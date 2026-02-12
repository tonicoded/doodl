-- Supabase schema snapshot for DOODL.
-- Run in Supabase SQL editor. Assumes bucket "avatars" already exists.

-- Enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Profiles table
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  pairing_code text not null unique,
  avatar_url text,
  last_active_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Ensure last_active_at exists on older installs
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'last_active_at'
  ) then
    alter table public.profiles add column last_active_at timestamptz default now();
  end if;
end$$;

-- Ensure xp_total exists on older installs
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'xp_total'
  ) then
    alter table public.profiles add column xp_total int not null default 0;
  end if;
end$$;

-- Ensure is_pro exists on older installs (Pro crown badge)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'is_pro'
  ) then
    alter table public.profiles add column is_pro boolean not null default false;
  end if;
end$$;

-- Ensure rank exists on older installs (derived from XP/level; max 20)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'rank'
  ) then
    alter table public.profiles add column rank int not null default 1;
  end if;
end$$;

-- Backfill pairing_code if the column already existed without values
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'pairing_code') then
    update public.profiles
    set pairing_code = lower(substr(encode(gen_random_bytes(8), 'hex'), 1, 8))
    where pairing_code is null or pairing_code = '';
  end if;
end$$;

-- updated_at trigger
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_set_updated_at on public.profiles;
create trigger trg_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;

-- No direct table access for anon; use SECURITY DEFINER RPCs below.
drop policy if exists "profiles_insert_anon" on public.profiles;
drop policy if exists "profiles_select_public" on public.profiles;
drop policy if exists "profiles_update_anon" on public.profiles;
drop policy if exists "profiles_delete_anon" on public.profiles;

