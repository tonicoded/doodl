-- Push jobs for friend requests and group invites.

do $$
begin
  alter table public.push_jobs drop constraint if exists push_jobs_kind_check;
  alter table public.push_jobs
    add constraint push_jobs_kind_check
    check (kind in ('group', 'anonymous', 'friend_request', 'group_invite')) not valid;
  alter table public.push_jobs validate constraint push_jobs_kind_check;
exception
  when undefined_table then
    -- push_jobs not created yet; skip.
    null;
end$$;

create or replace function public._enqueue_friend_request_push_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;

  insert into public.push_jobs (kind, content_id, sender_profile_id, recipient_profile_id, status)
  values ('friend_request', new.id, new.requester_profile_id, new.target_profile_id, 'pending');
  return new;
end;
$$;

create or replace function public._enqueue_group_invite_push_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;

  insert into public.push_jobs (kind, content_id, group_id, sender_profile_id, recipient_profile_id, status)
  values ('group_invite', new.id, new.group_id, new.inviter_profile_id, new.invited_profile_id, 'pending');
  return new;
end;
$$;

drop trigger if exists trg_enqueue_friend_request_push_job on public.friend_requests;
create trigger trg_enqueue_friend_request_push_job
after insert on public.friend_requests
for each row
execute procedure public._enqueue_friend_request_push_job();

drop trigger if exists trg_enqueue_group_invite_push_job on public.group_invites;
create trigger trg_enqueue_group_invite_push_job
after insert on public.group_invites
for each row
execute procedure public._enqueue_group_invite_push_job();
