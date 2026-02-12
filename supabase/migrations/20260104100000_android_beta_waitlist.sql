-- Android beta waitlist (public submission via RPC).

create table if not exists public.android_beta_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  source text,
  created_at timestamptz default now()
);

create unique index if not exists android_beta_waitlist_email_key
  on public.android_beta_waitlist (email);

alter table public.android_beta_waitlist enable row level security;

drop function if exists public.submit_android_beta_email(text, text);
create or replace function public.submit_android_beta_email(
  p_email text,
  p_source text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_email text := lower(trim(p_email));
  clean_source text := nullif(trim(p_source), '');
begin
  if clean_email is null or length(clean_email) < 5 or position('@' in clean_email) = 0 then
    raise exception 'invalid_email';
  end if;

  insert into public.android_beta_waitlist (email, source)
  values (clean_email, clean_source)
  on conflict (email) do update
    set source = coalesce(excluded.source, public.android_beta_waitlist.source);
end;
$$;

grant execute on function public.submit_android_beta_email(text, text) to anon;
