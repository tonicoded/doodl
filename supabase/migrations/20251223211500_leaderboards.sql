-- Global leaderboards (daily + all-time) based on group doodls sent.
-- Returns top N + the requesting user's rank to show "you" even if outside top list.

-- Performance for global sender aggregation (used by leaderboard RPCs).
create index if not exists idx_doodles_sender_created_active
  on public.doodles (sender_profile_id, created_at desc)
  where is_removed = false and content_base64 is not null;

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
