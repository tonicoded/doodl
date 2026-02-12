-- Hide pre-join group doodls (privacy/UX).
-- Run in Supabase SQL editor.
-- Safe for existing clients: this only affects what members can READ after joining a group.

create or replace function public.inbox_doodles_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_limit int default 50
)
returns table (
  doodle_id uuid,
  sender_profile_id uuid,
  content_base64 text,
  sender_username text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  -- Privacy/UX: when a user joins an existing group, they should not see pre-join doodls.
  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  -- Performance: pick ids first using index-friendly filters, then fetch base64 only for the limited rows.
  return query
  with meta as materialized (
    select d.id, d.sender_profile_id, d.created_at
    from public.doodles d
    where d.group_id = gid
      and d.content_base64 is not null
      and d.is_removed = false
      and d.created_at >= joined_at
      and not exists (
        select 1
        from public.blocked_profiles b
        where b.profile_id = p_requester_profile_id and b.blocked_profile_id = d.sender_profile_id
      )
    order by d.created_at desc, d.id desc
    -- Hard cap to reduce base64 payload / statement timeouts (keeps UX fast).
    limit greatest(1, least(p_limit, 18))
  )
  select
    m.id as doodle_id,
    m.sender_profile_id,
    case
      when d.content_len is not null and d.content_len <= 600000 then d.content_base64
      when d.content_len is null and length(d.content_base64) <= 600000 then d.content_base64
      else null
    end as content_base64,
    p.username as sender_username,
    m.created_at
  from meta m
  join public.doodles d on d.id = m.id
  join public.profiles p on p.id = m.sender_profile_id
  order by m.created_at desc, m.id desc;
end;
$$;

grant execute on function public.inbox_doodles_secure(text, uuid, int) to anon;

create or replace function public.inbox_doodle_metas_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_limit int default 50
)
returns table (
  doodle_id uuid,
  sender_profile_id uuid,
  sender_username text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  -- Hide pre-join doodls for users newly added to an existing group.
  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  -- Performance: pick ids first using index-friendly filters, then join profiles only for the capped rows.
  return query
  with meta as materialized (
    select d.id, d.sender_profile_id, d.created_at
    from public.doodles d
    where d.group_id = gid
      and d.content_base64 is not null
      and d.is_removed = false
      and d.created_at >= joined_at
      and not exists (
        select 1
        from public.blocked_profiles b
        where b.profile_id = p_requester_profile_id and b.blocked_profile_id = d.sender_profile_id
      )
    order by d.created_at desc, d.id desc
    limit greatest(1, least(p_limit, 18))
  )
  select m.id, m.sender_profile_id, p.username, m.created_at
  from meta m
  join public.profiles p on p.id = m.sender_profile_id
  order by m.created_at desc, m.id desc;
end;
$$;

grant execute on function public.inbox_doodle_metas_secure(text, uuid, int) to anon;

create or replace function public.doodle_contents_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_doodle_ids uuid[]
)
returns table (
  doodle_id uuid,
  content_base64 text,
  sender_profile_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  lim int := 18;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  -- Defense-in-depth: never allow fetching pre-join doodl content by id.
  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  return query
  with input as materialized (
    select distinct x as id
    from unnest(coalesce(p_doodle_ids, array[]::uuid[])) as x
    where x is not null
    limit lim
  )
  select
    d.id,
    case
      when d.content_len is not null and d.content_len <= 600000 then d.content_base64
      when d.content_len is null and length(d.content_base64) <= 600000 then d.content_base64
      else null
    end as content_base64,
    d.sender_profile_id,
    d.created_at
  from input i
  join public.doodles d on d.id = i.id
  where d.group_id = gid
    and d.content_base64 is not null
    and d.is_removed = false
    and d.created_at >= joined_at
    and not exists (
      select 1
      from public.blocked_profiles b
      where b.profile_id = p_requester_profile_id and b.blocked_profile_id = d.sender_profile_id
    )
  order by d.created_at desc, d.id desc
  limit lim;
end;
$$;

grant execute on function public.doodle_contents_secure(text, uuid, uuid[]) to anon;

create or replace function public.inbox_senders_secure(p_code text, p_requester_profile_id uuid)
returns table (
  sender_profile_id uuid,
  sender_username text,
  sender_avatar_url text,
  unread_count int,
  last_created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  joined_at timestamptz;
begin
  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    return;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    return;
  end if;

  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  return query
  select
    p.id as sender_profile_id,
    p.username as sender_username,
    p.avatar_url as sender_avatar_url,
    case
      when p.id = p_requester_profile_id then 0
      else coalesce((
        select count(*)
        from public.doodles d
        where d.group_id = gid
          and d.sender_profile_id = p.id
          and d.sender_profile_id <> p_requester_profile_id
          and d.content_base64 is not null
          and d.is_removed = false
          and d.created_at >= joined_at
          and not exists (
            select 1
            from public.doodle_views v
            where v.doodle_id = d.id and v.viewer_profile_id = p_requester_profile_id
          )
      ), 0)::int
    end as unread_count,
    (
      select max(d.created_at)
      from public.doodles d
      where d.group_id = gid
        and d.sender_profile_id = p.id
        and d.is_removed = false
        and d.created_at >= joined_at
    ) as last_created_at
  from public.group_members gm
  join public.profiles p on p.id = gm.profile_id
  where gm.group_id = gid
    and (
      p.id = p_requester_profile_id
      or not exists (
        select 1
        from public.blocked_profiles b
        where b.profile_id = p_requester_profile_id and b.blocked_profile_id = p.id
      )
    )
  order by
    unread_count desc,
    last_created_at desc nulls last,
    lower(p.username);
end;
$$;

grant execute on function public.inbox_senders_secure(text, uuid) to anon;

create or replace function public.thread_doodles_secure(
  p_code text,
  p_requester_profile_id uuid,
  p_requester_pairing_code text,
  p_sender_profile_id uuid,
  p_limit int default 200
)
returns table (
  doodle_id uuid,
  content_base64 text,
  sender_username text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  gid uuid;
  c text := lower(trim(p_requester_pairing_code));
  joined_at timestamptz;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_requester_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  select g.id into gid
  from public.groups g
  where g.code = lower(p_code)
  limit 1;

  if gid is null then
    raise exception 'invalid_code';
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  ) then
    raise exception 'not_member';
  end if;

  select gm.created_at into joined_at
  from public.group_members gm
  where gm.group_id = gid and gm.profile_id = p_requester_profile_id
  limit 1;

  if joined_at is null then
    joined_at := '-infinity'::timestamptz;
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = gid and gm.profile_id = p_sender_profile_id
  ) then
    raise exception 'invalid_sender';
  end if;

  if exists (
    select 1
    from public.blocked_profiles b
    where b.profile_id = p_requester_profile_id and b.blocked_profile_id = p_sender_profile_id
  ) then
    return;
  end if;

  insert into public.doodle_views (doodle_id, viewer_profile_id)
  select d.id, p_requester_profile_id
  from public.doodles d
  where d.group_id = gid
    and d.created_at >= joined_at
    and d.sender_profile_id = p_sender_profile_id
    and d.sender_profile_id <> p_requester_profile_id
    and d.content_base64 is not null
    and d.is_removed = false
    and not exists (
      select 1
      from public.doodle_views v
      where v.doodle_id = d.id and v.viewer_profile_id = p_requester_profile_id
    )
  on conflict do nothing;

  return query
  select
    d.id,
    d.content_base64,
    p.username,
    d.created_at
  from public.doodles d
  join public.profiles p on p.id = d.sender_profile_id
  where d.group_id = gid
    and d.created_at >= joined_at
    and d.sender_profile_id = p_sender_profile_id
    and d.content_base64 is not null
    and d.is_removed = false
  order by d.created_at desc
  limit greatest(1, least(p_limit, 400));
end;
$$;

grant execute on function public.thread_doodles_secure(text, uuid, text, uuid, int) to anon;
