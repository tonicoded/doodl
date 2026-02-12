# revenuecat-webhook

Updates `public.profiles.is_pro` when RevenueCat sends subscription webhooks.

## Required secrets

- `APP_SUPABASE_URL`
- `APP_SUPABASE_SERVICE_ROLE_KEY`

## Optional secrets (recommended)

- `REVENUECAT_WEBHOOK_SECRET` (string)

If set, the webhook must send either:
- `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>` (or raw value), or
- `x-revenuecat-secret: <REVENUECAT_WEBHOOK_SECRET>`

## Deploy

RevenueCat does not send a Supabase JWT, so deploy without JWT verification:

```bash
supabase functions deploy revenuecat-webhook --no-verify-jwt
```
