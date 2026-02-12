-- Add optional streak_count to direct chat list (v2) without breaking older clients.
-- Uses member_streaks maintained by create_doodle_secure for both groups and direct chats.

drop function if exists public.list_direct_chats_secure_v2(uuid, text, int);
create or replace function public.list_direct_chats_secure_v2(
  p_profile_id uuid,
  p_profile_pairing_code text,
  p_limit int default 50
)
returns table (
  code text,
  other_profile_id uuid,
  other_username text,
  other_avatar_url text,
  other_is_pro boolean,
  last_created_at timestamptz,
  has_unread boolean,
  streak_count int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text := lower(trim(p_profile_pairing_code));
  lim int := greatest(1, least(coalesce(p_limit, 50), 200));
  today date := (now() at time zone 'utc')::date;
begin
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id and p.pairing_code = c
  ) then
    raise exception 'unauthorized';
  end if;

  return query
  with threads as (
    select
      dt.group_id,
      case when dt.profile_a = p_profile_id then dt.profile_b else dt.profile_a end as other_id
    from public.direct_threads dt
    where dt.profile_a = p_profile_id or dt.profile_b = p_profile_id
  ),
  base as (
    select
      g.code,
      t.other_id as other_profile_id,
      p.username as other_username,
      p.avatar_url as other_avatar_url,
      coalesce(p.is_pro, false) as other_is_pro,
      (
        select d.created_at
        from public.doodles d
        where d.group_id = t.group_id
          and d.is_removed = false
          and d.content_base64 is not null
        order by d.created_at desc
        limit 1
      ) as last_created_at,
      exists (
        select 1
        from public.doodles d
        where d.group_id = t.group_id
          and d.sender_profile_id = t.other_id
          and d.is_removed = false
          and d.content_base64 is not null
          and not exists (
            select 1 from public.doodle_views v
            where v.doodle_id = d.id and v.viewer_profile_id = p_profile_id
          )
      ) as has_unread,
      least(
        coalesce(
          case
            when ms_me.last_streak_date is null then 0
            when ms_me.last_streak_date = today then ms_me.streak_count
            when ms_me.last_streak_date = (today - 1) then ms_me.streak_count
            else 0
          end,
          0
        ),
        coalesce(
          case
            when ms_other.last_streak_date is null then 0
            when ms_other.last_streak_date = today then ms_other.streak_count
            when ms_other.last_streak_date = (today - 1) then ms_other.streak_count
            else 0
          end,
          0
        )
      )::int as streak_count
    from threads t
    join public.groups g on g.id = t.group_id
    join public.profiles p on p.id = t.other_id
    left join public.member_streaks ms_me on ms_me.group_id = t.group_id and ms_me.profile_id = p_profile_id
    left join public.member_streaks ms_other on ms_other.group_id = t.group_id and ms_other.profile_id = t.other_id
    where g.kind = 'direct'
  )
  select
    b.code,
    b.other_profile_id,
    b.other_username,
    b.other_avatar_url,
    b.other_is_pro,
    b.last_created_at,
    b.has_unread,
    b.streak_count
  from base b
  order by b.has_unread desc, b.last_created_at desc nulls last, lower(b.other_username) asc
  limit lim;
end;
$$;

grant execute on function public.list_direct_chats_secure_v2(uuid, text, int) to anon;
