-- enforce one owner per token+environment (so tokens always map to current account on that device)

create unique index if not exists idx_profile_devices_token_env
on public.profile_devices (apns_token, environment);

