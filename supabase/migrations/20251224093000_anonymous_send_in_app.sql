-- In-app anonymous send: search enabled recipients + send without needing a link.
-- Also default-enable anonymous receiving for all profiles.

-- Store sender_profile_id for in-app sends (not exposed to recipients).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anonymous_doodles' and column_name = 'sender_profile_id'
  ) then
    alter table public.anonymous_doodles
      add column sender_profile_id uuid references public.profiles (id) on delete set null;
  end if;
end$$;

-- Default enable for new links
alter table public.anonymous_links
  alter column is_enabled set default true;

-- Enable anonymous receiving for existing users (per product decision).
update public.anonymous_links
set is_enabled = true
where is_enabled = false;

-- Ensure every profile has an anonymous link row (enabled) for in-app discovery.
create or replace function public._ensure_anonymous_link_for_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  code text;
  inserted boolean := false;
begin
  -- If one already exists, don't touch it.
  if exists (select 1 from public.anonymous_links al where al.profile_id = new.id) then
    return new;
  end if;

  for _ in 1..8 loop
    code := substr(md5(random()::text || clock_timestamp()::text || new.id::text), 1, 14);
    begin
      insert into public.anonymous_links (profile_id, short_code, is_enabled)
      values (new.id, code, true);
      inserted := true;
      exit;
    exception when unique_violation then
      -- Rare collision, retry
    end;
  end loop;

  if not inserted then
    -- Fail open: profile creation should not break if code generation fails.
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ensure_anonymous_link_profile on public.profiles;
create trigger trg_ensure_anonymous_link_profile
after insert on public.profiles
for each row
execute procedure public._ensure_anonymous_link_for_profile();

-- Backfill missing links for existing profiles (idempotent).
do $$
declare
  p record;
begin
  for p in (select id from public.profiles) loop
    if not exists (select 1 from public.anonymous_links al where al.profile_id = p.id) then
      -- Reuse the trigger function logic by direct insert loop.
      for _ in 1..8 loop
        begin
          insert into public.anonymous_links (profile_id, short_code, is_enabled)
          values (p.id, substr(md5(random()::text || clock_timestamp()::text || p.id::text), 1, 14), true);
          exit;
        exception when unique_violation then
        end;
      end loop;
    end if;
  end loop;
end;
$$;

-- Search users who have anonymous receiving enabled (requires requester auth).
drop function if exists public.search_anonymous_receivers_secure(uuid, text, text, int);
create or replace function public.search_anonymous_receivers_secure(
  p_requester_profile_id uuid,
  p_requester_pairing_code text,
  p_query text,
  p_limit int default 12
)
returns table (profile_id uuid, username text, avatar_url text)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_requester_pairing_code));
  q text := lower(trim(p_query));
  lim int := greatest(1, least(coalesce(p_limit, 12), 20));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_requester_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  -- Privacy: require a non-trivial query to avoid enumerating the userbase.
  if q is null or length(q) < 2 then
    return;
  end if;

  return query
  select p.id, p.username, p.avatar_url
  from public.profiles p
  join public.anonymous_links al on al.profile_id = p.id
  where p.id <> p_requester_profile_id
    and al.is_enabled = true
    and (
      lower(p.username) like q || '%'
      or lower(p.username) like '%' || q || '%'
    )
  order by
    case
      when lower(p.username) like q || '%' then 0
      when lower(p.username) like '%' || q || '%' then 1
      else 2
    end,
    length(p.username) asc,
    p.username asc
  limit lim;
end;
$$;

grant execute on function public.search_anonymous_receivers_secure(uuid, text, text, int) to anon;

-- In-app anonymous send by recipient profile id (requires sender auth, still anonymous to recipient).
drop function if exists public.submit_anonymous_doodle_to_profile_secure(uuid, text, uuid, text, text);
create or replace function public.submit_anonymous_doodle_to_profile_secure(
  p_sender_profile_id uuid,
  p_sender_pairing_code text,
  p_recipient_profile_id uuid,
  p_content_base64 text,
  p_sender_fingerprint text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_sender_pairing_code));
  lid uuid;
  did uuid;
  fp text := nullif(trim(p_sender_fingerprint), '');
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_sender_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if p_recipient_profile_id is null then
    raise exception 'not_found';
  end if;

  if p_content_base64 is null or length(p_content_base64) < 50 or length(p_content_base64) > 1800000 then
    raise exception 'invalid_content';
  end if;

  select al.id into lid
  from public.anonymous_links al
  where al.profile_id = p_recipient_profile_id and al.is_enabled = true
  limit 1;

  if lid is null then
    raise exception 'not_found';
  end if;

  if fp is not null and exists (
    select 1
    from public.blocked_anonymous_senders b
    where b.recipient_profile_id = p_recipient_profile_id and b.sender_fingerprint = fp
  ) then
    raise exception 'blocked';
  end if;

  insert into public.anonymous_doodles (link_id, recipient_profile_id, content_base64, sender_fingerprint, sender_profile_id)
  values (
    lid,
    p_recipient_profile_id,
    p_content_base64,
    case when fp is not null and length(fp) between 6 and 200 then fp else null end,
    p_sender_profile_id
  )
  returning id into did;

  return did;
end;
$$;

grant execute on function public.submit_anonymous_doodle_to_profile_secure(uuid, text, uuid, text, text) to anon;
