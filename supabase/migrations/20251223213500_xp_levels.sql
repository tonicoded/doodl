-- XP + levels for profiles (awarded when sending group doodls).

-- Add xp_total to profiles (safe for older installs).
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'xp_total'
  ) then
    alter table public.profiles add column xp_total int not null default 0;
  end if;
end$$;

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

-- Read current XP + derived level state (secure, no direct table access).
drop function if exists public.profile_xp_secure(uuid, text);
create or replace function public.profile_xp_secure(p_profile_id uuid, p_profile_pairing_code text)
returns table (
  xp_total int,
  level int,
  level_xp int,
  next_level_xp int
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

  return query select total, lvl, remaining, needed;
end;
$$;

grant execute on function public.profile_xp_secure(uuid, text) to anon;

-- Award XP when a group doodl is created (hook into existing secure RPC).
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
