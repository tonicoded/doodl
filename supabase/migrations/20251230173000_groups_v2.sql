-- Groups v2: friendlier groups UX (additive; keeps old builds working).

-- Ensure groups.kind exists (added by direct chats migration, but keep older installs safe).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'groups' and column_name = 'kind'
  ) then
    alter table public.groups add column kind text not null default 'group';
    alter table public.groups add constraint groups_kind_check check (kind in ('group','direct'));
  end if;
end$$;

-- Optional display name for group lists (don’t show codes in UI).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'groups' and column_name = 'display_name'
  ) then
    alter table public.groups add column display_name text;
  end if;
end$$;

create index if not exists idx_groups_kind on public.groups (kind);

-- Helpful index: list my groups quickly (group_members PK is (group_id, profile_id) so add profile lookup).
create index if not exists idx_group_members_profile_id on public.group_members (profile_id);

-- Create a new group with a friendly name (server generates code; avoids collisions).
drop function if exists public.create_group_v2_secure(uuid, text, text);
create or replace function public.create_group_v2_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_display_name text default null
)
returns table (code text, display_name text, group_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  name text := nullif(trim(p_display_name), '');
  new_code text;
  gid uuid;
  inserted boolean := false;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if name is not null and length(name) > 40 then
    name := left(name, 40);
  end if;

  for _ in 1..10 loop
    new_code := substr(md5(random()::text || clock_timestamp()::text || p_profile_id::text), 1, 10);
    begin
      insert into public.groups (code, owner_profile_id, kind, display_name)
      values (new_code, p_profile_id, 'group', name)
      returning id into gid;
      inserted := true;
      exit;
    exception when unique_violation then
      -- retry
    end;
  end loop;

  if not inserted then
    raise exception 'failed_to_generate_code';
  end if;

  insert into public.group_members (group_id, profile_id)
  values (gid, p_profile_id)
  on conflict do nothing;

  return query select new_code, name, gid;
end;
$$;

grant execute on function public.create_group_v2_secure(uuid, text, text) to anon;

-- List groups a user is in (excluding the user’s private default group == pairing_code).
drop function if exists public.list_groups_v2_secure(uuid, text, int);
create or replace function public.list_groups_v2_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 50
)
returns table (
  code text,
  display_name text,
  owner_profile_id uuid,
  member_count int,
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
    g.code,
    g.display_name,
    g.owner_profile_id,
    (
      select count(*)::int
      from public.group_members gm2
      where gm2.group_id = g.id
    ) as member_count,
    g.created_at
  from public.group_members gm
  join public.groups g on g.id = gm.group_id
  where gm.profile_id = p_profile_id
    and g.kind = 'group'
    and g.code <> c
  order by g.created_at desc nulls last
  limit lim;
end;
$$;

grant execute on function public.list_groups_v2_secure(uuid, text, int) to anon;

