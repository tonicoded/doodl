-- Add a server-side Pro flag so other users can see a crown badge.
-- Safe + additive: older app builds ignore extra JSON fields.

alter table public.profiles
  add column if not exists is_pro boolean not null default false;

