#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_REF="${PROJECT_REF:-jgunrdhmipqltddbnnyb}"
SUPABASE_URL="${SUPABASE_URL:-https://${PROJECT_REF}.supabase.co}"

echo "project: ${PROJECT_REF}"
echo "function: doodl-push"
echo "function: doodl-push-worker"
echo

if ! command -v supabase >/dev/null 2>&1; then
  echo "supabase cli not found"
  exit 1
fi

read -rp "apns key id (kid) [PG3LJB7CYK]: " APNS_KEY_ID
APNS_KEY_ID="${APNS_KEY_ID:-PG3LJB7CYK}"

read -rp "apple team id (iss): " APNS_TEAM_ID
if [[ -z "${APNS_TEAM_ID}" ]]; then
  echo "team id is required"
  exit 1
fi

read -rp "ios bundle id (apns topic, e.g. com.your.app): " APNS_BUNDLE_ID
if [[ -z "${APNS_BUNDLE_ID}" ]]; then
  echo "bundle id is required"
  exit 1
fi

read -rsp "supabase service role key: " APP_SUPABASE_SERVICE_ROLE_KEY
echo
if [[ -z "${APP_SUPABASE_SERVICE_ROLE_KEY}" ]]; then
  echo "service role key is required"
  exit 1
fi

DOODL_WEBHOOK_SECRET="$(openssl rand -hex 16)"
echo "generated DOODL_WEBHOOK_SECRET: ${DOODL_WEBHOOK_SECRET}"
echo "(copy this into your Supabase DB webhook header x-doodl-secret)"
echo

if [[ -n "${APNS_PRIVATE_KEY:-}" ]]; then
  APNS_PRIVATE_KEY_CONTENT="${APNS_PRIVATE_KEY}"
elif [[ -n "${APNS_PRIVATE_KEY_FILE:-}" ]]; then
  if [[ ! -f "${APNS_PRIVATE_KEY_FILE}" ]]; then
    echo "APNS_PRIVATE_KEY_FILE does not exist: ${APNS_PRIVATE_KEY_FILE}"
    exit 1
  fi
  APNS_PRIVATE_KEY_CONTENT="$(cat "${APNS_PRIVATE_KEY_FILE}")"
elif [[ -f "AuthKey_${APNS_KEY_ID}.p8" ]]; then
  APNS_PRIVATE_KEY_CONTENT="$(cat "AuthKey_${APNS_KEY_ID}.p8")"
elif [[ -f "AuthKey_PG3LJB7CYK.p8" ]]; then
  APNS_PRIVATE_KEY_CONTENT="$(cat "AuthKey_PG3LJB7CYK.p8")"
else
  echo "missing APNs .p8 key file."
  echo "Set APNS_PRIVATE_KEY_FILE=/path/to/AuthKey_${APNS_KEY_ID}.p8 (recommended) or export APNS_PRIVATE_KEY."
  exit 1
fi

supabase link --project-ref "${PROJECT_REF}"
supabase functions deploy doodl-push --no-verify-jwt
supabase functions deploy doodl-push-worker --no-verify-jwt

supabase secrets set \
  APP_SUPABASE_URL="${SUPABASE_URL}" \
  APP_SUPABASE_SERVICE_ROLE_KEY="${APP_SUPABASE_SERVICE_ROLE_KEY}" \
  APNS_KEY_ID="${APNS_KEY_ID}" \
  APNS_TEAM_ID="${APNS_TEAM_ID}" \
  APNS_PRIVATE_KEY="${APNS_PRIVATE_KEY_CONTENT}" \
  APNS_BUNDLE_ID="${APNS_BUNDLE_ID}" \
  DOODL_WEBHOOK_SECRET="${DOODL_WEBHOOK_SECRET}"

echo
echo "done."
echo "next: enable push queue + schedule worker:"
echo "- apply migration: supabase/migrations/20251229002000_push_queue.sql"
echo "- schedule: /functions/v1/doodl-push-worker?limit=50"
echo "header: x-doodl-secret: ${DOODL_WEBHOOK_SECRET}"
