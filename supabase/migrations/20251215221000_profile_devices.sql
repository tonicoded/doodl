-- device tokens for apns push notifications

create table if not exists public.profile_devices (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  apns_token text not null,
  environment text not null default 'sandbox', -- sandbox|production
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  primary key (profile_id, apns_token)
);

-- updated_at trigger (assumes public.set_updated_at exists)
drop trigger if exists trg_set_updated_at_profile_devices on public.profile_devices;
create trigger trg_set_updated_at_profile_devices
before update on public.profile_devices
for each row execute procedure public.set_updated_at();

alter table public.profile_devices enable row level security;

drop policy if exists "profile_devices_insert_anon" on public.profile_devices;
create policy "profile_devices_insert_anon" on public.profile_devices
for insert to anon
with check (true);

drop policy if exists "profile_devices_select_public" on public.profile_devices;
create policy "profile_devices_select_public" on public.profile_devices
for select using (true);

drop policy if exists "profile_devices_delete_anon" on public.profile_devices;
create policy "profile_devices_delete_anon" on public.profile_devices
for delete to anon
using (true);

