# doodl-push (supabase edge function)

sends apns push notifications:
- group doodls: to all devices in a group when a new row is inserted into `public.doodles`
- anonymous doodls: to the recipient's devices when a new row is inserted into `public.anonymous_doodles`

## required supabase db

run the latest `supabase_schema.sql` in the supabase sql editor (it adds `public.profile_devices`).

## required function secrets (supabase dashboard → edge functions → secrets)

- `APP_SUPABASE_URL`: your project url
- `APP_SUPABASE_SERVICE_ROLE_KEY`: service role key (never use anon here)
- `APNS_KEY_ID`: e.g. `PG3LJB7CYK`
- `APNS_TEAM_ID`: your apple developer team id
- `APNS_PRIVATE_KEY`: contents of the `.p8` file (keep newlines; if you paste as one line, replace newlines with `\n`)
- `APNS_BUNDLE_ID`: your ios bundle id (apns topic), e.g. `com.anthonyverruijt.doodl`
- `DOODL_WEBHOOK_SECRET`: any random string (used to protect the endpoint)

## deploy (supabase cli)

from this repo:

```sh
supabase functions deploy doodl-push --no-verify-jwt
```

## recommended: queue-based worker (avoids DB overload)

Database webhooks run *inside* Postgres transactions and can block inserts under load.
For production stability, enqueue push jobs in Postgres and process them asynchronously.

1) Apply the migration `supabase/migrations/20251229002000_push_queue.sql` (creates `public.push_jobs` + enqueue triggers).
2) Deploy the worker function:

```sh
supabase functions deploy doodl-push-worker --no-verify-jwt
```

3) Add a scheduled job in Supabase Dashboard (Edge Functions → Scheduled) to call:

- URL: `https://<project-ref>.supabase.co/functions/v1/doodl-push-worker?limit=50`
- Header: `x-doodl-secret: <DOODL_WEBHOOK_SECRET or DOODL_WORKER_SECRET>`
- Interval: start with 10–30 seconds

You can keep `doodl-push` for manual testing, but avoid DB webhooks on `doodles`/`anonymous_doodles`.

## ios app

the app registers apns tokens and upserts into `public.profile_devices` via `SupabaseService.upsertApnsDeviceToken(...)`.
