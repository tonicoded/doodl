-- Award XP for in-app anonymous doodle sends (when sender_profile_id is known).

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anonymous_doodles' and column_name = 'sender_profile_id'
  ) then
    alter table public.anonymous_doodles
      add column sender_profile_id uuid references public.profiles (id) on delete set null;
  end if;
end$$;

create or replace function public._award_xp_for_anonymous_doodle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sender_profile_id is not null then
    update public.profiles
    set xp_total = coalesce(xp_total, 0) + 10
    where id = new.sender_profile_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_award_xp_anonymous_doodle on public.anonymous_doodles;
create trigger trg_award_xp_anonymous_doodle
after insert on public.anonymous_doodles
for each row
execute procedure public._award_xp_for_anonymous_doodle();

