import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-lacak-trigger",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface DispatchRequestBody {
  alert_id?: string;
  record?: {
    id?: string;
  };
}

interface AlertRow {
  id: string;
  sppg_id: string;
  batch_id: string;
  reporter_school_id: string;
  stage: string;
  symptom_count: number;
  notes: string | null;
  broadcast_enabled: boolean;
  sample_label_code: string | null;
  pdf_dispatched: boolean;
  created_at: string;
}

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function sanitizeText(value: unknown, fallback: string): string {
  if (typeof value !== "string") {
    return fallback;
  }
  const stripped = value
    .replaceAll("\u2014", ", ")
    .replaceAll("\u2013", "-")
    .replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]/gu, "")
    .replace(/\s{2,}/g, " ")
    .trim();
  return stripped.length > 0 ? stripped : fallback;
}

async function resolveCallerUserId(
  supabaseUrl: string,
  serviceRoleKey: string,
  bearerToken: string,
): Promise<string | null> {
  const resp = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${bearerToken}`,
    },
  });
  if (!resp.ok) {
    return null;
  }
  const userJson = (await resp.json()) as { id?: unknown };
  return typeof userJson.id === "string" && userJson.id.length > 0
    ? userJson.id
    : null;
}

function jsonResponse(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlEncodeJson(obj: unknown): string {
  return base64UrlEncodeBytes(new TextEncoder().encode(JSON.stringify(obj)));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    bytes[i] = bin.charCodeAt(i);
  }
  return bytes.buffer;
}

async function fetchGoogleAccessToken(
  clientEmail: string,
  privateKeyPem: string,
): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  const headerB64 = base64UrlEncodeJson({ alg: "RS256", typ: "JWT" });
  const claimB64 = base64UrlEncodeJson({
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSec,
    exp: nowSec + 3600,
  });
  const signingInput = `${headerB64}.${claimB64}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${base64UrlEncodeBytes(new Uint8Array(sigBuf))}`;

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenResp.ok) {
    throw new Error(`OAuth token exchange failed: ${tokenResp.status}`);
  }
  const tokenJson = (await tokenResp.json()) as { access_token?: string };
  if (!tokenJson.access_token) {
    throw new Error("Missing access_token from Google OAuth response");
  }
  return tokenJson.access_token;
}

async function fetchSupabaseRest<T>(
  supabaseUrl: string,
  serviceRoleKey: string,
  path: string,
): Promise<T> {
  const resp = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      Accept: "application/json",
    },
  });
  if (!resp.ok) {
    throw new Error(`PostgREST query failed (${resp.status}) on ${path}`);
  }
  return (await resp.json()) as T;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { ok: false, error: "Supabase service credentials missing" },
      500,
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse({ ok: false, error: "Unauthorized" }, 401);
  }
  const bearerToken = authHeader.slice(7).trim();
  if (!bearerToken) {
    return jsonResponse({ ok: false, error: "Unauthorized" }, 401);
  }

  const isServiceCaller = bearerToken === serviceRoleKey;
  let callerUserId: string | null = null;
  if (!isServiceCaller) {
    callerUserId = await resolveCallerUserId(
      supabaseUrl,
      serviceRoleKey,
      bearerToken,
    );
    if (!callerUserId) {
      return jsonResponse({ ok: false, error: "Unauthorized" }, 401);
    }
  }

  let body: DispatchRequestBody;
  try {
    body = (await req.json()) as DispatchRequestBody;
  } catch {
    return jsonResponse({ ok: false, error: "Invalid JSON payload" }, 400);
  }

  const alertId = sanitizeText(body.alert_id ?? body.record?.id, "");
  if (!alertId || !UUID_REGEX.test(alertId)) {
    return jsonResponse({ ok: false, error: "Valid alert_id UUID is required" }, 400);
  }

  try {
    const alertRows = await fetchSupabaseRest<AlertRow[]>(
      supabaseUrl,
      serviceRoleKey,
      `cluster_alerts?id=eq.${encodeURIComponent(alertId)}&select=*`,
    );
    const alert = alertRows[0];
    if (!alert) {
      return jsonResponse({ ok: false, error: "Alert record not found" }, 404);
    }

    const [kitchens, batches, approvedSchools, reporterSchools, batchAlerts, sppgMembers] =
      await Promise.all([
        fetchSupabaseRest<Array<{ id: string; name: string; owner_user_id: string }>>(
          supabaseUrl,
          serviceRoleKey,
          `sppg_kitchens?id=eq.${encodeURIComponent(alert.sppg_id)}&select=id,name,owner_user_id`,
        ),
        fetchSupabaseRest<Array<{ id: string; batch_code: string; menu_name: string }>>(
          supabaseUrl,
          serviceRoleKey,
          `food_batches?id=eq.${encodeURIComponent(alert.batch_id)}&select=id,batch_code,menu_name`,
        ),
        fetchSupabaseRest<Array<{ id: string; name: string; owner_user_id: string }>>(
          supabaseUrl,
          serviceRoleKey,
          `schools?sppg_id=eq.${encodeURIComponent(alert.sppg_id)}&verification_status=eq.approved&select=id,name,owner_user_id`,
        ),
        fetchSupabaseRest<Array<{ id: string; name: string; owner_user_id: string }>>(
          supabaseUrl,
          serviceRoleKey,
          `schools?id=eq.${encodeURIComponent(alert.reporter_school_id)}&select=id,name,owner_user_id`,
        ),
        fetchSupabaseRest<Array<{ reporter_school_id: string }>>(
          supabaseUrl,
          serviceRoleKey,
          `cluster_alerts?batch_id=eq.${encodeURIComponent(alert.batch_id)}&select=reporter_school_id`,
        ),
        fetchSupabaseRest<Array<{ user_id: string | null; role: string }>>(
          supabaseUrl,
          serviceRoleKey,
          `institution_members?institution_type=eq.sppg&institution_id=eq.${encodeURIComponent(alert.sppg_id)}&is_active=eq.true&user_id=not.is.null&select=user_id,role`,
        ).catch(() => []),
      ]);

    const kitchen = kitchens[0];
    const reporterSchoolRow = reporterSchools[0];
    const allSchoolIds = Array.from(
      new Set<string>([
        alert.reporter_school_id,
        ...approvedSchools.map((s) => s.id),
      ]),
    );
    const schoolMembers = allSchoolIds.length > 0
      ? await fetchSupabaseRest<Array<{ institution_id: string; user_id: string | null }>>(
          supabaseUrl,
          serviceRoleKey,
          `institution_members?institution_type=eq.school&institution_id=in.(${encodeURIComponent(allSchoolIds.join(","))})&is_active=eq.true&user_id=not.is.null&select=institution_id,user_id`,
        ).catch(() => [])
      : [];

    const isAuthorizedCaller =
      isServiceCaller ||
      callerUserId === reporterSchoolRow?.owner_user_id ||
      callerUserId === kitchen?.owner_user_id ||
      schoolMembers.some(
        (m) =>
          m.institution_id === alert.reporter_school_id &&
          m.user_id === callerUserId,
      ) ||
      sppgMembers.some(
        (m) =>
          m.user_id === callerUserId &&
          (m.role === "admin" || m.role === "staff"),
      );

    if (!isAuthorizedCaller) {
      return jsonResponse(
        { ok: false, error: "Forbidden for this tenant" },
        403,
      );
    }

    if (!alert.broadcast_enabled) {
      return jsonResponse({
        ok: true,
        mode: "broadcast_disabled",
        alert_id: alert.id,
        sppg_id: alert.sppg_id,
      });
    }

    const batch = batches[0];
    const reporterSchool = reporterSchoolRow ??
      approvedSchools.find((s) => s.id === alert.reporter_school_id);
    const recipientSchools = approvedSchools.filter(
      (s) => s.id !== alert.reporter_school_id,
    );
    const recipientSchoolIds = new Set(recipientSchools.map((s) => s.id));

    const recipientUserIds = new Set<string>();
    for (const s of recipientSchools) {
      if (s.owner_user_id) recipientUserIds.add(s.owner_user_id);
    }
    for (const m of schoolMembers) {
      if (m.user_id && recipientSchoolIds.has(m.institution_id)) {
        recipientUserIds.add(m.user_id);
      }
    }
    if (kitchen?.owner_user_id) {
      recipientUserIds.add(kitchen.owner_user_id);
    }
    for (const m of sppgMembers) {
      if (m.user_id) recipientUserIds.add(m.user_id);
    }

    let tokens: string[] = [];
    if (recipientUserIds.size > 0) {
      const idList = Array.from(recipientUserIds).join(",");
      const profiles = await fetchSupabaseRest<Array<{ id: string; fcm_token: string | null }>>(
        supabaseUrl,
        serviceRoleKey,
        `profiles?id=in.(${encodeURIComponent(idList)})&fcm_token=not.is.null&select=id,fcm_token`,
      );
      tokens = profiles
        .map((p) => p.fcm_token ?? "")
        .filter((t) => t.trim().length > 0);
    }

    const sppgName = sanitizeText(kitchen?.name, "Dapur SPPG Mitra");
    const menuName = sanitizeText(batch?.menu_name, "Menu Makan Bergizi Gratis");
    const batchCode = sanitizeText(batch?.batch_code, "-");
    const reporterSchoolName = sanitizeText(reporterSchool?.name, "Sekolah Mitra SPPG");
    const uniqueReporterCount = new Set(
      batchAlerts.map((r) => r.reporter_school_id),
    ).size || 1;

    const notifTitle = "PERINGATAN DARURAT MAKANAN";
    const notifBody = sanitizeText(
      alert.stage === "post_consumption"
        ? `Tahap 2 Pasca-Konsumsi: ${reporterSchoolName} melaporkan ${alert.symptom_count} siswa bergejala pada menu ${menuName} (${sppgName}). Tahan kloter siang dan siapkan Bank Sampel.`
        : `Tahap 1 Pra-Konsumsi: Hentikan distribusi menu ${menuName} dari ${sppgName} (${reporterSchoolName}).`,
      notifTitle,
    );

    const fcmTopic = `sppg_${alert.sppg_id.replace(/[^a-zA-Z0-9-_.~%]/g, "_")}`;
    const dataPayload: Record<string, string> = {
      type: "cluster_alert",
      alert_id: alert.id,
      sppg_id: alert.sppg_id,
      sppg_name: sppgName,
      batch_id: alert.batch_id,
      batch_code: batchCode,
      menu_name: menuName,
      reporter_school_id: alert.reporter_school_id,
      reporter_school_name: reporterSchoolName,
      stage: alert.stage,
      symptom_count: String(alert.symptom_count ?? 0),
      notes: sanitizeText(alert.notes ?? "", ""),
      broadcast_enabled: String(Boolean(alert.broadcast_enabled)),
      sample_label_code: sanitizeText(alert.sample_label_code ?? "", ""),
      pdf_dispatched: String(Boolean(alert.pdf_dispatched)),
      created_at: alert.created_at,
      active_reporter_count: String(uniqueReporterCount),
    };

    const saJsonRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!saJsonRaw) {
      return jsonResponse({
        ok: true,
        mode: "fcm_unconfigured_realtime_active",
        alert_id: alert.id,
        sppg_id: alert.sppg_id,
        target_schools_count: recipientSchools.length,
        target_tokens_count: tokens.length,
        topic: fcmTopic,
        notification_preview: {
          title: notifTitle,
          body: notifBody,
          data: dataPayload,
        },
      });
    }

    const sa = JSON.parse(saJsonRaw) as {
      project_id?: string;
      client_email?: string;
      private_key?: string;
    };
    if (!sa.project_id || !sa.client_email || !sa.private_key) {
      return jsonResponse({
        ok: true,
        mode: "fcm_invalid_service_account_realtime_active",
        alert_id: alert.id,
        sppg_id: alert.sppg_id,
      });
    }

    const accessToken = await fetchGoogleAccessToken(sa.client_email, sa.private_key);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(sa.project_id)}/messages:send`;

    const targets: Array<{ topic?: string; token?: string }> =
      tokens.length > 0
        ? tokens.map((token) => ({ token }))
        : [{ topic: fcmTopic }];

    let sentCount = 0;
    const sendErrors: string[] = [];

    for (const target of targets) {
      const fcmResp = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            ...target,
            notification: {
              title: notifTitle,
              body: notifBody,
            },
            data: dataPayload,
            android: {
              priority: "HIGH",
              notification: {
                channel_id: "lacak_cluster_alert_emergency",
                sound: "default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
          },
        }),
      });
      if (fcmResp.ok) {
        sentCount++;
      } else {
        sendErrors.push(`status_${fcmResp.status}`);
      }
    }

    return jsonResponse({
      ok: true,
      mode: "fcm_dispatched",
      alert_id: alert.id,
      sppg_id: alert.sppg_id,
      target_schools_count: recipientSchools.length,
      target_tokens_count: tokens.length,
      sent_count: sentCount,
      errors: sendErrors,
    });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: sanitizeText(String(error), "Dispatch failed"),
      },
      500,
    );
  }
});
