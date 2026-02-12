-- Push queue to avoid blocking inserts with DB webhooks.

create table if not exists public.push_jobs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('group', 'anonymous')),
  content_id uuid not null,
  group_id uuid references public.groups (id) on delete cascade,
  sender_profile_id uuid references public.profiles (id) on delete set null,
  recipient_profile_id uuid references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'processing', 'done', 'failed')),
  attempt_count int not null default 0,
  locked_at timestamptz,
  last_error text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_push_jobs_pending_created
  on public.push_jobs (created_at asc)
  where status = 'pending';

create index if not exists idx_push_jobs_status_updated
  on public.push_jobs (status, updated_at desc);

alter table public.push_jobs enable row level security;

-- Enqueue helpers (fast, non-blocking).
create or replace function public._enqueue_group_push_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_jobs (kind, content_id, group_id, sender_profile_id, status)
  values ('group', new.id, new.group_id, new.sender_profile_id, 'pending');
  return new;
end;
$$;

create or replace function public._enqueue_anonymous_push_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_jobs (kind, content_id, recipient_profile_id, status)
  values ('anonymous', new.id, new.recipient_profile_id, 'pending');
  return new;
end;
$$;

drop trigger if exists trg_enqueue_group_push_job on public.doodles;
create trigger trg_enqueue_group_push_job
after insert on public.doodles
for each row
execute procedure public._enqueue_group_push_job();

drop trigger if exists trg_enqueue_anonymous_push_job on public.anonymous_doodles;
create trigger trg_enqueue_anonymous_push_job
after insert on public.anonymous_doodles
for each row
execute procedure public._enqueue_anonymous_push_job();

-- Service-only: claim N jobs atomically.
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
    order by pj.created_at asc
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

-- Service-only: complete a job.
drop function if exists public.complete_push_job_service(uuid, boolean, text);
create or replace function public.complete_push_job_service(
  p_job_id uuid,
  p_ok boolean,
  p_error text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  role_claim text := current_setting('request.jwt.claim.role', true);
begin
  if role_claim is not null and role_claim <> 'service_role' then
    raise exception 'unauthorized';
  end if;

  update public.push_jobs pj
  set
    status = case when p_ok then 'done' else 'failed' end,
    last_error = case when p_ok then null else nullif(trim(p_error), '') end,
    locked_at = null,
    updated_at = now()
  where pj.id = p_job_id;

  return 'ok';
end;
$$;
