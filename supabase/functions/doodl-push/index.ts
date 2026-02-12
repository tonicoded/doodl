import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

const supabaseUrl = Deno.env.get("APP_SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("APP_SUPABASE_SERVICE_ROLE_KEY") ?? "";

const apnsKeyId = Deno.env.get("APNS_KEY_ID") ?? "";
const apnsTeamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const apnsPrivateKey = (Deno.env.get("APNS_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "";
const webhookSecret = Deno.env.get("DOODL_WEBHOOK_SECRET") ?? "";

const fcmServiceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";
const fcmProjectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
const fcmClientEmail = Deno.env.get("FCM_CLIENT_EMAIL") ?? "";
const fcmPrivateKey = (Deno.env.get("FCM_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("missing APP_SUPABASE_URL or APP_SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

type InsertWebhook = {
  type?: string;
  table?: string;
  schema?: string;
  record?: {
    id: string;
    group_id: string;
    sender_profile_id: string;
    created_at: string;
    recipient_profile_id?: string;
  };
};

type ProfileDeviceRow = {
  profile_id: string;
  apns_token: string;
  environment: "sandbox" | "production" | string;
};

type ProfileFcmDeviceRow = {
  profile_id: string;
  fcm_token: string;
};

type FcmConfig = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
};

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  // Note: Supabase "Database Webhooks" (pg_net) may not forward custom headers reliably for the
  // "Supabase Edge Functions" webhook type. We treat pg_net calls as trusted (they originate inside
  // your project) and only enforce `x-doodl-secret` for non-pg_net callers.
  const userAgent = req.headers.get("user-agent") ?? "";
  const isPgNetWebhook = userAgent.toLowerCase().startsWith("pg_net/");

  if (webhookSecret && !isPgNetWebhook) {
    const provided = req.headers.get("x-doodl-secret") ?? "";
    if (provided !== webhookSecret) {
      return new Response("unauthorized", { status: 401 });
    }
  }

  // APNs is required for iOS; FCM is optional (Android-only).
  if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey || !apnsBundleId) {
    return new Response("apns env vars not configured", { status: 500 });
  }

  const fcm = readFcmConfig();

  let body: InsertWebhook;
  try {
    body = await req.json();
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  const record = body?.record;
  if (!record?.id) {
    return new Response("missing record.id", { status: 400 });
  }

  const isAnonymous = body?.table === "anonymous_doodles" || Boolean(record?.recipient_profile_id);

  if (isAnonymous) {
    const recipientProfileId = record.recipient_profile_id;
    if (!recipientProfileId) {
      return new Response("missing record.recipient_profile_id", { status: 400 });
    }

    const { data: deviceRows, error: devicesError } = await supabase
      .from("profile_devices")
      .select("profile_id,apns_token,environment")
      .eq("profile_id", recipientProfileId)
      .not("apns_token", "is", null);

    if (devicesError) {
      console.error("device token lookup error", devicesError);
      return new Response("failed token lookup", { status: 500 });
    }

    const tokens: ProfileDeviceRow[] = (deviceRows ?? []).filter(
      (r): r is ProfileDeviceRow => Boolean(r?.apns_token),
    );

    const fcmTokens = fcm ? await fetchFcmTokens([recipientProfileId]) : [];

    if (tokens.length === 0 && fcmTokens.length === 0) {
      return new Response(JSON.stringify({ delivered: 0, reason: "no tokens" }), {
        headers: { "content-type": "application/json" },
      });
    }

    const results: Record<string, number> = {};
    for (const row of tokens) {
      try {
        const alert = await sendApnsPush({
          deviceToken: row.apns_token,
          environment: row.environment,
          pushType: "alert",
          title: "new anonymous doodl.",
          body: "someone sent you a doodl.",
          payload: {
            kind: "anonymous",
            anonymous_doodle_id: record.id,
          },
        });

        results[row.apns_token] = alert.ok ? alert.status : 0;
        if (!alert.ok) {
          const reason = apnsReason(alert.text);
          if (reason === "BadDeviceToken" || reason === "Unregistered" || alert.status === 410) {
            await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
          }
        }
      } catch (err) {
        console.error("apns send error", err);
        results[row.apns_token] = 0;
      }
    }

    if (fcm && fcmTokens.length > 0) {
      const accessToken = await getFcmAccessToken(fcm);
      await Promise.all(
        fcmTokens.map(async (row) => {
          const res = await sendFcmPush({
            accessToken,
            projectId: fcm.projectId,
            fcmToken: row.fcm_token,
            title: "new anonymous doodl.",
            body: "someone sent you a doodl.",
            data: { kind: "anonymous", anonymous_doodle_id: record.id },
          });
          if (!res.ok && isFcmTokenInvalid(res.text)) {
            try {
              await supabase.from("profile_fcm_devices").delete().eq("fcm_token", row.fcm_token);
            } catch {
              // ignore
            }
          }
        }),
      );
    }

    return new Response(JSON.stringify({ delivered: Object.values(results).filter((s) => s > 0).length, results }), {
      headers: { "content-type": "application/json" },
    });
  }

  if (!record?.group_id || !record?.sender_profile_id) {
    return new Response("missing record.group_id / record.sender_profile_id", { status: 400 });
  }

  const groupId = record.group_id;
  const senderProfileId = record.sender_profile_id;

  const [{ data: groupRows, error: groupError }, { data: senderRows, error: senderError }, { data: members, error: membersError }] =
    await Promise.all([
      supabase.from("groups").select("code").eq("id", groupId).limit(1),
      supabase.from("profiles").select("username").eq("id", senderProfileId).limit(1),
      supabase.from("group_members").select("profile_id").eq("group_id", groupId),
    ]);

  if (groupError) {
    console.error("group lookup error", groupError);
    return new Response("failed group lookup", { status: 500 });
  }
  if (senderError) {
    console.error("sender lookup error", senderError);
    return new Response("failed sender lookup", { status: 500 });
  }
  if (membersError) {
    console.error("member lookup error", membersError);
    return new Response("failed member lookup", { status: 500 });
  }

  const groupCode = groupRows?.[0]?.code ?? null;
  const senderUsername = senderRows?.[0]?.username ?? "someone";
  let memberIds = (members ?? [])
    .map((m) => m.profile_id as string)
    .filter((id) => id && id !== senderProfileId);

  if (memberIds.length === 0) {
    return new Response(JSON.stringify({ delivered: 0, reason: "no other members" }), {
      headers: { "content-type": "application/json" },
    });
  }

  // Skip recipients who have blocked this sender.
  const { data: blockedRows, error: blockedError } = await supabase
    .from("blocked_profiles")
    .select("profile_id")
    .eq("blocked_profile_id", senderProfileId)
    .in("profile_id", memberIds);

  if (blockedError) {
    console.error("blocked_profiles lookup error", blockedError);
    return new Response("failed blocked_profiles lookup", { status: 500 });
  }

  const blocked = new Set((blockedRows ?? []).map((r) => r.profile_id as string).filter(Boolean));
  memberIds = memberIds.filter((id) => !blocked.has(id));

  if (memberIds.length === 0) {
    return new Response(JSON.stringify({ delivered: 0, reason: "all recipients blocked sender" }), {
      headers: { "content-type": "application/json" },
    });
  }

  const fcmTokens = fcm ? await fetchFcmTokens(memberIds) : [];

  const { data: deviceRows, error: devicesError } = await supabase
    .from("profile_devices")
    .select("profile_id,apns_token,environment")
    .in("profile_id", memberIds)
    .not("apns_token", "is", null);

  if (devicesError) {
    console.error("device token lookup error", devicesError);
    return new Response("failed token lookup", { status: 500 });
  }

  const tokens: ProfileDeviceRow[] = (deviceRows ?? []).filter(
    (r): r is ProfileDeviceRow => Boolean(r?.apns_token),
  );

  if (tokens.length === 0 && fcmTokens.length === 0) {
    return new Response(JSON.stringify({ delivered: 0, reason: "no tokens" }), {
      headers: { "content-type": "application/json" },
    });
  }

  const results: Record<string, number> = {};
  for (const row of tokens) {
    try {
      // Widget refresh: try a silent/background push first.
      // It must never block the normal alert push (some setups reject background pushes).
      try {
        const bg = await sendApnsPush({
          deviceToken: row.apns_token,
          environment: row.environment,
          pushType: "background",
          title: "background",
          body: "background",
          payload: {
            kind: "group",
            group_id: groupId,
            group_code: groupCode,
            sender_profile_id: senderProfileId,
            sender_username: senderUsername,
            doodle_id: record.id,
          },
        });
        // If APNs says the token is invalid/unregistered, remove it so future sends don't keep failing.
        if (!bg.ok) {
          const reason = apnsReason(bg.text);
          if (reason === "BadDeviceToken" || reason === "Unregistered" || bg.status === 410) {
            await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
          }
        }
      } catch (err) {
        console.warn("apns background push failed; continuing with alert push", err);
      }

      const alert = await sendApnsPush({
        deviceToken: row.apns_token,
        environment: row.environment,
        pushType: "alert",
        title: "new doodl.",
        body: `@${senderUsername} sent a doodl.`,
        payload: {
          kind: "group",
          group_id: groupId,
          group_code: groupCode,
          sender_profile_id: senderProfileId,
          sender_username: senderUsername,
          doodle_id: record.id,
        },
      });

      results[row.apns_token] = alert.ok ? alert.status : 0;
      if (!alert.ok) {
        const reason = apnsReason(alert.text);
        if (reason === "BadDeviceToken" || reason === "Unregistered" || alert.status === 410) {
          await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
        }
      }
    } catch (err) {
      console.error("apns send error", err);
      results[row.apns_token] = 0;
    }
  }

  if (fcm && fcmTokens.length > 0) {
    const accessToken = await getFcmAccessToken(fcm);
    await Promise.all(
      fcmTokens.map(async (row) => {
        const res = await sendFcmPush({
          accessToken,
          projectId: fcm.projectId,
          fcmToken: row.fcm_token,
          title: "new doodl.",
          body: `@${senderUsername} sent a doodl.`,
          data: {
            kind: "group",
            group_id: groupId,
            group_code: groupCode ?? "",
            sender_profile_id: senderProfileId,
            sender_username: senderUsername,
            doodle_id: record.id,
          },
        });
        if (!res.ok && isFcmTokenInvalid(res.text)) {
          try {
            await supabase.from("profile_fcm_devices").delete().eq("fcm_token", row.fcm_token);
          } catch {
            // ignore
          }
        }
      }),
    );
  }

  return new Response(JSON.stringify({ delivered: Object.values(results).filter((s) => s > 0).length, results }), {
    headers: { "content-type": "application/json" },
  });
});

type ApnsSendArgs = {
  deviceToken: string;
  environment: string;
  pushType: "background" | "alert";
  title: string;
  body: string;
  payload?: Record<string, unknown>;
};

type ApnsSendResult = { ok: boolean; status: number; text: string };

async function sendApnsPush({ deviceToken, environment, pushType, title, body, payload }: ApnsSendArgs): Promise<ApnsSendResult> {
  const jwt = await buildApnsJwt();
  const host = environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";

  const aps: Record<string, unknown> =
    pushType === "background"
      ? { aps: { "content-available": 1 } }
      : {
          aps: {
            alert: { title, body },
            sound: "default",
            "content-available": 1,
          },
        };
  if (payload) Object.assign(aps, payload);

  const response = await fetch(`${host}/3/device/${deviceToken}`, {
    method: "POST",
    body: JSON.stringify(aps),
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": apnsBundleId,
      "apns-push-type": pushType,
      "apns-priority": pushType === "background" ? "5" : "10",
      "content-type": "application/json",
    },
  });

  const text = await response.text();
  console.log("apns response", response.status, text);
  return { ok: response.ok, status: response.status, text };
}

function apnsReason(text: string): string | null {
  try {
    const parsed = JSON.parse(text) as { reason?: unknown };
    return typeof parsed?.reason === "string" ? parsed.reason : null;
  } catch {
    return null;
  }
}

async function buildApnsJwt(): Promise<string> {
  // APNs provider tokens (JWT) should be reused for a while; generating a new token for every send
  // can trigger 429 TooManyProviderTokenUpdates.
  const nowSeconds = Math.floor(Date.now() / 1000);
  const maxAgeSeconds = 50 * 60; // keep a safety margin under Apple's 60min recommendation
  if (cachedApnsJwt && cachedApnsJwtIat && nowSeconds - cachedApnsJwtIat < maxAgeSeconds) {
    return cachedApnsJwt;
  }

  const header = { alg: "ES256", kid: apnsKeyId, typ: "JWT" };
  const payload = { iss: apnsTeamId, iat: nowSeconds };

  const encoder = new TextEncoder();
  const headerPart = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const payloadPart = base64UrlEncode(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerPart}.${payloadPart}`;

  const key = await importPrivateKey(apnsPrivateKey);
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, encoder.encode(signingInput));
  const signaturePart = base64UrlEncode(new Uint8Array(signature));

  cachedApnsJwt = `${signingInput}.${signaturePart}`;
  cachedApnsJwtIat = nowSeconds;
  return cachedApnsJwt;
}

let cachedApnsJwt: string | null = null;
let cachedApnsJwtIat: number | null = null;

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const binaryDerString = atob(cleaned);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDer.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  return crypto.subtle.importKey("pkcs8", binaryDer.buffer, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

function base64UrlEncode(input: Uint8Array): string {
  return btoa(String.fromCharCode(...input)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function readFcmConfig(): FcmConfig | null {
  try {
    if (fcmServiceAccountJson.trim()) {
      const parsed = JSON.parse(fcmServiceAccountJson) as Record<string, unknown>;
      const projectId = String(parsed["project_id"] ?? "");
      const clientEmail = String(parsed["client_email"] ?? "");
      const privateKey = String(parsed["private_key"] ?? "").replace(/\\n/g, "\n");
      if (!projectId || !clientEmail || !privateKey) return null;
      return { projectId, clientEmail, privateKey };
    }
  } catch {
    // ignore
  }

  if (!fcmProjectId || !fcmClientEmail || !fcmPrivateKey) return null;
  return { projectId: fcmProjectId, clientEmail: fcmClientEmail, privateKey: fcmPrivateKey };
}

async function fetchFcmTokens(profileIds: string[]): Promise<ProfileFcmDeviceRow[]> {
  if (!profileIds.length) return [];
  const { data, error } = await supabase
    .from("profile_fcm_devices")
    .select("profile_id,fcm_token")
    .in("profile_id", profileIds)
    .not("fcm_token", "is", null);

  if (error) {
    const code = (error as { code?: unknown })?.code;
    if (code === "42P01") return [];
    console.warn("fcm token lookup error", error);
    return [];
  }

  return (data ?? []).filter((r): r is ProfileFcmDeviceRow => Boolean(r?.fcm_token));
}

let cachedFcmAccessToken: string | null = null;
let cachedFcmAccessTokenExp: number | null = null;

async function getFcmAccessToken(cfg: FcmConfig): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedFcmAccessToken && cachedFcmAccessTokenExp && now + 30 < cachedFcmAccessTokenExp) {
    return cachedFcmAccessToken;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: cfg.clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 55 * 60,
  };

  const encoder = new TextEncoder();
  const headerPart = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const payloadPart = base64UrlEncode(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerPart}.${payloadPart}`;

  const key = await importRsaPrivateKey(cfg.privateKey);
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(signingInput));
  const assertion = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });

  const text = await response.text();
  if (!response.ok) throw new Error(`fcm token exchange failed: ${response.status} ${text}`);

  const parsed = JSON.parse(text) as { access_token?: string; expires_in?: number };
  if (!parsed?.access_token) throw new Error("fcm token exchange missing access_token");

  cachedFcmAccessToken = parsed.access_token;
  cachedFcmAccessTokenExp = now + Math.max(60, Number(parsed.expires_in ?? 3600));
  return parsed.access_token;
}

async function importRsaPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const binaryDerString = atob(cleaned);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDer.length; i++) binaryDer[i] = binaryDerString.charCodeAt(i);

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

type FcmSendArgs = {
  accessToken: string;
  projectId: string;
  fcmToken: string;
  title: string;
  body: string;
  data: Record<string, string>;
};

type FcmSendResult = { ok: boolean; status: number; text: string };

async function sendFcmPush(args: FcmSendArgs): Promise<FcmSendResult> {
  const { accessToken, projectId, fcmToken, title, body, data } = args;
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const payload = {
    message: {
      token: fcmToken,
      // Data-only so Android can process it in background and update the widget.
      data: { ...data, title, body },
      android: { priority: "HIGH" },
    },
  };

  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const text = await response.text();
  return { ok: response.ok, status: response.status, text };
}

function isFcmTokenInvalid(text: string): boolean {
  const t = text.toUpperCase();
  return t.includes("UNREGISTERED") || t.includes("NOT_FOUND") || t.includes("INVALID_ARGUMENT");
}
