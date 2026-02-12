-- Direct chats (Snapchat-style) built on top of existing groups+doodles.
-- This migration is additive and does not change existing RPCs, so old App Store builds keep working.

-- Mark groups as either 'group' (existing) or 'direct' (1:1 chat under the hood).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'groups' and column_name = 'kind'
  ) then
    alter table public.groups add column kind text not null default 'group';
  end if;
end$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_namespace n on n.oid = c.connamespace
    where n.nspname = 'public'
      and c.conname = 'groups_kind_check'
  ) then
    alter table public.groups
      add constraint groups_kind_check
      check (kind in ('group', 'direct')) not valid;
    alter table public.groups validate constraint groups_kind_check;
  end if;
end$$;

create index if not exists idx_groups_kind_created
  on public.groups (kind, created_at desc);

-- Friends (bidirectional edge list).
create table if not exists public.friends (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  friend_profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (profile_id, friend_profile_id)
);

create index if not exists idx_friends_profile_created
  on public.friends (profile_id, created_at desc);

alter table public.friends enable row level security;

-- Friend requests (username-based).
create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_profile_id uuid not null references public.profiles (id) on delete cascade,
  target_profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz default now(),
  responded_at timestamptz
);

create index if not exists idx_friend_requests_target_status_created
  on public.friend_requests (target_profile_id, status, created_at desc);

create index if not exists idx_friend_requests_requester_created
  on public.friend_requests (requester_profile_id, created_at desc);

-- Only one pending request per pair; allows re-request after decline.
create unique index if not exists idx_friend_requests_unique_pending
  on public.friend_requests (requester_profile_id, target_profile_id)
  where status = 'pending';

alter table public.friend_requests enable row level security;

