-- Remove a friend (and their direct chat thread) safely.
-- Additive: existing App Store builds keep working.

drop function if exists public.remove_friend_secure(uuid, text, uuid);
create or replace function public.remove_friend_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_friend_profile_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  a uuid := least(p_profile_id, p_friend_profile_id);
  b uuid := greatest(p_profile_id, p_friend_profile_id);
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

  -- Delete both friend edges (idempotent).
  delete from public.friends f
  where (f.profile_id = p_profile_id and f.friend_profile_id = p_friend_profile_id)
     or (f.profile_id = p_friend_profile_id and f.friend_profile_id = p_profile_id);

  -- Clear any pending requests between the two.
  delete from public.friend_requests fr
  where (fr.requester_profile_id = p_profile_id and fr.target_profile_id = p_friend_profile_id and fr.status = 'pending')
     or (fr.requester_profile_id = p_friend_profile_id and fr.target_profile_id = p_profile_id and fr.status = 'pending');

  -- Remove direct thread mapping + membership (if it exists).
  select dt.group_id into gid
  from public.direct_threads dt
  where dt.profile_a = a and dt.profile_b = b
  limit 1;

  if gid is not null then
    delete from public.group_members gm
    where gm.group_id = gid and gm.profile_id in (p_profile_id, p_friend_profile_id);

    delete from public.direct_threads dt
    where dt.profile_a = a and dt.profile_b = b;
  end if;

  return 'ok';
end;
$$;

grant execute on function public.remove_friend_secure(uuid, text, uuid) to anon;
