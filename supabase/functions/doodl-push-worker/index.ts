import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

const supabaseUrl = Deno.env.get("APP_SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("APP_SUPABASE_SERVICE_ROLE_KEY") ?? "";

const apnsKeyId = Deno.env.get("APNS_KEY_ID") ?? "";
const apnsTeamId = Deno.env.get("APNS_TEAM_ID") ?? "";
const apnsPrivateKey = (Deno.env.get("APNS_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "";

const fcmServiceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";
const fcmProjectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
const fcmClientEmail = Deno.env.get("FCM_CLIENT_EMAIL") ?? "";
const fcmPrivateKey = (Deno.env.get("FCM_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");

const workerSecret = Deno.env.get("DOODL_WORKER_SECRET") ?? Deno.env.get("DOODL_WEBHOOK_SECRET") ?? "";

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("missing APP_SUPABASE_URL or APP_SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

type PushJobRow = {
  id: string;
  kind: "group" | "anonymous" | "friend_request" | "group_invite" | "broadcast" | string;
  content_id: string;
  group_id: string | null;
  sender_profile_id: string | null;
  recipient_profile_id: string | null;
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
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("method not allowed", { status: 405 });
  }

  const userAgent = req.headers.get("user-agent") ?? "";
  const isPgNetWebhook = userAgent.toLowerCase().startsWith("pg_net/");

  if (workerSecret && !isPgNetWebhook) {
    const provided = req.headers.get("x-doodl-secret") ?? "";
    if (provided !== workerSecret) {
      return new Response("unauthorized", { status: 401 });
    }
  }

  // APNs is required for iOS; FCM is optional (Android-only).
  if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey || !apnsBundleId) {
    return new Response("apns env vars not configured", { status: 500 });
  }

  const url = new URL(req.url);
  const limit = Math.max(1, Math.min(Number(url.searchParams.get("limit") ?? "25"), 100));

  const { data: jobs, error: claimError } = await supabase.rpc("claim_push_jobs_service", {
    p_limit: limit,
  });

  if (claimError) {
    console.error("claim jobs error", claimError);
    return new Response("failed to claim jobs", { status: 500 });
  }

  const rows: PushJobRow[] = Array.isArray(jobs) ? (jobs as PushJobRow[]) : [];
  if (rows.length === 0) {
    return new Response(JSON.stringify({ claimed: 0, delivered: 0 }), {
      headers: { "content-type": "application/json" },
    });
  }

  let delivered = 0;
  for (const job of rows) {
    try {
      const ok = await processJob(job);
      await supabase.rpc("complete_push_job_service", {
        p_job_id: job.id,
        p_ok: ok,
        p_error: ok ? null : "failed",
      });
      if (ok) delivered += 1;
    } catch (err) {
      console.error("job processing error", job.id, err);
      await supabase.rpc("complete_push_job_service", {
        p_job_id: job.id,
        p_ok: false,
        p_error: String(err?.message ?? err),
      });
    }
  }

  return new Response(JSON.stringify({ claimed: rows.length, delivered }), {
    headers: { "content-type": "application/json" },
  });
});

async function processJob(job: PushJobRow): Promise<boolean> {
  if (job.kind === "anonymous") {
    if (!job.recipient_profile_id) return false;
    return await pushAnonymous(job.content_id, job.recipient_profile_id);
  }

  if (job.kind === "group") {
    if (!job.group_id || !job.sender_profile_id) return false;
    return await pushGroup(job.content_id, job.group_id, job.sender_profile_id);
  }

  if (job.kind === "friend_request") {
    if (!job.sender_profile_id || !job.recipient_profile_id) return false;
    return await pushFriendRequest(job.content_id, job.sender_profile_id, job.recipient_profile_id);
  }

  if (job.kind === "group_invite") {
    if (!job.sender_profile_id || !job.recipient_profile_id) return false;
    return await pushGroupInvite(job.content_id, job.sender_profile_id, job.recipient_profile_id);
  }

  if (job.kind === "broadcast") {
    if (!job.recipient_profile_id) return false;
    return await pushBroadcast(job.content_id, job.recipient_profile_id);
  }

  return false;
}

async function pushBroadcast(broadcastId: string, recipientProfileId: string): Promise<boolean> {
  const { data: broadcastRows, error: broadcastError } = await supabase
    .from("push_broadcasts")
    .select("title,body,data")
    .eq("id", broadcastId)
    .limit(1);

  if (broadcastError) {
    console.error("broadcast lookup error", broadcastError);
    return false;
  }

  const broadcast = broadcastRows?.[0];
  if (!broadcast) return false;

  const extraData = isRecord(broadcast.data) ? broadcast.data : {};
  const payload = {
    kind: "broadcast",
    broadcast_id: broadcastId,
    ...extraData,
  };

  return await pushApnsOnly(recipientProfileId, {
    title: broadcast.title,
    body: broadcast.body,
    data: payload,
  });
}

async function pushAnonymous(anonymousDoodleId: string, recipientProfileId: string): Promise<boolean> {
  const fcm = readFcmConfig();

  const { data: deviceRows, error: devicesError } = await supabase
    .from("profile_devices")
    .select("profile_id,apns_token,environment")
    .eq("profile_id", recipientProfileId)
    .not("apns_token", "is", null);

  if (devicesError) {
    console.error("device token lookup error", devicesError);
    return false;
  }

  const tokens: ProfileDeviceRow[] = (deviceRows ?? []).filter(
    (r): r is ProfileDeviceRow => Boolean(r?.apns_token),
  );
  const fcmTokens = fcm ? await fetchFcmTokens([recipientProfileId]) : [];

  if (tokens.length === 0 && fcmTokens.length === 0) return true;

  for (const row of tokens) {
    const alert = await sendApnsPush({
      deviceToken: row.apns_token,
      environment: row.environment,
      pushType: "alert",
      title: "new anonymous doodl.",
      body: "someone sent you a doodl.",
      payload: { kind: "anonymous", anonymous_doodle_id: anonymousDoodleId },
    });

    if (!alert.ok) {
      const reason = apnsReason(alert.text);
      if (reason === "BadDeviceToken" || reason === "Unregistered" || alert.status === 410) {
        await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
      }
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
            data: {
              kind: "anonymous",
              anonymous_doodle_id: anonymousDoodleId,
              sender_username: "",
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

  return true;
}

async function pushGroup(doodleId: string, groupId: string, senderProfileId: string): Promise<boolean> {
  const fcm = readFcmConfig();

  const { data: groupRows, error: groupError } = await supabase
    .from("groups")
    .select("code")
    .eq("id", groupId)
    .limit(1);

  if (groupError) {
    console.error("group lookup error", groupError);
    return false;
  }

  const groupCode = groupRows?.[0]?.code ?? null;

  const [{ data: senderRows, error: senderError }, { data: members, error: membersError }] =
    await Promise.all([
      supabase.from("profiles").select("username").eq("id", senderProfileId).limit(1),
      supabase.from("group_members").select("profile_id").eq("group_id", groupId),
    ]);

  if (senderError || membersError) {
    console.error("sender/members lookup error", senderError ?? membersError);
    return false;
  }

  const senderUsername = senderRows?.[0]?.username ?? "someone";
  let memberIds = (members ?? [])
    .map((m) => m.profile_id as string)
    .filter((id) => id && id !== senderProfileId);

  if (memberIds.length === 0) return true;

  const { data: blockedRows, error: blockedError } = await supabase
    .from("blocked_profiles")
    .select("profile_id")
    .eq("blocked_profile_id", senderProfileId)
    .in("profile_id", memberIds);

  if (blockedError) {
    console.error("blocked_profiles lookup error", blockedError);
    return false;
  }

  const blocked = new Set((blockedRows ?? []).map((r) => r.profile_id as string).filter(Boolean));
  memberIds = memberIds.filter((id) => !blocked.has(id));
  if (memberIds.length === 0) return true;

  const fcmTokens = fcm ? await fetchFcmTokens(memberIds) : [];

  const { data: deviceRows, error: devicesError } = await supabase
    .from("profile_devices")
    .select("profile_id,apns_token,environment")
    .in("profile_id", memberIds)
    .not("apns_token", "is", null);

  if (devicesError) {
    console.error("device token lookup error", devicesError);
    return false;
  }

  const tokens: ProfileDeviceRow[] = (deviceRows ?? []).filter(
    (r): r is ProfileDeviceRow => Boolean(r?.apns_token),
  );
  if (tokens.length === 0 && fcmTokens.length === 0) return true;

  for (const row of tokens) {
    try {
      // Best-effort background push first.
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
            doodle_id: doodleId,
          },
        });
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
          doodle_id: doodleId,
        },
      });

      if (!alert.ok) {
        const reason = apnsReason(alert.text);
        if (reason === "BadDeviceToken" || reason === "Unregistered" || alert.status === 410) {
          await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
        }
      }
    } catch (err) {
      console.error("apns send error", err);
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
              doodle_id: doodleId,
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

  return true;
}

async function pushFriendRequest(
  requestId: string,
  requesterProfileId: string,
  targetProfileId: string,
): Promise<boolean> {
  const senderUsername = await fetchUsername(requesterProfileId);
  const body = senderUsername ? `@${senderUsername} sent you a friend request.` : "new friend request.";

  return await pushDirectToProfile(targetProfileId, {
    title: "new friend request.",
    body,
    data: {
      kind: "friend_request",
      friend_request_id: requestId,
      sender_profile_id: requesterProfileId,
      sender_username: senderUsername,
    },
  });
}

async function pushGroupInvite(
  inviteId: string,
  inviterProfileId: string,
  invitedProfileId: string,
): Promise<boolean> {
  const senderUsername = await fetchUsername(inviterProfileId);
  const body = senderUsername ? `@${senderUsername} invited you to a group.` : "you have a group invite.";

  return await pushDirectToProfile(invitedProfileId, {
    title: "new group invite.",
    body,
    data: {
      kind: "group_invite",
      group_invite_id: inviteId,
      sender_profile_id: inviterProfileId,
      sender_username: senderUsername,
    },
  });
}

async function fetchUsername(profileId: string): Promise<string> {
  const { data, error } = await supabase
    .from("profiles")
    .select("username")
    .eq("id", profileId)
    .limit(1);

  if (error) {
    console.error("username lookup error", error);
    return "";
  }

  return data?.[0]?.username ?? "";
}

async function pushDirectToProfile(
  profileId: string,
  args: { title: string; body: string; data: Record<string, string> },
): Promise<boolean> {
  const fcm = readFcmConfig();

  const { data: deviceRows, error: devicesError } = await supabase
    .from("profile_devices")
    .select("profile_id,apns_token,environment")
    .eq("profile_id", profileId)
    .not("apns_token", "is", null);

  if (devicesError) {
    console.error("device token lookup error", devicesError);
    return false;
  }

  const tokens: ProfileDeviceRow[] = (deviceRows ?? []).filter(
    (r): r is ProfileDeviceRow => Boolean(r?.apns_token),
  );
  const fcmTokens = fcm ? await fetchFcmTokens([profileId]) : [];

  if (tokens.length === 0 && fcmTokens.length === 0) return true;

  for (const row of tokens) {
    const alert = await sendApnsPush({
      deviceToken: row.apns_token,
      environment: row.environment,
      pushType: "alert",
      title: args.title,
      body: args.body,
      payload: args.data,
    });

    if (!alert.ok) {
      const reason = apnsReason(alert.text);
      if (reason === "BadDeviceToken" || reason === "Unregistered" || alert.status === 410) {
        await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
      }
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
          title: args.title,
          body: args.body,
          data: args.data,
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

  return true;
}

async function pushApnsOnly(
  profileId: string,
  args: { title: string; body: string; data?: Record<string, unknown> },
): Promise<boolean> {
  const { data: deviceRows, error: devicesError } = await supabase
    .from("profile_devices")
    .select("profile_id,apns_token,environment")
    .eq("profile_id", profileId)
    .not("apns_token", "is", null);

  if (devicesError) {
    console.error("device token lookup error", devicesError);
    return false;
  }

  const tokens: ProfileDeviceRow[] = (deviceRows ?? []).filter(
    (r): r is ProfileDeviceRow => Boolean(r?.apns_token),
  );

  if (tokens.length === 0) return true;

  for (const row of tokens) {
    const alert = await sendApnsPush({
      deviceToken: row.apns_token,
      environment: row.environment,
      pushType: "alert",
      title: args.title,
      body: args.body,
      payload: args.data,
    });

    if (!alert.ok) {
      const reason = apnsReason(alert.text);
      if (reason === "BadDeviceToken" || reason === "Unregistered" || alert.status === 410) {
        await supabase.from("profile_devices").delete().eq("apns_token", row.apns_token);
      }
    }
  }

  return true;
}

type ApnsSendArgs = {
  deviceToken: string;
  environment: string;
  pushType: "background" | "alert";
  title: string;
  body: string;
  payload?: Record<string, unknown>;
};

type ApnsSendResult = { ok: boolean; status: number; text: string };

async function sendApnsPush({
  deviceToken,
  environment,
  pushType,
  title,
  body,
  payload,
}: ApnsSendArgs): Promise<ApnsSendResult> {
  const jwt = await buildApnsJwt();
  const host = environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";

  const aps: Record<string, unknown> =
    pushType === "background"
      ? { aps: { "content-available": 1 } }
      : { aps: { alert: { title, body }, sound: "default", "content-available": 1 } };
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
  return { ok: response.ok, status: response.status, text };
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

function apnsReason(text: string): string | null {
  try {
    const parsed = JSON.parse(text) as { reason?: unknown };
    return typeof parsed?.reason === "string" ? parsed.reason : null;
  } catch {
    return null;
  }
}

let cachedApnsJwt: string | null = null;
let cachedApnsJwtIat: number | null = null;

async function buildApnsJwt(): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const maxAgeSeconds = 50 * 60;
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

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const binaryDerString = atob(cleaned);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDer.length; i++) binaryDer[i] = binaryDerString.charCodeAt(i);

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
    // Backwards-compat: table may not exist yet on some projects.
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
  // Minimal heuristic: errors typically contain "UNREGISTERED" / "NOT_FOUND" for invalid tokens.
  const t = text.toUpperCase();
  return t.includes("UNREGISTERED") || t.includes("NOT_FOUND") || t.includes("INVALID_ARGUMENT");
} 