-- One direct group per unique pair.
create table if not exists public.direct_threads (
  profile_a uuid not null references public.profiles (id) on delete cascade,
  profile_b uuid not null references public.profiles (id) on delete cascade,
  group_id uuid not null references public.groups (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (profile_a, profile_b)
);

create index if not exists idx_direct_threads_profile_a on public.direct_threads (profile_a);
create index if not exists idx_direct_threads_profile_b on public.direct_threads (profile_b);

alter table public.direct_threads enable row level security;

-- Internal: ensure a 1:1 'direct' group exists for the pair and return the group_id.
drop function if exists public._ensure_direct_thread(uuid, uuid);
create or replace function public._ensure_direct_thread(p_left uuid, p_right uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  a uuid := least(p_left, p_right);
  b uuid := greatest(p_left, p_right);
  gid uuid;
  code text;
begin
  -- Serialize per pair to avoid duplicate groups under concurrency.
  perform pg_advisory_xact_lock(hashtext(a::text || ':' || b::text));

  select dt.group_id into gid
  from public.direct_threads dt
  where dt.profile_a = a and dt.profile_b = b
  limit 1;

  if gid is not null then
    return gid;
  end if;

  for _ in 1..8 loop
    code := substr(md5(random()::text || clock_timestamp()::text || a::text || b::text), 1, 14);
    begin
      insert into public.groups (code, owner_profile_id, kind)
      values (code, a, 'direct')
      returning public.groups.id into gid;
      exit;
    exception when unique_violation then
      -- Rare: group code collision; retry.
    end;
  end loop;

  if gid is null then
    raise exception 'failed_to_generate_code';
  end if;

  insert into public.group_members (group_id, profile_id)
  values (gid, a), (gid, b)
  on conflict do nothing;

  insert into public.direct_threads (profile_a, profile_b, group_id)
  values (a, b, gid);

  return gid;
end;
$$;

-- Send friend request (auth via pairing_code).
drop function if exists public.send_friend_request_secure(uuid, text, text);
create or replace function public.send_friend_request_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_target_username text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  target_id uuid;
  req_id uuid;
  u text := lower(trim(p_target_username));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select p.id into target_id
  from public.profiles p
  where lower(p.username) = u
  limit 1;

  if target_id is null then
    raise exception 'user_not_found';
  end if;
  if target_id = p_profile_id then
    raise exception 'invalid_target';
  end if;

  if exists (
    select 1 from public.friends f
    where f.profile_id = p_profile_id and f.friend_profile_id = target_id
  ) then
    raise exception 'already_friends';
  end if;

  insert into public.friend_requests (requester_profile_id, target_profile_id, status, created_at)
  values (p_profile_id, target_id, 'pending', now())
  on conflict (requester_profile_id, target_profile_id) where status = 'pending'
  do update set created_at = excluded.created_at
  returning id into req_id;

  return req_id;
end;
$$;

grant execute on function public.send_friend_request_secure(uuid, text, text) to anon;

-- List incoming pending requests.
drop function if exists public.list_friend_requests_secure(uuid, text, int);
create or replace function public.list_friend_requests_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 50
)
returns table (
  request_id uuid,
  requester_profile_id uuid,
  requester_username text,
  requester_avatar_url text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  lim int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  return query
  select
    fr.id,
    fr.requester_profile_id,
    p.username,
    p.avatar_url,
    fr.created_at
  from public.friend_requests fr
  join public.profiles p on p.id = fr.requester_profile_id
  where fr.target_profile_id = p_profile_id
    and fr.status = 'pending'
  order by fr.created_at desc
  limit lim;
end;
$$;

grant execute on function public.list_friend_requests_secure(uuid, text, int) to anon;

-- Accept/decline a friend request. On accept, creates the direct thread group and returns its code.
drop function if exists public.respond_friend_request_secure(uuid, uuid, text, boolean);
create or replace function public.respond_friend_request_secure(
  p_request_id uuid,
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_accept boolean
)
returns table (status text, direct_group_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  fr public.friend_requests%rowtype;
  gid uuid;
  code text;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select * into fr
  from public.friend_requests r
  where r.id = p_request_id and r.target_profile_id = p_profile_id
  limit 1;

  if not found then
    raise exception 'not_found';
  end if;

  if fr.status <> 'pending' then
    return query select fr.status, null::text;
    return;
  end if;

  if not p_accept then
    update public.friend_requests
    set status = 'declined', responded_at = now()
    where id = p_request_id;
    return query select 'declined'::text, null::text;
    return;
  end if;

  -- Create friend edges (idempotent).
  insert into public.friends (profile_id, friend_profile_id)
  values (fr.requester_profile_id, fr.target_profile_id),
         (fr.target_profile_id, fr.requester_profile_id)
  on conflict do nothing;

  -- Ensure direct group + membership exists.
  gid := public._ensure_direct_thread(fr.requester_profile_id, fr.target_profile_id);
  select g.code into code from public.groups g where g.id = gid limit 1;

  update public.friend_requests
  set status = 'accepted', responded_at = now()
  where id = p_request_id;

  return query select 'accepted'::text, code;
end;
$$;

grant execute on function public.respond_friend_request_secure(uuid, uuid, text, boolean) to anon;

-- List friends.
drop function if exists public.list_friends_secure(uuid, text, int);
create or replace function public.list_friends_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 200
)
returns table (profile_id uuid, username text, avatar_url text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  lim int := greatest(1, least(coalesce(p_limit, 200), 500));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  return query
  select
    p.id,
    p.username,
    p.avatar_url,
    f.created_at
  from public.friends f
  join public.profiles p on p.id = f.friend_profile_id
  where f.profile_id = p_profile_id
  order by f.created_at desc
  limit lim;
end;
$$;

grant execute on function public.list_friends_secure(uuid, text, int) to anon;

-- Ensure a direct chat exists with a friend (returns group code).
drop function if exists public.ensure_direct_chat_secure(uuid, text, uuid);
create or replace function public.ensure_direct_chat_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_friend_profile_id uuid
)
returns table (code text, group_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  gid uuid;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if p_friend_profile_id is null or p_friend_profile_id = p_profile_id then
    raise exception 'invalid_target';
  end if;

  if not exists (
    select 1 from public.friends f
    where f.profile_id = p_profile_id and f.friend_profile_id = p_friend_profile_id
  ) then
    raise exception 'not_friends';
  end if;

  gid := public._ensure_direct_thread(p_profile_id, p_friend_profile_id);

  return query
  select g.code, g.id
  from public.groups g
  where g.id = gid
  limit 1;
end;
$$;

grant execute on function public.ensure_direct_chat_secure(uuid, text, uuid) to anon;

-- List direct chat threads for the requester (fast chat list).
drop function if exists public.list_direct_chats_secure(uuid, text, int);
create or replace function public.list_direct_chats_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 50
)
returns table (
  code text,
  other_profile_id uuid,
  other_username text,
  other_avatar_url text,
  other_is_pro boolean,
  last_created_at timestamptz,
  has_unread boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  lim int := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  return query
  with threads as (
    select
      dt.group_id,
      case when dt.profile_a = p_profile_id then dt.profile_b else dt.profile_a end as other_id
    from public.direct_threads dt
    where dt.profile_a = p_profile_id or dt.profile_b = p_profile_id
  ),
  base as (
    select
      g.code,
      t.other_id as other_profile_id,
      p.username as other_username,
      p.avatar_url as other_avatar_url,
      coalesce(p.is_pro, false) as other_is_pro,
      (
        select d.created_at
        from public.doodles d
        where d.group_id = t.group_id
          and d.is_removed = false
          and d.content_base64 is not null
        order by d.created_at desc
        limit 1
      ) as last_created_at,
      exists (
        select 1
        from public.doodles d
        where d.group_id = t.group_id
          and d.sender_profile_id = t.other_id
          and d.is_removed = false
          and d.content_base64 is not null
          and not exists (
            select 1 from public.doodle_views v
            where v.doodle_id = d.id and v.viewer_profile_id = p_profile_id
          )
      ) as has_unread
    from threads t
    join public.groups g on g.id = t.group_id
    join public.profiles p on p.id = t.other_id
    where g.kind = 'direct'
  )
  select
    b.code,
    b.other_profile_id,
    b.other_username,
    b.other_avatar_url,
    b.other_is_pro,
    b.last_created_at,
    b.has_unread
  from base b
  order by b.has_unread desc, b.last_created_at desc nulls last, lower(b.other_username) asc
  limit lim;
end;
$$;

grant execute on function public.list_direct_chats_secure(uuid, text, int) to anon;
