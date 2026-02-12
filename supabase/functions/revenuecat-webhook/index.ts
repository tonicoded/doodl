import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

const supabaseUrl = Deno.env.get("APP_SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("APP_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("missing APP_SUPABASE_URL or APP_SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

type RevenueCatPayload = Record<string, unknown>;

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const url = new URL(req.url);

  if (webhookSecret) {
    const expected = normalizeAuthValue(webhookSecret);
    const rawCandidates: Array<[string, string | null]> = [
      ["x-revenuecat-secret", req.headers.get("x-revenuecat-secret")],
      ["authorization", req.headers.get("authorization")],
      ["secret(query)", url.searchParams.get("secret")],
      ["token(query)", url.searchParams.get("token")],
    ];

    const candidates = rawCandidates
      .map(([k, v]) => [k, v] as const)
      .filter(([, v]) => typeof v === "string" && v.trim().length > 0)
      .map(([k, v]) => [k, normalizeAuthValue(v as string)] as const);

    const ok = candidates.some(([, v]) => v === expected);
    if (!ok) {
      console.error("webhook auth mismatch", {
        expected: redact(expected),
        candidates: candidates.map(([k, v]) => [k, redact(v)]),
      });
      return new Response("unauthorized", { status: 401 });
    }
  }

  let payload: RevenueCatPayload;
  try {
    payload = (await req.json()) as RevenueCatPayload;
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  const { profileId, isPro, reason } = deriveProfileProState(payload);
  if (!profileId) {
    return json({ ok: false, error: "missing profile id" }, 400);
  }

  if (isPro == null) {
    return json({ ok: true, profile_id: profileId, skipped: true, reason }, 200);
  }

  const { error } = await supabase
    .from("profiles")
    .update({ is_pro: isPro })
    .eq("id", profileId);

  if (error) {
    console.error("update profiles.is_pro error", error);
    return json({ ok: false, error: "db update failed" }, 500);
  }

  return json({ ok: true, profile_id: profileId, is_pro: isPro }, 200);
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function normalizeAuthValue(value: string): string {
  let trimmed = value.trim();
  if (
    (trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    trimmed = trimmed.slice(1, -1).trim();
  }
  if (trimmed.toLowerCase().startsWith("bearer ")) {
    return trimmed.slice(7).trim();
  }
  return trimmed;
}

function redact(value: string): string {
  const v = value.trim();
  if (v.length <= 10) return `${v.length}:${v}`;
  return `${v.length}:${v.slice(0, 6)}…${v.slice(-2)}`;
}

function deriveProfileProState(payload: RevenueCatPayload): { profileId: string | null; isPro: boolean | null; reason: string } {
  const event = (payload["event"] ?? null) as Record<string, unknown> | null;
  const subscriberRoot = (payload["subscriber"] ?? null) as Record<string, unknown> | null;
  const subscriberEvent = (event?.["subscriber"] ?? null) as Record<string, unknown> | null;
  const subscriber = subscriberEvent ?? subscriberRoot;

  const profileId =
    asString(event?.["app_user_id"]) ??
    asString(payload["app_user_id"]) ??
    asString(subscriber?.["app_user_id"]) ??
    asString(subscriber?.["original_app_user_id"]) ??
    null;

  const type = (asString(event?.["type"]) ?? "").toLowerCase();

  const entitlementIdsRaw = event?.["entitlement_ids"] ?? event?.["entitlement_id"];
  const entitlementIds = normalizeStringArray(entitlementIdsRaw).map((x) => x.toLowerCase());
  const mentionsProEntitlement = entitlementIds.includes("pro");

  // Preferred: evaluate the current entitlement state when it's present in the payload.
  const entitlements = (subscriber?.["entitlements"] ?? null) as Record<string, unknown> | null;
  const proEntitlement = (entitlements?.["pro"] ?? null) as Record<string, unknown> | null;
  if (proEntitlement) {
    const expiresDate = asString(proEntitlement["expires_date"]);
    if (!expiresDate) {
      return { profileId, isPro: true, reason: "entitlement_present_no_expiry" };
    }
    const expiresAt = Date.parse(expiresDate);
    if (!Number.isFinite(expiresAt)) {
      return { profileId, isPro: null, reason: "invalid_expires_date" };
    }
    return { profileId, isPro: expiresAt > Date.now(), reason: "entitlement_expiry" };
  }

  // Fallback: infer from event type + entitlement_ids.
  if (mentionsProEntitlement) {
    const negative =
      type.includes("cancellation") ||
      type.includes("expiration") ||
      type.includes("refund") ||
      type.includes("billing_issue");
    return { profileId, isPro: !negative, reason: "event_type_entitlement_ids" };
  }

  return { profileId, isPro: null, reason: "no_entitlement_info" };
}

function asString(v: unknown): string | null {
  if (typeof v === "string") {
    const t = v.trim();
    return t.length ? t : null;
  }
  return null;
}

function normalizeStringArray(v: unknown): string[] {
  if (!v) return [];
  if (Array.isArray(v)) return v.map(asString).filter((x): x is string => Boolean(x));
  const s = asString(v);
  return s ? [s] : [];
}
