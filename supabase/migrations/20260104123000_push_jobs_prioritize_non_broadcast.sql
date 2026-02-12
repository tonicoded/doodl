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
