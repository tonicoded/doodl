-- Android push notifications: store FCM tokens per profile.

create table if not exists public.profile_fcm_devices (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (profile_id, fcm_token)
);

create index if not exists idx_profile_fcm_devices_token
on public.profile_fcm_devices (fcm_token);

alter table public.profile_fcm_devices enable row level security;

-- No direct table access for anon; use SECURITY DEFINER RPC.
drop policy if exists "profile_fcm_devices_insert_anon" on public.profile_fcm_devices;
drop policy if exists "profile_fcm_devices_select_public" on public.profile_fcm_devices;
drop policy if exists "profile_fcm_devices_delete_anon" on public.profile_fcm_devices;

drop trigger if exists trg_set_updated_at_profile_fcm_devices on public.profile_fcm_devices;
create trigger trg_set_updated_at_profile_fcm_devices
before update on public.profile_fcm_devices
for each row execute procedure public.set_updated_at();

drop function if exists public.upsert_profile_fcm_device_secure(uuid, text, text);
create or replace function public.upsert_profile_fcm_device_secure(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_fcm_token text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  token text := nullif(trim(p_fcm_token), '');
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  if token is null or length(token) < 20 then
    raise exception 'invalid_token';
  end if;

  -- One token should map to exactly one profile: replace existing rows with this token.
  delete from public.profile_fcm_devices d where d.fcm_token = token;

  insert into public.profile_fcm_devices (profile_id, fcm_token)
  values (p_profile_id, token)
  on conflict (profile_id, fcm_token) do update
  set updated_at = now();

  return 'ok';
end;
$$;

grant execute on function public.upsert_profile_fcm_device_secure(uuid, text, text) to anon;

