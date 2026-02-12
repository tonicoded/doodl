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