-- Username availability (public)
drop function if exists public.username_available_secure(text);
create or replace function public.username_available_secure(p_username text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  u text := lower(trim(p_username));
begin
  if u is null or length(u) < 2 or length(u) > 24 then
    return false;
  end if;

  return not exists (
    select 1 from public.profiles p where lower(p.username) = u
  );
end;
$$;

-- Prioritize non-broadcast jobs so realtime pushes are not delayed.
drop function if exists public.claim_push_jobs_service(int);
create or replace function public.claim_push_jobs_service(p_limit int default 25)
returns table (
  id uuid,
  kind text,
  content_id uuid,
  group_id uuid,
  sender_profile_id uuid,
  recipient_profile_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
  lim int := greatest(1, least(coalesce(p_limit, 25), 100));
begin
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  return query
  with picked as (
    select pj.id as job_id
    from public.push_jobs pj
    where pj.status = 'pending'
    order by
      case when pj.kind = 'broadcast' then 1 else 0 end,
      pj.created_at asc
    for update skip locked
    limit lim
  ),
  upd as (
    update public.push_jobs pj
    set
      status = 'processing',
      attempt_count = pj.attempt_count + 1,
      locked_at = now(),
      updated_at = now()
    where pj.id in (select picked.job_id from picked)
    returning pj.id, pj.kind, pj.content_id, pj.group_id, pj.sender_profile_id, pj.recipient_profile_id
  )
  select * from upd;
end;
$$;

grant execute on function public.username_available_secure(text) to anon;

-- XP curve: returns XP needed to advance from `p_level` to `p_level + 1`.
drop function if exists public.xp_needed_for_level(int);
create or replace function public.xp_needed_for_level(p_level int)
returns int
language plpgsql
immutable
as $$
declare
  lvl int := greatest(1, coalesce(p_level, 1));
begin
  -- Level 1 -> 2: 60 XP, then ramps by +25 per level.
  return 60 + ((lvl - 1) * 25);
end;
$$;

-- Rank helpers (rank is stored on profiles so it can be surfaced in RPCs without recomputing everywhere).
drop function if exists public.rank_from_level(int);
create or replace function public.rank_from_level(p_level int)
returns int
language sql
immutable
as $$
  select least(20, greatest(1, coalesce(p_level, 1)));
$$;

drop function if exists public.level_from_xp_total(int);
create or replace function public.level_from_xp_total(p_xp_total int)
returns int
language plpgsql
immutable
as $$
declare
  total int := greatest(0, coalesce(p_xp_total, 0));
  lvl int := 1;
  needed int := public.xp_needed_for_level(lvl);
  guard int := 0;
begin
  while total >= needed loop
    total := total - needed;
    lvl := lvl + 1;
    needed := public.xp_needed_for_level(lvl);
    guard := guard + 1;
    if guard > 1200 then
      exit;
    end if;
  end loop;
  return lvl;
end;
$$;

-- Read current XP + derived level state (secure, no direct table access).
drop function if exists public.profile_xp_secure(uuid, text);
create or replace function public.profile_xp_secure(p_profile_id uuid, p_profile_pairing_code text)
returns table (
  xp_total int,
  level int,
  level_xp int,
  next_level_xp int,
  rank int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  total int := 0;
  remaining int := 0;
  lvl int := 1;
  needed int := 0;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select coalesce(p.xp_total, 0) into total
  from public.profiles p
  where p.id = p_profile_id
  limit 1;

  remaining := total;
  needed := public.xp_needed_for_level(lvl);
  while remaining >= needed loop
    remaining := remaining - needed;
    lvl := lvl + 1;
    needed := public.xp_needed_for_level(lvl);
    if lvl > 999 then
      exit;
    end if;
  end loop;

  return query select total, lvl, remaining, needed, public.rank_from_level(lvl);
end;
$$;

grant execute on function public.profile_xp_secure(uuid, text) to anon;

create or replace function public._sync_profile_rank_from_xp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.rank := public.rank_from_level(public.level_from_xp_total(new.xp_total));
  return new;
end;
$$;

drop trigger if exists trg_sync_profile_rank_from_xp on public.profiles;
create trigger trg_sync_profile_rank_from_xp
before update of xp_total on public.profiles
for each row execute procedure public._sync_profile_rank_from_xp();

-- Backfill rank for existing profiles (idempotent).
update public.profiles
set rank = public.rank_from_level(public.level_from_xp_total(coalesce(xp_total, 0)))
where rank is null or rank <= 0;

-- Profile search for invites (public: returns only username + avatar)
drop function if exists public.search_profiles_secure(text, int, uuid);
create or replace function public.search_profiles_secure(
  p_query text,
  p_limit int default 8,
  p_exclude_profile_id uuid default null
)
returns table (id uuid, username text, avatar_url text)
language plpgsql
security definer
set search_path = public
as $$
declare
  q text := lower(trim(p_query));
  lim int := greatest(1, least(coalesce(p_limit, 8), 20));
begin
  if q is null or length(q) < 2 then
    return;
  end if;

  return query
  select p.id, p.username, p.avatar_url
  from public.profiles p
  where (p_exclude_profile_id is null or p.id <> p_exclude_profile_id)
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

grant execute on function public.search_profiles_secure(text, int, uuid) to anon;

-- Create profile (requires unique username + pairing_code). Uses pairing_code as a lightweight secret for later updates.
drop function if exists public.create_profile_secure(text, text, text);
create or replace function public.create_profile_secure(p_username text, p_pairing_code text, p_avatar_url text default null)
returns table (id uuid, username text, avatar_url text, pairing_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  u text := lower(trim(p_username));
  c text := lower(trim(p_pairing_code));
  pid uuid;
begin
  if u is null or length(u) < 2 or length(u) > 24 then
    raise exception 'invalid_username';
  end if;
  if c is null or length(c) < 4 or length(c) > 64 then
    raise exception 'invalid_pairing_code';
  end if;

  -- Provide deterministic errors (avoid generic "conflict" where possible).
  if exists (select 1 from public.profiles p where lower(p.username) = u) then
    raise exception 'username_taken';
  end if;
  if exists (select 1 from public.profiles p where p.pairing_code = c) then
    -- Backward-compat: older app versions only understand "conflict" and will retry with a new code.
    raise exception 'conflict';
  end if;

  begin
    insert into public.profiles (username, pairing_code, avatar_url)
    values (u, c, nullif(p_avatar_url, ''))
    returning public.profiles.id into pid;
  exception when unique_violation then
    raise exception 'conflict';
  end;

  return query
  select p.id, p.username, p.avatar_url, p.pairing_code
  from public.profiles p
  where p.id = pid
  limit 1;
end;
$$;

grant execute on function public.create_profile_secure(text, text, text) to anon;

-- Fetch profile id (for session recovery)
drop function if exists public.fetch_profile_id_secure(text, text);
create or replace function public.fetch_profile_id_secure(p_username text, p_pairing_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  u text := lower(trim(p_username));
  c text := lower(trim(p_pairing_code));
  pid uuid;
begin
  select p.id into pid
  from public.profiles p
  where lower(p.username) = u and p.pairing_code = c
  limit 1;

  return pid;
end;
$$;

grant execute on function public.fetch_profile_id_secure(text, text) to anon;

-- Profile exists (for session validity check)
drop function if exists public.profile_exists_secure(uuid);
create or replace function public.profile_exists_secure(p_profile_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists(select 1 from public.profiles p where p.id = p_profile_id);
end;
$$;

grant execute on function public.profile_exists_secure(uuid) to anon;

-- Update username (requires profile pairing_code)
drop function if exists public.update_username_secure(uuid, text, text);
create or replace function public.update_username_secure(p_profile_id uuid, p_profile_pairing_code text, p_new_username text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  u text := lower(trim(p_new_username));
  c text := lower(trim(p_profile_pairing_code));
begin
  if u is null or length(u) < 2 or length(u) > 24 then
    raise exception 'invalid_username';
  end if;

  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  begin
    update public.profiles
    set username = u
    where id = p_profile_id;
  exception when unique_violation then
    raise exception 'username_taken';
  end;

  return 'ok';
end;
$$;

grant execute on function public.update_username_secure(uuid, text, text) to anon;

-- Update avatar (requires profile pairing_code)
drop function if exists public.update_avatar_secure(uuid, text, text);
create or replace function public.update_avatar_secure(p_profile_id uuid, p_profile_pairing_code text, p_avatar_url text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  update public.profiles
  set avatar_url = nullif(p_avatar_url, '')
  where id = p_profile_id;

  return 'ok';
end;
$$;

grant execute on function public.update_avatar_secure(uuid, text, text) to anon;

-- Delete profile (requires profile pairing_code)
drop function if exists public.delete_profile_secure(uuid, text);
create or replace function public.delete_profile_secure(p_profile_id uuid, p_profile_pairing_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  delete from public.profiles p where p.id = p_profile_id;
  return 'ok';
end;
$$;

grant execute on function public.delete_profile_secure(uuid, text) to anon;

-- Storage policies for bucket "avatars" (public bucket)
drop policy if exists "avatars_select_public" on storage.objects;
create policy "avatars_select_public" on storage.objects
for select using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_anon" on storage.objects;
create policy "avatars_insert_anon" on storage.objects
for insert to anon
with check (bucket_id = 'avatars');

-- Keep deletes disabled for safety; old avatar files can remain in storage.
drop policy if exists "avatars_delete_anon" on storage.objects;

-- Groups table
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  owner_profile_id uuid references public.profiles (id) on delete cascade,
  created_at timestamptz default now()
);

-- Group members
create table if not exists public.group_members (
  group_id uuid references public.groups (id) on delete cascade,
  profile_id uuid references public.profiles (id) on delete cascade,
  role text default 'member',
  created_at timestamptz default now(),
  primary key (group_id, profile_id)
);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;

-- No direct table access for anon; use SECURITY DEFINER RPCs below.
drop policy if exists "groups_insert_anon" on public.groups;
drop policy if exists "groups_select_public" on public.groups;
drop policy if exists "group_members_insert_anon" on public.group_members;
drop policy if exists "group_members_select_public" on public.group_members;
drop policy if exists "group_members_delete_anon" on public.group_members;

-- Ensure group exists + ensure membership (requires profile pairing_code)
drop function if exists public.ensure_group_secure(text, uuid, text);
create or replace function public.ensure_group_secure(p_code text, p_profile_id uuid, p_profile_pairing_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := lower(trim(p_code));
  c text := lower(trim(p_profile_pairing_code));
  gid uuid;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select g.id into gid
  from public.groups g
  where g.code = v_code
  limit 1;

  if gid is null then
    insert into public.groups (code, owner_profile_id)
    values (v_code, p_profile_id)
    returning public.groups.id into gid;
  end if;

  insert into public.group_members (group_id, profile_id)
  values (gid, p_profile_id)
  on conflict do nothing;

  return gid;
end;
$$;

grant execute on function public.ensure_group_secure(text, uuid, text) to anon;

-- Join group (capacity max 15) (requires profile pairing_code)
drop function if exists public.join_group_secure(text, uuid, text);
create or replace function public.join_group_secure(p_code text, p_profile_id uuid, p_profile_pairing_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := lower(trim(p_code));
  c text := lower(trim(p_profile_pairing_code));
  gid uuid;
  member_count int;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select g.id into gid
  from public.groups g
  where g.code = v_code
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  select count(*) into member_count
  from public.group_members gm
  where gm.group_id = gid;

  if member_count >= 15 then
    raise exception 'group_full';
  end if;

  insert into public.group_members (group_id, profile_id)
  values (gid, p_profile_id)
  on conflict do nothing;

  return 'ok';
end;
$$;

grant execute on function public.join_group_secure(text, uuid, text) to anon;

-- Leave group (requires profile pairing_code)
drop function if exists public.leave_group_secure(text, uuid, text);
create or replace function public.leave_group_secure(p_code text, p_profile_id uuid, p_profile_pairing_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := lower(trim(p_code));
  c text := lower(trim(p_profile_pairing_code));
  gid uuid;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select g.id into gid
  from public.groups g
  where g.code = v_code
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  delete from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_profile_id;

  return 'ok';
end;
$$;

grant execute on function public.leave_group_secure(text, uuid, text) to anon;

-- Remove member (owner-only) (requires requester pairing_code)
drop function if exists public.remove_member_secure(text, uuid, text, uuid);
create or replace function public.remove_member_secure(p_code text, p_requester_profile_id uuid, p_requester_pairing_code text, p_member_profile_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := lower(trim(p_code));
  c text := lower(trim(p_requester_pairing_code));
  gid uuid;
  owner_id uuid;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_requester_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select g.id, g.owner_profile_id into gid, owner_id
  from public.groups g
  where g.code = v_code
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  if owner_id is distinct from p_requester_profile_id then
    raise exception 'not_owner';
  end if;

  if p_member_profile_id = owner_id then
    raise exception 'cannot_remove_owner';
  end if;

  delete from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_member_profile_id;

  return 'ok';
end;
$$;

grant execute on function public.remove_member_secure(text, uuid, text, uuid) to anon;

-- Fetch group owner (read-only)
drop function if exists public.fetch_group_owner_secure(text);
create or replace function public.fetch_group_owner_secure(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  owner_id uuid;
begin
  select g.id, g.owner_profile_id into gid, owner_id
  from public.groups g
  where g.code = lower(trim(p_code))
  limit 1;

  return owner_id;
end;
$$;

grant execute on function public.fetch_group_owner_secure(text) to anon;

-- Member streaks (per group + sender)
create table if not exists public.member_streaks (
  group_id uuid not null references public.groups (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  streak_count int not null default 0,
  last_streak_date date,
  updated_at timestamptz default now(),
  primary key (group_id, profile_id)
);

alter table public.member_streaks enable row level security;

-- Secure RPC to fetch members: requires requester to still be a member
drop function if exists public.group_members_secure(text, uuid);
create or replace function public.group_members_secure(p_code text, requester_profile_id uuid)
returns table (profile_id uuid, username text, avatar_url text, is_pro boolean, streak_count int, is_online boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  today date := (now() at time zone 'utc')::date;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = requester_profile_id
  ) then
    return;
  end if;

  return query
  select
    p.id,
    p.username,
    p.avatar_url,
    coalesce(p.is_pro, false) as is_pro,
    coalesce(
      case
        when ms.last_streak_date is null then 0
        when ms.last_streak_date = today then ms.streak_count
        when ms.last_streak_date = (today - 1) then ms.streak_count
        else 0
      end,
      0
    )::int as streak_count,
    (p.last_active_at is not null and p.last_active_at >= now() - interval '2 minutes') as is_online
  from public.group_members gm
  join public.profiles p on p.id = gm.profile_id
  left join public.member_streaks ms on ms.group_id = gm.group_id and ms.profile_id = gm.profile_id
  where gm.group_id = gid
  order by lower(p.username);
end;
$$;

grant execute on function public.group_members_secure(text, uuid) to anon;

-- Fetch group member counts for multiple groups the requester belongs to.
drop function if exists public.group_member_counts_secure(text[], uuid);
create or replace function public.group_member_counts_secure(
  p_codes text[],
  p_requester_profile_id uuid
)
returns table (code text, member_count int, max_members int)
language sql
security definer
set search_path = public
as $$
  with input as (
    select distinct lower(trim(x)) as code
    from unnest(coalesce(p_codes, array[]::text[])) as x
    where x is not null and length(trim(x)) > 0
  )
  select
    g.code,
    count(gm_all.profile_id)::int as member_count,
    15::int as max_members
  from input i
  join public.groups g on g.code = i.code
  join public.group_members gm_req on gm_req.group_id = g.id and gm_req.profile_id = p_requester_profile_id
  join public.group_members gm_all on gm_all.group_id = g.id
  group by g.code;
$$;

grant execute on function public.group_member_counts_secure(text[], uuid) to anon;

-- Invites (username-based)
create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  inviter_profile_id uuid not null references public.profiles (id) on delete cascade,
  invited_profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending', -- pending|accepted|declined
  created_at timestamptz default now(),
  responded_at timestamptz
);

create index if not exists idx_group_invites_invited on public.group_invites (invited_profile_id, status);
create index if not exists idx_group_invites_group on public.group_invites (group_id, status);

alter table public.group_invites enable row level security;

-- Secure RPCs for invites (we keep direct table access closed by not adding select/insert policies)

drop function if exists public.invite_to_group_secure(text, uuid, text);
create or replace function public.invite_to_group_secure(p_group_code text, p_inviter_profile_id uuid, p_invited_username text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  invited_id uuid;
  invite_id uuid;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_group_code)
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  if not exists (
    select 1 from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_inviter_profile_id
  ) then
    raise exception 'not_member';
  end if;

  select p.id into invited_id
  from public.profiles p
  where lower(p.username) = lower(p_invited_username)
  limit 1;

  if invited_id is null then
    raise exception 'user_not_found';
  end if;

  if invited_id = p_inviter_profile_id then
    raise exception 'self_invite';
  end if;

  if exists (
    select 1 from public.group_members gm
    where gm.group_id = gid and gm.profile_id = invited_id
  ) then
    raise exception 'already_member';
  end if;

  insert into public.group_invites (group_id, inviter_profile_id, invited_profile_id)
  values (gid, p_inviter_profile_id, invited_id)
  returning id into invite_id;

  return invite_id;
end;
$$;

grant execute on function public.invite_to_group_secure(text, uuid, text) to anon;

drop function if exists public.list_invites_secure(uuid);
create or replace function public.list_invites_secure(p_profile_id uuid)
returns table (
  invite_id uuid,
  group_code text,
  inviter_username text,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    gi.id,
    g.code,
    p.username,
    gi.status,
    gi.created_at
  from public.group_invites gi
  join public.groups g on g.id = gi.group_id
  join public.profiles p on p.id = gi.inviter_profile_id
  where gi.invited_profile_id = p_profile_id
  order by gi.created_at desc;
end;
$$;

grant execute on function public.list_invites_secure(uuid) to anon;

drop function if exists public.respond_invite_secure(uuid, uuid, boolean);
drop function if exists public.respond_invite_secure(uuid, uuid, text, boolean);
create or replace function public.respond_invite_secure(p_invite_id uuid, p_profile_id uuid, p_profile_pairing_code text, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  current_status text;
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select gi.group_id, gi.status into gid, current_status
  from public.group_invites gi
  where gi.id = p_invite_id and gi.invited_profile_id = p_profile_id
  limit 1;

  if gid is null then
    raise exception 'invite_not_found';
  end if;

  if current_status <> 'pending' then
    return current_status;
  end if;

  if p_accept then
    insert into public.group_members (group_id, profile_id)
    values (gid, p_profile_id)
    on conflict do nothing;

    update public.group_invites
    set status = 'accepted', responded_at = now()
    where id = p_invite_id;

    return 'accepted';
  else
    update public.group_invites
    set status = 'declined', responded_at = now()
    where id = p_invite_id;

    return 'declined';
  end if;
end;
$$;

grant execute on function public.respond_invite_secure(uuid, uuid, text, boolean) to anon;

-- Doodles
create table if not exists public.doodles (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  sender_profile_id uuid not null references public.profiles (id) on delete cascade,
  image_url text,
  content_base64 text,
  content_len int,
  created_at timestamptz default now(),
  is_removed boolean not null default false
);

create index if not exists idx_doodles_group_created on public.doodles (group_id, created_at desc);

-- Performance: covers sender_profile_id for common inbox filters / blocked checks without touching the heap.
create index if not exists idx_doodles_group_created_active_sender
  on public.doodles (group_id, created_at desc) include (sender_profile_id)
  where is_removed = false and content_base64 is not null;

-- Performance: helps stable ordering and fast pruning/offset for per-group retention.
create index if not exists idx_doodles_group_created_id_active_sender
  on public.doodles (group_id, created_at desc, id desc) include (sender_profile_id)
  where is_removed = false and content_base64 is not null;

-- Performance: speeds up per-sender lookups used by inbox_senders_secure.
create index if not exists idx_doodles_group_sender_created_active
  on public.doodles (group_id, sender_profile_id, created_at desc)
  where is_removed = false and content_base64 is not null;

-- Performance for global sender aggregation (used by leaderboard RPCs).
create index if not exists idx_doodles_sender_created_active
  on public.doodles (sender_profile_id, created_at desc)
  where is_removed = false and content_base64 is not null;

alter table public.doodles enable row level security;

-- Retention: keep only the newest N doodles per group to prevent unbounded growth.
-- Use `public.prune_doodles_service()` once to clean existing rows, then the trigger keeps it capped.

drop function if exists public.prune_doodles_service(int);
create or replace function public.prune_doodles_service(p_keep_per_group int default 18)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
  keep_n int := greatest(1, least(coalesce(p_keep_per_group, 18), 50));
  deleted_count int := 0;
begin
  -- Allow from SQL editor (no JWT) or service_role; never allow anon/auth users.
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  -- Give the cleanup room to finish even under load.
  perform set_config('statement_timeout', '300000', true); -- 5 minutes

  with ranked as (
    select
      d.id,
      row_number() over (partition by d.group_id order by d.created_at desc, d.id desc) as rn
    from public.doodles d
  ),
  del as (
    delete from public.doodles d
    using ranked r
    where d.id = r.id and r.rn > keep_n
    returning 1
  )
  select count(*)::int into deleted_count from del;

  return deleted_count;
end;
$$;

-- Chunked cleanup (avoids Supabase SQL editor upstream timeouts).
-- Run repeatedly until it returns 0.
drop function if exists public.prune_doodles_service_chunk(int, int);
create or replace function public.prune_doodles_service_chunk(
  p_keep_per_group int default 18,
  p_group_batch int default 10
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
  keep_n int := greatest(1, least(coalesce(p_keep_per_group, 18), 50));
  group_batch int := greatest(1, least(coalesce(p_group_batch, 10), 200));
  deleted_count int := 0;
begin
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  perform set_config('statement_timeout', '120000', true); -- 2 minutes

  with groups_to_prune as materialized (
    select d.group_id
    from public.doodles d
    group by d.group_id
    having count(*) > keep_n
    order by count(*) desc
    limit group_batch
  ),
  ranked as materialized (
    select
      d.id,
      row_number() over (partition by d.group_id order by d.created_at desc, d.id desc) as rn
    from public.doodles d
    join groups_to_prune g on g.group_id = d.group_id
  ),
  del as (
    delete from public.doodles d
    using ranked r
    where d.id = r.id and r.rn > keep_n
    returning 1
  )
  select count(*)::int into deleted_count from del;

  return deleted_count;
end;
$$;

-- Cleanup: remove oversized doodles (prevents PostgREST/DB timeouts from huge base64 payloads).
-- Run repeatedly until it returns 0.
drop function if exists public.prune_oversized_doodles_service_chunk(int, int);
create or replace function public.prune_oversized_doodles_service_chunk(
  p_max_len int default 600000,
  p_batch int default 200
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
  max_len int := greatest(10000, least(coalesce(p_max_len, 600000), 1800000));
  batch_n int := greatest(1, least(coalesce(p_batch, 200), 2000));
  deleted_count int := 0;
begin
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  perform set_config('statement_timeout', '120000', true); -- 2 minutes

  -- First: backfill content_len for a small batch (this step may detoast large rows, so keep it tiny).
  with todo as materialized (
    select d.id
    from public.doodles d
    where d.content_len is null and d.content_base64 is not null
    order by d.created_at desc
    limit least(batch_n, 10)
  )
  update public.doodles d
  set content_len = length(d.content_base64)
  from todo t
  where d.id = t.id;

  with doomed as materialized (
    select d.id
    from public.doodles d
    where d.content_len is not null
      and d.content_len > max_len
    order by d.created_at asc
    limit batch_n
  ),
  del as (
    delete from public.doodles d
    using doomed x
    where d.id = x.id
    returning 1
  )
  select count(*)::int into deleted_count from del;

  return deleted_count;
end;
$$;

-- Trigger helper: prune only the group of the inserted doodle (fast path).
create or replace function public._prune_doodles_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  keep_n int := 18;
begin
  -- After initial cleanup, this deletes at most 1 row per insert (the oldest beyond keep_n).
  delete from public.doodles d
  where d.id in (
    select x.id
    from (
      select d2.id
      from public.doodles d2
      where d2.group_id = new.group_id
      order by d2.created_at desc, d2.id desc
      offset keep_n
      limit 1
    ) x
  );

  return new;
end;
$$;

drop trigger if exists trg_prune_doodles_per_group on public.doodles;
create trigger trg_prune_doodles_per_group
after insert on public.doodles
for each row
execute procedure public._prune_doodles_after_insert();

-- One-time cleanup (run from SQL editor): keep the newest 18 per group.
-- select public.prune_doodles_service(18);
-- If you hit "upstream timeout", run in chunks instead:
-- select public.prune_doodles_service_chunk(18, 10);
-- If you have legacy huge doodles (causing statement timeouts), delete them in chunks:
-- select public.prune_oversized_doodles_service_chunk(600000, 200);

-- Ensure is_removed exists on older installs
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'doodles' and column_name = 'is_removed'
  ) then
    alter table public.doodles add column is_removed boolean not null default false;
  end if;
end$$;

-- Ensure base64 column exists on older installs
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'doodles' and column_name = 'content_base64'
  ) then
    alter table public.doodles add column content_base64 text;
  end if;
end$$;

-- Ensure content_len exists on older installs (lets read RPCs avoid detoasting huge base64 blobs).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'doodles' and column_name = 'content_len'
  ) then
    alter table public.doodles add column content_len int;
  end if;
end$$;

-- If an older schema had image_url NOT NULL (storage-based), make it nullable for base64-based doodls
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'doodles' and column_name = 'image_url'
  ) then
    alter table public.doodles alter column image_url drop not null;
  end if;
end$$;

-- Secure RPC to create a doodl record (requires membership)
drop function if exists public.create_doodle_secure(text, uuid, text);
drop function if exists public.create_doodle_secure(text, uuid, text, text);
create or replace function public.create_doodle_secure(p_code text, p_sender_profile_id uuid, p_content_base64 text, p_sender_pairing_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  did uuid;
  today date := (now() at time zone 'utc')::date;
  c text := lower(trim(p_sender_pairing_code));
  last_sent_at timestamptz;
  content_len int := length(coalesce(p_content_base64, ''));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_sender_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  -- Under load, PostgREST's default statement timeout can be hit by unrelated DB triggers
  -- (e.g. Supabase Database Webhooks / http_request queue). Give this write RPC a bit more room.
  perform set_config('statement_timeout', '90000', true); -- 90 seconds

  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_sender_profile_id
  ) then
    raise exception 'not_member';
  end if;

  if p_content_base64 is null or content_len < 50 then
    raise exception 'invalid_content';
  end if;
  if content_len > 600000 then
    -- Keep token for newer clients, but make it readable for older App Store builds.
    raise exception 'image_too_large: doodle te groot (probeer opnieuw)';
  end if;

  -- Anti-spam: 1-minute cooldown per sender per group.
  select d.created_at into last_sent_at
  from public.doodles d
  where d.group_id = gid
    and d.sender_profile_id = p_sender_profile_id
    and d.content_base64 is not null
    and d.is_removed = false
  order by d.created_at desc
  limit 1;

  if last_sent_at is not null and last_sent_at >= now() - interval '1 minute' then
    -- PostgREST wraps exceptions in JSON; keep message human-readable for older clients.
    raise exception 'wacht 60 seconden';
  end if;

  -- Write `content_len` explicitly so reads stay fast even if triggers are temporarily disabled.
  insert into public.doodles (group_id, sender_profile_id, content_base64, content_len)
  values (gid, p_sender_profile_id, p_content_base64, content_len)
  returning id into did;

  -- Update streak: once per UTC day, increment if yesterday was last streak day, otherwise reset to 1.
  insert into public.member_streaks (group_id, profile_id, streak_count, last_streak_date)
  values (gid, p_sender_profile_id, 1, today)
  on conflict (group_id, profile_id) do update
  set
    streak_count = case
      when public.member_streaks.last_streak_date = today then public.member_streaks.streak_count
      when public.member_streaks.last_streak_date = (today - 1) then public.member_streaks.streak_count + 1
      else 1
    end,
    last_streak_date = today,
    updated_at = now();

  return did;
end;
$$;

grant execute on function public.create_doodle_secure(text, uuid, text, text) to anon;

-- Maintain `content_len` automatically (prevents expensive detoast/length() calls in read RPCs).
create or replace function public._set_doodle_content_len()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.content_base64 is null then
    new.content_len := null;
  else
    new.content_len := length(new.content_base64);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_doodle_content_len on public.doodles;
create trigger trg_set_doodle_content_len
before insert or update of content_base64 on public.doodles
for each row
execute procedure public._set_doodle_content_len();

-- Award XP for sending group doodls (runs on every insert).
create or replace function public._award_xp_for_doodle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set xp_total = coalesce(xp_total, 0) + 10
  where id = new.sender_profile_id;
  return new;
end;
$$;

drop trigger if exists trg_award_xp_doodle on public.doodles;
create trigger trg_award_xp_doodle
after insert on public.doodles
for each row
execute procedure public._award_xp_for_doodle();

-- Global leaderboards (daily + all-time) based on group doodls sent.
-- Returns top N + the requesting user's rank to show "you" even if outside top list.

drop function if exists public.leaderboard_total_secure(uuid, text, int);
create or replace function public.leaderboard_total_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 15
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  result jsonb;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  -- Deprecated: leaderboards removed from the app; keep RPC for backward compatibility.
  select jsonb_build_object(
    'top', '[]'::jsonb,
    'me', jsonb_build_object(
      'profile_id', p_profile_id,
      'username', (select p.username from public.profiles p where p.id = p_profile_id),
      'sent_count', 0,
      'rank', null
    )
  ) into result;

  return result;
end;
$$;

grant execute on function public.leaderboard_total_secure(uuid, text, int) to anon;

drop function if exists public.leaderboard_daily_secure(uuid, text, int);
create or replace function public.leaderboard_daily_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 15
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  result jsonb;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  -- Deprecated: leaderboards removed from the app; keep RPC for backward compatibility.
  select jsonb_build_object(
    'top', '[]'::jsonb,
    'me', jsonb_build_object(
      'profile_id', p_profile_id,
      'username', (select p.username from public.profiles p where p.id = p_profile_id),
      'sent_count', 0,
      'rank', null
    )
  ) into result;

  return result;
end;
$$;

grant execute on function public.leaderboard_daily_secure(uuid, text, int) to anon;

-- Presence ping (best-effort; requires no auth in this app)
drop function if exists public.update_presence_secure(uuid);
drop function if exists public.update_presence_secure(uuid, text);
create or replace function public.update_presence_secure(p_profile_id uuid, p_profile_pairing_code text)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  v timestamptz;
begin
  -- Performance: presence can be called very frequently; only write at most once per 30s
  -- to avoid row-lock contention with other profile updates (xp, username, avatar, etc).
  update public.profiles p
  set last_active_at = now()
  where p.id = p_profile_id
    and p.pairing_code = c
    and (p.last_active_at is null or p.last_active_at < now() - interval '30 seconds')
  returning p.last_active_at into v;

  if v is not null then
    return v;
  end if;

  -- No write (either too soon, or unauthorized). Return the existing timestamp for valid users.
  select p.last_active_at into v
  from public.profiles p
  where p.id = p_profile_id and p.pairing_code = c
  limit 1;

  if v is null then
    -- Either unauthorized, or the profile doesn't exist.
    if exists (select 1 from public.profiles p where p.id = p_profile_id) then
      raise exception 'unauthorized';
    end if;
    raise exception 'profile_not_found';
  end if;

  return v;
end;
$$;

grant execute on function public.update_presence_secure(uuid, text) to anon;

-- Secure RPC to fetch inbox doodls (requires membership)
drop function if exists public.inbox_doodles_secure(text, uuid, int);
create or replace function public.inbox_doodles_secure(p_code text, p_requester_profile_id uuid, p_limit int default 50)
returns table (
  doodle_id uuid,
  sender_profile_id uuid,
  content_base64 text,
  sender_username text,
  sender_is_pro boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  -- Privacy/UX: when a user joins an existing group, they should not see pre-join doodls.
  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  -- Performance: pick ids first using index-friendly filters, then fetch base64 only for the limited rows.
  return query
  with meta as materialized (
    select d.id, d.sender_profile_id, d.created_at
    from public.doodles d
    where d.group_id = gid
      and d.content_base64 is not null
      and d.is_removed = false
      and d.created_at >= joined_at
      and not exists (
        select 1
        from public.blocked_profiles b
        where b.profile_id = p_requester_profile_id and b.blocked_profile_id = d.sender_profile_id
      )
    order by d.created_at desc, d.id desc
    -- Hard cap to reduce base64 payload / statement timeouts (keeps UX fast).
    limit greatest(1, least(p_limit, 18))
  )
  select
    m.id as doodle_id,
    m.sender_profile_id,
    case
      when d.content_len is not null and d.content_len <= 600000 then d.content_base64
      when d.content_len is null and length(d.content_base64) <= 600000 then d.content_base64
      else null
    end as content_base64,
    p.username as sender_username,
    coalesce(p.is_pro, false) as sender_is_pro,
    m.created_at
  from meta m
  join public.doodles d on d.id = m.id
  join public.profiles p on p.id = m.sender_profile_id
  order by m.created_at desc, m.id desc;
end;
$$;

grant execute on function public.inbox_doodles_secure(text, uuid, int) to anon;

-- Note: for best performance in newer clients, prefer `inbox_doodle_metas_secure` + `doodle_contents_secure`
-- to avoid transferring large base64 payloads for the full inbox.
-- This project enforces a hard cap of 20 doodles per inbox fetch for performance.

-- Lightweight inbox metadata (no base64) to avoid timeouts on large payloads.
drop function if exists public.inbox_doodle_metas_secure(text, uuid, int);
create or replace function public.inbox_doodle_metas_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_limit int default 50
)
returns table (
  doodle_id uuid,
  sender_profile_id uuid,
  sender_username text,
  sender_is_pro boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  -- Hide pre-join doodls for users newly added to an existing group.
  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  -- Performance: pick ids first using index-friendly filters, then join profiles only for the capped rows.
  return query
  with meta as materialized (
    select d.id, d.sender_profile_id, d.created_at
    from public.doodles d
    where d.group_id = gid
      and d.content_base64 is not null
      and d.is_removed = false
      and d.created_at >= joined_at
      and not exists (
        select 1
        from public.blocked_profiles b
        where b.profile_id = p_requester_profile_id and b.blocked_profile_id = d.sender_profile_id
      )
    order by d.created_at desc, d.id desc
    limit greatest(1, least(p_limit, 18))
  )
  select m.id, m.sender_profile_id, p.username, coalesce(p.is_pro, false) as sender_is_pro, m.created_at
  from meta m
  join public.profiles p on p.id = m.sender_profile_id
  order by m.created_at desc, m.id desc;
end;
$$;

grant execute on function public.inbox_doodle_metas_secure(text, uuid, int) to anon;

-- Fetch doodle contents by ids (batched) for visible inbox items.
drop function if exists public.doodle_contents_secure(text, uuid, uuid[]);
create or replace function public.doodle_contents_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_doodle_ids uuid[]
)
returns table (
  doodle_id uuid,
  content_base64 text,
  sender_profile_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  lim int := 18;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  -- Defense-in-depth: never allow fetching pre-join doodl content by id.
  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  return query
  with input as materialized (
    select distinct x as id
    from unnest(coalesce(p_doodle_ids, array[]::uuid[])) as x
    where x is not null
    limit lim
  )
  select
    d.id,
    case
      when d.content_len is not null and d.content_len <= 600000 then d.content_base64
      when d.content_len is null and length(d.content_base64) <= 600000 then d.content_base64
      else null
    end as content_base64,
    d.sender_profile_id,
    d.created_at
  from input i
  join public.doodles d on d.id = i.id
  where d.group_id = gid
    and d.content_base64 is not null
    and d.is_removed = false
    and d.created_at >= joined_at
    and not exists (
      select 1
      from public.blocked_profiles b
      where b.profile_id = p_requester_profile_id and b.blocked_profile_id = d.sender_profile_id
    )
  order by d.created_at desc, d.id desc
  limit lim;
end;
$$;

grant execute on function public.doodle_contents_secure(text, uuid, uuid[]) to anon;

-- Doodle views (per-viewer read receipts)
create table if not exists public.doodle_views (
  doodle_id uuid not null references public.doodles (id) on delete cascade,
  viewer_profile_id uuid not null references public.profiles (id) on delete cascade,
  viewed_at timestamptz default now(),
  primary key (doodle_id, viewer_profile_id)
);

create index if not exists idx_doodle_views_viewer on public.doodle_views (viewer_profile_id, viewed_at desc);

alter table public.doodle_views enable row level security;

-- Inbox senders with unread counts (requires membership)
drop function if exists public.inbox_senders_secure(text, uuid);
create or replace function public.inbox_senders_secure(p_code text, p_requester_profile_id uuid)
returns table (
  sender_profile_id uuid,
  sender_username text,
  sender_avatar_url text,
  unread_count int,
  last_created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  return query
  select
    p.id as sender_profile_id,
    p.username as sender_username,
    p.avatar_url as sender_avatar_url,
    case
      when p.id = p_requester_profile_id then 0
      else coalesce((
        select count(*)
        from public.doodles d
        where d.group_id = gid
          and d.sender_profile_id = p.id
          and d.sender_profile_id <> p_requester_profile_id
          and d.content_base64 is not null
          and d.is_removed = false
          and d.created_at >= joined_at
          and not exists (
            select 1
            from public.doodle_views v
            where v.doodle_id = d.id and v.viewer_profile_id = p_requester_profile_id
          )
      ), 0)::int
    end as unread_count,
    (
      select max(d.created_at)
      from public.doodles d
      where d.group_id = gid
        and d.sender_profile_id = p.id
        and d.is_removed = false
        and d.created_at >= joined_at
    ) as last_created_at
  from public.group_members gm
  join public.profiles p on p.id = gm.profile_id
  where gm.group_id = gid
    and (
      p.id = p_requester_profile_id
      or not exists (
        select 1
        from public.blocked_profiles b
        where b.profile_id = p_requester_profile_id and b.blocked_profile_id = p.id
      )
    )
  order by
    unread_count desc,
    last_created_at desc nulls last,
    lower(p.username);
end;
$$;

grant execute on function public.inbox_senders_secure(text, uuid) to anon;

-- Blocking (user-generated content safety)
create table if not exists public.blocked_profiles (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  blocked_profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (profile_id, blocked_profile_id)
);

create index if not exists idx_blocked_profiles_profile on public.blocked_profiles (profile_id, created_at desc);
create index if not exists idx_blocked_profiles_pair on public.blocked_profiles (profile_id, blocked_profile_id);

alter table public.blocked_profiles enable row level security;

drop function if exists public.block_profile_secure(uuid, text, uuid);
create or replace function public.block_profile_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_blocked_profile_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if p_blocked_profile_id is null or p_blocked_profile_id = p_profile_id then
    raise exception 'invalid_target';
  end if;

  insert into public.blocked_profiles (profile_id, blocked_profile_id)
  values (p_profile_id, p_blocked_profile_id)
  on conflict do nothing;

  return 'ok';
end;
$$;

grant execute on function public.block_profile_secure(uuid, text, uuid) to anon;

drop function if exists public.unblock_profile_secure(uuid, text, uuid);
create or replace function public.unblock_profile_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_blocked_profile_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  delete from public.blocked_profiles
  where profile_id = p_profile_id and blocked_profile_id = p_blocked_profile_id;

  return 'ok';
end;
$$;

grant execute on function public.unblock_profile_secure(uuid, text, uuid) to anon;

-- Reports (notifies developer via DB table)
create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_profile_id uuid not null references public.profiles (id) on delete cascade,
  reported_profile_id uuid references public.profiles (id) on delete set null,
  reported_anonymous_fingerprint text,
  content_kind text not null, -- 'group_doodle' | 'anonymous_doodle'
  content_id uuid not null,
  group_id uuid references public.groups (id) on delete set null,
  reason text,
  created_at timestamptz default now(),
  resolved_at timestamptz,
  action_taken text,
  status text not null default 'pending'
);

create index if not exists idx_content_reports_created on public.content_reports (created_at desc);
create index if not exists idx_content_reports_status on public.content_reports (status, created_at desc);

alter table public.content_reports enable row level security;

-- Ensure moderation columns exist on older installs
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'content_reports' and column_name = 'reported_anonymous_fingerprint'
  ) then
    alter table public.content_reports add column reported_anonymous_fingerprint text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'content_reports' and column_name = 'resolved_at'
  ) then
    alter table public.content_reports add column resolved_at timestamptz;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'content_reports' and column_name = 'action_taken'
  ) then
    alter table public.content_reports add column action_taken text;
  end if;
end$$;

drop function if exists public.report_content_secure(uuid, text, text, uuid, text);
create or replace function public.report_content_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_content_kind text,
  p_content_id uuid,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  rid uuid;
  gid uuid;
  afp text;
  report_id uuid;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if p_content_kind = 'group_doodle' then
    select d.sender_profile_id, d.group_id into rid, gid
    from public.doodles d
    where d.id = p_content_id
    limit 1;

    if gid is null then
      raise exception 'not_found';
    end if;

    if not exists (
      select 1
      from public.group_members gm
      where gm.group_id = gid and gm.profile_id = p_profile_id
    ) then
      raise exception 'not_member';
    end if;
  elsif p_content_kind = 'anonymous_doodle' then
    -- Ensure the reporter is the recipient of this anonymous doodl.
    select d.sender_fingerprint into afp
    from public.anonymous_doodles d
    where d.id = p_content_id and d.recipient_profile_id = p_profile_id
    limit 1;

    if afp is null then
      -- Still allow reporting if the doodl exists but has no fingerprint, as long as it's theirs.
      if not exists (
        select 1
        from public.anonymous_doodles d
        where d.id = p_content_id and d.recipient_profile_id = p_profile_id
      ) then
        raise exception 'not_found';
      end if;
    end if;

    gid := null;
    rid := null;
  else
    raise exception 'invalid_kind';
  end if;

  insert into public.content_reports (
    reporter_profile_id,
    reported_profile_id,
    reported_anonymous_fingerprint,
    content_kind,
    content_id,
    group_id,
    reason
  )
  values (
    p_profile_id,
    rid,
    nullif(trim(afp), ''),
    p_content_kind,
    p_content_id,
    gid,
    nullif(trim(p_reason), '')
  )
  returning id into report_id;

  return report_id;
end;
$$;

grant execute on function public.report_content_secure(uuid, text, text, uuid, text) to anon;

-- Service/admin helper: resolve a content report by removing content and optionally ejecting a user.
drop function if exists public.resolve_content_report_service(uuid, text);
create or replace function public.resolve_content_report_service(
  p_report_id uuid,
  p_action text default 'remove_only' -- remove_only | remove_and_eject
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
  r public.content_reports%rowtype;
begin
  -- Allow from SQL editor (no JWT) or service_role; never allow anon/auth users.
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  select * into r
  from public.content_reports cr
  where cr.id = p_report_id
  limit 1;

  if not found then
    raise exception 'not_found';
  end if;

  if r.content_kind = 'group_doodle' then
    update public.doodles
    set is_removed = true
    where id = r.content_id;

    if p_action = 'remove_and_eject' and r.reported_profile_id is not null and r.group_id is not null then
      delete from public.group_members
      where group_id = r.group_id and profile_id = r.reported_profile_id;
    end if;
  elsif r.content_kind = 'anonymous_doodle' then
    update public.anonymous_doodles
    set is_removed = true
    where id = r.content_id;
  else
    raise exception 'invalid_kind';
  end if;

  update public.content_reports
  set
    status = 'resolved',
    resolved_at = now(),
    action_taken = p_action
  where id = p_report_id;

  return 'ok';
end;
$$;

-- Thread doodls for one sender (requires membership). Marks returned doodls as viewed for the requester.
drop function if exists public.thread_doodles_secure(text, uuid, uuid, int);
drop function if exists public.thread_doodles_secure(text, uuid, text, uuid, int);
create or replace function public.thread_doodles_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_requester_pairing_code text,
  p_sender_profile_id uuid,
  p_limit int default 200
)
returns table (
  doodle_id uuid,
  content_base64 text,
  sender_username text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  c text := lower(trim(p_requester_pairing_code));
  joined_at timestamptz;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_requester_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    raise exception 'not_member';
  end if;

  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_sender_profile_id
  ) then
    raise exception 'invalid_sender';
  end if;

  if exists (
    select 1
    from public.blocked_profiles b
    where b.profile_id = p_requester_profile_id and b.blocked_profile_id = p_sender_profile_id
  ) then
    return;
  end if;

  insert into public.doodle_views (doodle_id, viewer_profile_id)
  select d.id, p_requester_profile_id
  from public.doodles d
  where d.group_id = gid
    and d.created_at >= joined_at
    and d.sender_profile_id = p_sender_profile_id
    and d.sender_profile_id <> p_requester_profile_id
    and d.content_base64 is not null
    and d.is_removed = false
    and not exists (
      select 1
      from public.doodle_views v
      where v.doodle_id = d.id and v.viewer_profile_id = p_requester_profile_id
    )
  on conflict do nothing;

  return query
  select
    d.id,
    d.content_base64,
    p.username,
    d.created_at
  from public.doodles d
  join public.profiles p on p.id = d.sender_profile_id
  where d.group_id = gid
    and d.created_at >= joined_at
    and d.sender_profile_id = p_sender_profile_id
    and d.content_base64 is not null
    and d.is_removed = false
  order by d.created_at desc
  limit greatest(1, least(p_limit, 400));
end;
$$;

grant execute on function public.thread_doodles_secure(text, uuid, text, uuid, int) to anon;

-- APNs device tokens (one profile can have multiple devices)
create table if not exists public.profile_devices (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  apns_token text not null,
  environment text not null default 'sandbox', -- sandbox|production
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (profile_id, apns_token)
);

drop trigger if exists trg_set_updated_at_profile_devices on public.profile_devices;
create trigger trg_set_updated_at_profile_devices
before update on public.profile_devices
for each row execute procedure public.set_updated_at();

alter table public.profile_devices enable row level security;

-- No direct table access for anon; use SECURITY DEFINER RPC.
drop policy if exists "profile_devices_insert_anon" on public.profile_devices;
drop policy if exists "profile_devices_select_public" on public.profile_devices;
drop policy if exists "profile_devices_delete_anon" on public.profile_devices;

drop function if exists public.upsert_profile_device_secure(uuid, text, text, text);
create or replace function public.upsert_profile_device_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_apns_token text,
  p_environment text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  token text := lower(trim(p_apns_token));
  env text := lower(trim(p_environment));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if token is null or length(token) < 32 then
    raise exception 'invalid_token';
  end if;

  if env not in ('sandbox', 'production') then
    env := 'sandbox';
  end if;

  -- One token should map to exactly one profile: replace existing rows with this token.
  delete from public.profile_devices d where d.apns_token = token;

  insert into public.profile_devices (profile_id, apns_token, environment)
  values (p_profile_id, token, env)
  on conflict (profile_id, apns_token) do update
  set environment = excluded.environment, updated_at = now();

  return 'ok';
end;
$$;

grant execute on function public.upsert_profile_device_secure(uuid, text, text, text) to anon;

-- Anonymous doodle links + inbox (opt-in)
create table if not exists public.anonymous_links (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  short_code text not null,
  is_enabled boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index if not exists idx_anonymous_links_profile_id
on public.anonymous_links (profile_id);

create unique index if not exists idx_anonymous_links_short_code
on public.anonymous_links (short_code);

drop trigger if exists trg_set_updated_at_anonymous_links on public.anonymous_links;
create trigger trg_set_updated_at_anonymous_links
before update on public.anonymous_links
for each row execute procedure public.set_updated_at();

alter table public.anonymous_links enable row level security;

-- Ensure default-enabled for existing installs
alter table public.anonymous_links
  alter column is_enabled set default true;

-- Enable anonymous receiving for existing users (per product decision).
update public.anonymous_links
set is_enabled = true
where is_enabled = false;

create table if not exists public.anonymous_doodles (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.anonymous_links (id) on delete cascade,
  recipient_profile_id uuid not null references public.profiles (id) on delete cascade,
  sender_profile_id uuid references public.profiles (id) on delete set null,
  sender_fingerprint text,
  content_base64 text not null,
  content_len int,
  is_removed boolean not null default false,
  created_at timestamptz default now()
);

create index if not exists idx_anonymous_doodles_recipient_created
on public.anonymous_doodles (recipient_profile_id, created_at desc);

alter table public.anonymous_doodles enable row level security;

-- Ensure optional moderation columns exist on older installs
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anonymous_doodles' and column_name = 'sender_fingerprint'
  ) then
    alter table public.anonymous_doodles add column sender_fingerprint text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anonymous_doodles' and column_name = 'sender_profile_id'
  ) then
    alter table public.anonymous_doodles add column sender_profile_id uuid references public.profiles (id) on delete set null;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anonymous_doodles' and column_name = 'is_removed'
  ) then
    alter table public.anonymous_doodles add column is_removed boolean not null default false;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anonymous_doodles' and column_name = 'content_len'
  ) then
    alter table public.anonymous_doodles add column content_len int;
  end if;
end$$;

create or replace function public._set_anonymous_doodle_content_len()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.content_base64 is null then
    new.content_len := null;
  else
    new.content_len := length(new.content_base64);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_anonymous_doodle_content_len on public.anonymous_doodles;
create trigger trg_set_anonymous_doodle_content_len
before insert or update of content_base64 on public.anonymous_doodles
for each row
execute procedure public._set_anonymous_doodle_content_len();

create table if not exists public.blocked_anonymous_senders (
  recipient_profile_id uuid not null references public.profiles (id) on delete cascade,
  sender_fingerprint text not null,
  created_at timestamptz default now(),
  primary key (recipient_profile_id, sender_fingerprint)
);

create index if not exists idx_blocked_anonymous_senders_recipient
on public.blocked_anonymous_senders (recipient_profile_id, created_at desc);

alter table public.blocked_anonymous_senders enable row level security;

drop function if exists public.block_anonymous_sender_secure(uuid, text, text);
create or replace function public.block_anonymous_sender_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_sender_fingerprint text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  fp text := nullif(trim(p_sender_fingerprint), '');
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if fp is null or length(fp) < 6 or length(fp) > 200 then
    raise exception 'invalid_fingerprint';
  end if;

  insert into public.blocked_anonymous_senders (recipient_profile_id, sender_fingerprint)
  values (p_profile_id, fp)
  on conflict do nothing;

  return 'ok';
end;
$$;

grant execute on function public.block_anonymous_sender_secure(uuid, text, text) to anon;

drop function if exists public.set_anonymous_link_enabled_secure(uuid, text, boolean);
create or replace function public.set_anonymous_link_enabled_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_enabled boolean
)
returns table (short_code text, is_enabled boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  code text;
  inserted boolean := false;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select al.short_code into code
  from public.anonymous_links al
  where al.profile_id = p_profile_id
  limit 1;

  if code is null then
    -- Avoid extension-dependent generators; use built-in random() + time.
    for _ in 1..8 loop
      code := substr(md5(random()::text || clock_timestamp()::text || p_profile_id::text), 1, 14);
      begin
        insert into public.anonymous_links (profile_id, short_code, is_enabled)
        values (p_profile_id, code, p_enabled);
        inserted := true;
        exit;
      exception when unique_violation then
        -- Rare: short_code collision; retry.
      end;
    end loop;

    if not inserted then
      raise exception 'failed_to_generate_code';
    end if;
  else
    update public.anonymous_links
    set is_enabled = p_enabled
    where profile_id = p_profile_id;
  end if;

  return query
  select al.short_code, al.is_enabled
  from public.anonymous_links al
  where al.profile_id = p_profile_id
  limit 1;
end;
$$;

grant execute on function public.set_anonymous_link_enabled_secure(uuid, text, boolean) to anon;

drop function if exists public.get_anonymous_link_secure(uuid, text);
create or replace function public.get_anonymous_link_secure(
  p_profile_id uuid,
  p_profile_pairing_code text
)
returns table (short_code text, is_enabled boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  return query
  select al.short_code, al.is_enabled
  from public.anonymous_links al
  where al.profile_id = p_profile_id
  limit 1;
end;
$$;

grant execute on function public.get_anonymous_link_secure(uuid, text) to anon;

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
    end;
  end loop;

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

drop function if exists public.submit_anonymous_doodle(text, text);
drop function if exists public.submit_anonymous_doodle(text, text, text);
create or replace function public.submit_anonymous_doodle(
  p_short_code text,
  p_content_base64 text,
  p_sender_fingerprint text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  lid uuid;
  rid uuid;
  did uuid;
  code text := lower(trim(p_short_code));
  fp text := nullif(trim(p_sender_fingerprint), '');
  content_len int := length(coalesce(p_content_base64, ''));
begin
  if code is null or length(code) < 8 then
    raise exception 'invalid_code';
  end if;

  if p_content_base64 is null or content_len < 50 then
    raise exception 'invalid_content';
  end if;
  if content_len > 600000 then
    raise exception 'image_too_large: doodle te groot (probeer opnieuw)';
  end if;

  select al.id, al.profile_id into lid, rid
  from public.anonymous_links al
  where al.short_code = code and al.is_enabled = true
  limit 1;

  if lid is null or rid is null then
    raise exception 'not_found';
  end if;

  if fp is not null and exists (
    select 1
    from public.blocked_anonymous_senders b
    where b.recipient_profile_id = rid and b.sender_fingerprint = fp
  ) then
    raise exception 'blocked';
  end if;

  insert into public.anonymous_doodles (link_id, recipient_profile_id, content_base64, content_len, sender_fingerprint)
  values (
    lid,
    rid,
    p_content_base64,
    content_len,
    case when fp is not null and length(fp) between 6 and 200 then fp else null end
  )
  returning id into did;

  return did;
end;
$$;

grant execute on function public.submit_anonymous_doodle(text, text, text) to anon;

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
  content_len int := length(coalesce(p_content_base64, ''));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_sender_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if p_recipient_profile_id is null then
    raise exception 'not_found';
  end if;

  if p_content_base64 is null or content_len < 50 then
    raise exception 'invalid_content';
  end if;
  if content_len > 600000 then
    raise exception 'image_too_large: doodle te groot (probeer opnieuw)';
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

  insert into public.anonymous_doodles (link_id, recipient_profile_id, content_base64, content_len, sender_fingerprint, sender_profile_id)
  values (
    lid,
    p_recipient_profile_id,
    p_content_base64,
    content_len,
    case when fp is not null and length(fp) between 6 and 200 then fp else null end,
    p_sender_profile_id
  )
  returning id into did;

  return did;
end;
$$;

grant execute on function public.submit_anonymous_doodle_to_profile_secure(uuid, text, uuid, text, text) to anon;

-- Award XP for in-app anonymous doodle sends (when sender_profile_id is known).
create or replace function public._award_xp_for_anonymous_doodle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sender_profile_id is not null then
    update public.profiles
    set xp_total = coalesce(xp_total, 0) + 10
    where id = new.sender_profile_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_award_xp_anonymous_doodle on public.anonymous_doodles;
create trigger trg_award_xp_anonymous_doodle
after insert on public.anonymous_doodles
for each row
execute procedure public._award_xp_for_anonymous_doodle();

drop function if exists public.anonymous_link_is_enabled_public(text);
create or replace function public.anonymous_link_is_enabled_public(
  p_short_code text
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.anonymous_links al
    where al.short_code = lower(trim(p_short_code)) and al.is_enabled = true
  );
$$;

grant execute on function public.anonymous_link_is_enabled_public(text) to anon;

drop function if exists public.anonymous_inbox_doodles_secure(uuid, text, int);
create or replace function public.anonymous_inbox_doodles_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 50
)
returns table (id uuid, content_base64 text, sender_fingerprint text, created_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  return query
  select
    d.id,
    case
      when d.content_len is not null and d.content_len <= 600000 then d.content_base64
      when d.content_len is null and length(d.content_base64) <= 600000 then d.content_base64
      else null
    end as content_base64,
    d.sender_fingerprint,
    d.created_at
  from public.anonymous_doodles d
  where d.recipient_profile_id = p_profile_id
    and d.is_removed = false
    and (
      d.sender_fingerprint is null
      or not exists (
        select 1
        from public.blocked_anonymous_senders b
        where b.recipient_profile_id = p_profile_id and b.sender_fingerprint = d.sender_fingerprint
      )
    )
  order by d.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

grant execute on function public.anonymous_inbox_doodles_secure(uuid, text, int) to anon;

-- Android beta waitlist (public submission via RPC).
create table if not exists public.android_beta_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  source text,
  created_at timestamptz default now()
);

create unique index if not exists android_beta_waitlist_email_key
  on public.android_beta_waitlist (email);

alter table public.android_beta_waitlist enable row level security;

drop function if exists public.submit_android_beta_email(text, text);
create or replace function public.submit_android_beta_email(
  p_email text,
  p_source text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_email text := lower(trim(p_email));
  clean_source text := nullif(trim(p_source), '');
begin
  if clean_email is null or length(clean_email) < 5 or position('@' in clean_email) = 0 then
    raise exception 'invalid_email';
  end if;

  insert into public.android_beta_waitlist (email, source)
  values (clean_email, clean_source)
  on conflict (email) do update
    set source = coalesce(excluded.source, public.android_beta_waitlist.source);
end;
$$;

grant execute on function public.submit_android_beta_email(text, text) to anon;

-- Broadcast pushes (manual, service-only).
do $$
begin
  alter table public.push_jobs drop constraint if exists push_jobs_kind_check;
  alter table public.push_jobs
    add constraint push_jobs_kind_check
    check (kind in ('group', 'anonymous', 'friend_request', 'group_invite', 'broadcast')) not valid;
  alter table public.push_jobs validate constraint push_jobs_kind_check;
exception
  when undefined_table then
    -- push_jobs not created yet; skip.
    null;
end$$;

create table if not exists public.push_broadcasts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  data jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_push_broadcasts_created
  on public.push_broadcasts (created_at desc);

alter table public.push_broadcasts enable row level security;

drop function if exists public.enqueue_broadcast_push_jobs(text, text, jsonb);
create or replace function public.enqueue_broadcast_push_jobs(
  p_title text,
  p_body text,
  p_data jsonb default null
)
returns table (broadcast_id uuid, job_count int)
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
  bid uuid;
  inserted_count int := 0;
  clean_title text := nullif(trim(p_title), '');
  clean_body text := nullif(trim(p_body), '');
begin
  -- Allow from SQL editor (no JWT) or service_role; never allow anon/auth users.
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  if clean_title is null then
    raise exception 'invalid_title';
  end if;

  if clean_body is null then
    raise exception 'invalid_body';
  end if;

  insert into public.push_broadcasts (title, body, data)
  values (clean_title, clean_body, p_data)
  returning id into bid;

  insert into public.push_jobs (kind, content_id, recipient_profile_id, status)
  select 'broadcast', bid, d.profile_id, 'pending'
  from public.profile_devices d
  where d.apns_token is not null
  group by d.profile_id;

  get diagnostics inserted_count = row_count;

  return query select bid, inserted_count;
end;
$$;
