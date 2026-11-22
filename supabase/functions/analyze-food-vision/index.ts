import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type VisionMode = "organoleptic" | "plate_waste";

interface LocalScreeningHint {
  label?: string;
  confidence?: number;
  summary?: string;
  hints?: string[];
}

interface RequestBody {
  mode?: VisionMode;
  image_base64?: string;
  images_base64?: string[];
  mime_type?: string;
  menu_name?: string;
  local_screening?: LocalScreeningHint;
}

interface GeminiCallOutcome {
  ok: boolean;
  text: string;
  modelUsed: string;
  lastStatus: number;
  lastErrorDetail: string;
}

const rateBuckets = new Map<string, { count: number; resetAtMs: number }>();
const RATE_LIMIT_PER_MINUTE = 20;
const VISION_MODELS = [
  "gemini-3.8-flash",
  "gemini-3.5-flash-lite",
];
const PER_ATTEMPT_TIMEOUT_MS = 22_000;

const ORGANOLEPTIC_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    rice_check: {
      type: "STRING",
      description:
        "Observasi detail nasi/karbohidrat (tengah dan tepi): apakah putih bersih atau ada bagian menguning, kecokelatan, bintik abu-abu/hitam jamur, berair, atau menggumpal.",
    },
    protein_check: {
      type: "STRING",
      description:
        "Observasi detail SETIAP item lauk/protein secara terpisah (misal ikan, ayam, tahu, tempe, telur): periksa bercak jamur putih/abu-abu menyerupai kapas, bagian gosong menghitam/hangus pada tahu/tempe/gorengan, lendir, atau kotoran di sekat.",
    },
    vegetable_check: {
      type: "STRING",
      description:
        "Observasi detail sayur dan kuahnya: apakah segar atau layu gelap, berair keruh/berbusa/berbuih tanda fermentasi basi, berlendir, atau ada bercak putih/abu-abu jamur.",
    },
    fruit_and_pack_check: {
      type: "STRING",
      description:
        "Observasi detail SETIAP potongan buah dan kemasan minuman/wadah: periksa dengan teliti apakah buah potong (pepaya, melon, semangka, dll) memiliki bercak putih/abu-abu seperti kapas atau serbuk jamur, lembek busuk, atau kemasan menggembung/bocor.",
    },
    anomalies_found: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "Daftar detail setiap kejanggalan keamanan & mutu pangan yang terlihat (sebutkan nama bahan makanan dan ciri spesifiknya, misal 'Bercak jamur putih pada pepaya', 'Jamur putih pada ikan', 'Tahu tampak gosong menghitam'). Kosongkan HANYA jika semua komponen benar-benar bersih.",
    },
    freshness_status: {
      type: "STRING",
      enum: ["fresh_likely", "suspicious_discoloration", "packaging_anomaly"],
    },
    slime_or_discoloration_detected: { type: "BOOLEAN" },
    packaging_issue_detected: { type: "BOOLEAN" },
    confidence: { type: "NUMBER" },
    summary_id: {
      type: "STRING",
      description:
        "Ringkasan 1-3 kalimat bahasa Indonesia sederhana dan tegas untuk guru (maks 280 karakter, tanpa emoji, tanpa em-dash) yang menyebutkan semua komponen bermasalah.",
    },
  },
  required: [
    "rice_check",
    "protein_check",
    "vegetable_check",
    "fruit_and_pack_check",
    "anomalies_found",
    "freshness_status",
    "slime_or_discoloration_detected",
    "packaging_issue_detected",
    "confidence",
    "summary_id",
  ],
};

const PLATE_WASTE_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    rice_observation: {
      type: "STRING",
      description: "Seberapa penuh nasi yang tersisa di sekat nasi.",
    },
    protein_observation: {
      type: "STRING",
      description:
        "Seberapa banyak daging/lauk yang tersisa (bedakan tulang bekas makan dari daging yang masih utuh).",
    },
    veg_observation: {
      type: "STRING",
      description: "Seberapa penuh sayur yang masih tersisa di sekat sayur.",
    },
    carb_waste_pct: { type: "INTEGER" },
    protein_waste_pct: { type: "INTEGER" },
    veg_waste_pct: { type: "INTEGER" },
    summary_id: {
      type: "STRING",
      description:
        "Ringkasan singkat bahasa Indonesia sederhana (maks 180 karakter, tanpa emoji, tanpa em-dash).",
    },
  },
  required: [
    "rice_observation",
    "protein_observation",
    "veg_observation",
    "carb_waste_pct",
    "protein_waste_pct",
    "veg_waste_pct",
    "summary_id",
  ],
};

function jsonResponse(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function sanitizeText(value: unknown, fallback: string): string {
  if (typeof value !== "string") {
    return fallback;
  }
  const cleaned = value
    .replaceAll("\u2014", ", ")
    .replaceAll("\u2013", "-")
    .replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]/gu, "")
    .replace(/\s{2,}/g, " ")
    .trim();
  return cleaned.length > 0 ? cleaned : fallback;
}

function clampPct(value: unknown, fallback = 0): number {
  const num = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(num)) {
    return fallback;
  }
  return Math.max(0, Math.min(100, Math.round(num)));
}

function extractJwtSubject(authHeader: string | null): string {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return "anonymous";
  }
  try {
    const token = authHeader.slice(7).trim();
    const parts = token.split(".");
    if (parts.length < 2) {
      return "anonymous";
    }
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
    const decoded = JSON.parse(atob(padded)) as { sub?: unknown };
    return typeof decoded.sub === "string" && decoded.sub.length > 0
      ? decoded.sub
      : "anonymous";
  } catch {
    return "anonymous";
  }
}

function isRateLimited(subject: string): boolean {
  const now = Date.now();
  const current = rateBuckets.get(subject);
  if (!current || current.resetAtMs <= now) {
    rateBuckets.set(subject, { count: 1, resetAtMs: now + 60_000 });
    return false;
  }
  if (current.count >= RATE_LIMIT_PER_MINUTE) {
    return true;
  }
  current.count += 1;
  return false;
}

function extractJsonText(rawText: string): string {
  const trimmed = rawText.trim();
  const fenceMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenceMatch ? fenceMatch[1].trim() : trimmed;
  const firstBrace = candidate.indexOf("{");
  const lastBrace = candidate.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    return candidate.slice(firstBrace, lastBrace + 1);
  }
  return candidate;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function mapGeminiErrorSummary(status: number, hasEnvKey: boolean): string {
  if (!hasEnvKey) {
    return "Kunci AI server (GEMINI_API_KEY) belum diatur. Lanjutkan pemeriksaan secara manual.";
  }
  if (status === 400 || status === 401 || status === 403) {
    return "Kunci akses AI server tidak valid atau ditolak. Periksa pengaturan GEMINI_API_KEY lalu coba lagi.";
  }
  if (status === 429) {
    return "Kuota AI server sedang penuh sementara. Coba lagi sebentar atau gunakan pemeriksaan manual.";
  }
  if (status === 503) {
    return "Server AI sedang sangat sibuk sementara. Coba foto ulang atau lanjutkan pemeriksaan manual.";
  }
  return "AI server belum dapat merespons saat ini. Lanjutkan pemeriksaan secara manual.";
}

async function callGeminiModelChain(
  apiKey: string,
  parts: Array<Record<string, unknown>>,
  responseSchema: Record<string, unknown>,
): Promise<GeminiCallOutcome> {
  let lastStatus = 0;
  let lastErrorDetail = "unknown";

  // Try each model; retry once briefly on transient 503 high demand.
  const attempts: Array<{ model: string; delayBeforeMs: number }> = [];
  for (const model of VISION_MODELS) {
    attempts.push({ model, delayBeforeMs: 0 });
  }
  attempts.push({ model: VISION_MODELS[0], delayBeforeMs: 1_200 });

  for (const attempt of attempts) {
    if (attempt.delayBeforeMs > 0) {
      await sleep(attempt.delayBeforeMs);
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), PER_ATTEMPT_TIMEOUT_MS);
    try {
      const resp = await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/" +
          attempt.model +
          ":generateContent?key=" +
          encodeURIComponent(apiKey),
        {
          method: "POST",
          signal: controller.signal,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts }],
            generationConfig: {
              responseMimeType: "application/json",
              responseSchema,
              temperature: 0.1,
              maxOutputTokens: 1536,
            },
          }),
        },
      );

      if (!resp.ok) {
        lastStatus = resp.status;
        const errBody = await resp.text().catch(() => "");
        lastErrorDetail = errBody.slice(0, 260);
        console.error(
          `[analyze-food-vision] model=${attempt.model} status=${resp.status} body=${lastErrorDetail}`,
        );
        if (resp.status === 401 || resp.status === 403) {
          break;
        }
        continue;
      }

      const rawResult = (await resp.json()) as {
        candidates?: Array<{
          content?: {
            parts?: Array<{ text?: string; thought?: boolean }>;
          };
          finishReason?: string;
        }>;
      };

      const respParts = rawResult.candidates?.[0]?.content?.parts ?? [];
      let rawText = "";
      for (const part of respParts) {
        if (!part.thought && typeof part.text === "string" && part.text.trim().length > 0) {
          rawText = part.text;
        }
      }
      if (!rawText && respParts.length > 0) {
        rawText = respParts[respParts.length - 1]?.text ?? "";
      }

      const extracted = extractJsonText(rawText);
      if (extracted.length > 0) {
        try {
          JSON.parse(extracted);
          return {
            ok: true,
            text: extracted,
            modelUsed: attempt.model,
            lastStatus: 200,
            lastErrorDetail: "",
          };
        } catch (parseErr) {
          lastStatus = 502;
          lastErrorDetail = `invalid_json:${String(parseErr).slice(0, 120)}`;
          console.error(
            `[analyze-food-vision] model=${attempt.model} invalid JSON finishReason=${rawResult.candidates?.[0]?.finishReason} raw=${rawText.slice(0, 220)}`,
          );
        }
      }
    } catch (err) {
      lastStatus = 504;
      lastErrorDetail = String(err).slice(0, 180);
      console.error(`[analyze-food-vision] model=${attempt.model} exception=${lastErrorDetail}`);
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    ok: false,
    text: "",
    modelUsed: "",
    lastStatus,
    lastErrorDetail,
  };
}

function buildLocalScreeningContext(local?: LocalScreeningHint): string {
  if (!local) {
    return "";
  }
  const hints = Array.isArray(local.hints)
    ? local.hints.map((h) => sanitizeText(h, "")).filter((h) => h.length > 0)
    : [];
  const label = sanitizeText(local.label, "");
  const summary = sanitizeText(local.summary, "");
  if (!label && !summary && hints.length === 0) {
    return "";
  }
  return `\nCatatan pra-skrining awal dari perangkat HP (verifikasi ulang secara independen dari foto, jangan bergantung buta pada pra-skrining): status="${label}", ringkasan="${summary}", temuan=[${hints.join("; ")}].`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { ok: false, fallback_required: true, summary_id: "Metode HTTP tidak didukung." },
      405,
    );
  }

  const subject = extractJwtSubject(req.headers.get("Authorization"));
  if (isRateLimited(subject)) {
    return jsonResponse(
      {
        ok: false,
        provider: "rate_limited",
        fallback_required: true,
        summary_id:
          "Permintaan analisis sedang padat. Lanjutkan menggunakan pemeriksaan manual.",
      },
      429,
    );
  }

  let body: RequestBody;
  try {
    body = (await req.json()) as RequestBody;
  } catch {
    return jsonResponse(
      {
        ok: false,
        provider: "invalid_request",
        fallback_required: true,
        summary_id: "Format permintaan foto tidak valid.",
      },
      400,
    );
  }

  const mode: VisionMode = body.mode === "plate_waste" ? "plate_waste" : "organoleptic";
  const mimeType = typeof body.mime_type === "string" && body.mime_type.length > 0
    ? body.mime_type
    : "image/webp";
  const menuName = sanitizeText(body.menu_name, "Menu Makan Bergizi Gratis");

  const images: string[] = [];
  if (typeof body.image_base64 === "string" && body.image_base64.length > 0) {
    images.push(body.image_base64);
  }
  if (Array.isArray(body.images_base64)) {
    for (const item of body.images_base64) {
      if (typeof item === "string" && item.length > 0 && images.length < 5) {
        images.push(item);
      }
    }
  }

  if (images.length === 0) {
    return jsonResponse(
      {
        ok: false,
        provider: "missing_image",
        fallback_required: true,
        summary_id: "Foto sampel belum tersedia. Gunakan checklist manual di perangkat.",
      },
      400,
    );
  }

  const envKey = Deno.env.get("GEMINI_API_KEY")?.trim() ?? "";
  if (envKey.length === 0) {
    console.error("[analyze-food-vision] GEMINI_API_KEY secret is empty");
    return jsonResponse({
      ok: false,
      provider: "missing_api_key",
      fallback_required: true,
      mode,
      summary_id: mapGeminiErrorSummary(401, false),
    });
  }

  const localContext = buildLocalScreeningContext(body.local_screening);

  const prompt =
    mode === "organoleptic"
      ? `Anda adalah inspektur keamanan pangan sekolah yang sangat teliti dan mengutamakan keselamatan anak (prinsip kehati-hatian BGN/BPOM) untuk menu "${menuName}".
Tugas Anda: periksa SETIAP sekat makanan dan SETIAP potongan makanan di dalamnya secara detail (zoom in setiap benda satu per satu) sebelum mengambil kesimpulan. Lebih baik memberi peringatan (suspicious_discoloration) daripada meloloskan makanan yang berjamur, gosong, atau mulai basi.

Periksa seluruh 5 area ini secara ketat dan terpisah:
1. NASI / KARBOHIDRAT: Periksa bagian tengah maupun pinggir nasi apakah ada area menguning, kecokelatan kusam, bintik/bercak abu-abu gelap atau hitam (tanda jamur nasi), basah berlendir, atau menggumpal tidak wajar. Jika ada bagian menguning atau berbintik gelap, WAJIB dicatat ke anomalies_found.
2. SAYURAN & KUAH: Periksa warna dan permukaan sayur apakah tampak layu gelap/kehitaman, berlendir, memiliki bercak putih/abu-abu halus (kapang/jamur), atau kuah tampak berbusa/berbuih keruh (tanda fermentasi basi). Buih/busa pada kuah maupun bercak putih WAJIB dilaporkan ke anomalies_found.
3. LAUK / PROTEIN (periksa SETIAP potongan, misalnya ikan/ayam DAN tahu/tempe/telur satu per satu):
   - Periksa teliti apakah ada lapisan/bercak putih atau abu-abu seperti kapas/serbuk (jamur/kapang) pada permukaan ikan goreng, tahu, tempe, atau daging. Jangan terkecoh mengira bercak putih jamur sebagai bumbu/garam jika bentuknya menggumpal seperti kapas atau tidak merata.
   - Periksa teliti apakah tahu, tempe, ikan, atau lauk goreng memiliki bagian GOSONG MENGHITAM / hangus terbakar yang mencolok. Bagian gosong menghitam WAJIB dicatat sebagai temuan mutu & keamanan pangan.
   - Catat juga bila ada noda/minyak kotor di sekat kosong, namun TETAP laporkan kondisi masing-masing lauk secara jujur.
4. BUAH & KEMASAN:
   - Periksa SETIAP potongan buah (pepaya, melon, semangka, jeruk, dll.) apakah ada BERCAK PUTIH/ABU-ABU halus seperti kapas atau bulu (jamur/kapang), bagian lembek berair, atau busuk kehitaman. Bercak putih kecil pada permukaan pepaya/buah potong WAJIB dilaporkan sebagai jamur di anomalies_found dan fruit_and_pack_check (JANGAN pernah menyebut segar jika ada titik/bercak putih jamur).
   - Bedakan bintik cokelat matang alami pada kulit pisang dari busuk berair/berjamur.
   - Periksa kotak susu/minuman/wadah apakah menggembung, bocor, basah merembes, atau segel rusak.
5. Jika foto diambil dari layar (ada garis moire tipis), abaikan garis layarnya, tetapi TETAP periksa bercak jamur putih, bagian gosong, perubahan warna, dan busa kuah secara ketat.${localContext}

Aturan keputusan:
- Jika ada SATU SAJA kejanggalan (nasi menguning/berbintik, kuah sayur berbuih/layu gelap, lauk berjamur atau tahu/lauk gosong menghitam, buah ada bercak putih jamur/busuk): masukkan semua temuan ke anomalies_found, set slime_or_discoloration_detected = true, dan freshness_status = "suspicious_discoloration".
- Jika kemasan minuman/wadah menggembung/bocor/rusak: set packaging_issue_detected = true dan freshness_status = "packaging_anomaly".
- Set freshness_status = "fresh_likely" HANYA jika seluruh komponen (nasi, sayur, semua potong lauk, semua potong buah, dan kemasan) benar-benar bersih tanpa bercak jamur, gosong, layu/buih, maupun perubahan warna.
- Tulis summary_id dalam bahasa Indonesia sederhana yang lengkap dan tegas (sebutkan langsung setiap komponen bermasalah yang ditemukan, tanpa istilah teknis, tanpa emoji, tanpa em-dash).`
      : `Anda adalah asisten estimasi sisa makanan ompreng siswa untuk menu "${menuName}".
Periksa setiap sekat makanan secara terpisah dan jelaskan dulu apa yang terlihat di masing-masing sekat:
1. Sekat NASI / KARBOHIDRAT: bandingkan sisa nasi yang terlihat terhadap kapasitas porsi penuh sekat tersebut (0 = habis tak bersisa, 25 = tinggal sedikit/remah di sudut, 50 = tersisa sekitar setengah, 75-100 = masih hampir penuh/utuh).
2. Sekat LAUK / PROTEIN: bedakan dengan tegas antara TULANG / sisa kulit / noda minyak (itu berarti daging sudah habis -> 0% sampai 25%) dengan potongan daging/telur/tahu yang masih utuh (50% sampai 100%).
3. Sekat SAYURAN: ukur seberapa penuh sekat sayur masih berisi sayuran dibandingkan ukuran sekat sayur itu sendiri (jangan memberi nilai rendah hanya karena sekat sayur lebih kecil dari sekat nasi).
Abaikan pantulan logam stainless ompreng kosong. Gunakan bahasa Indonesia sederhana tanpa emoji dan tanpa em-dash.`;

  const parts: Array<Record<string, unknown>> = [{ text: prompt }];
  for (const imgB64 of images) {
    parts.push({
      inline_data: {
        mime_type: mimeType,
        data: imgB64,
      },
    });
  }

  const schema = mode === "plate_waste"
    ? PLATE_WASTE_RESPONSE_SCHEMA
    : ORGANOLEPTIC_RESPONSE_SCHEMA;

  const outcome = await callGeminiModelChain(envKey, parts, schema);
  if (!outcome.ok) {
    return jsonResponse({
      ok: false,
      provider: "gemini_unavailable",
      fallback_required: true,
      mode,
      error_status: outcome.lastStatus,
      summary_id: mapGeminiErrorSummary(outcome.lastStatus, true),
    });
  }

  try {
    const parsed = JSON.parse(outcome.text) as Record<string, unknown>;

    if (mode === "plate_waste") {
      return jsonResponse({
        ok: true,
        provider: "gemini_flash",
        model: outcome.modelUsed,
        fallback_required: false,
        mode,
        carb_waste_pct: clampPct(parsed.carb_waste_pct, 25),
        protein_waste_pct: clampPct(parsed.protein_waste_pct, 25),
        veg_waste_pct: clampPct(parsed.veg_waste_pct, 25),
        rice_observation: sanitizeText(parsed.rice_observation, ""),
        protein_observation: sanitizeText(parsed.protein_observation, ""),
        veg_observation: sanitizeText(parsed.veg_observation, ""),
        summary_id: sanitizeText(
          parsed.summary_id,
          "Estimasi sisa ompreng selesai. Sesuaikan angka bila perlu.",
        ),
      });
    }

    const rawAnomalies = Array.isArray(parsed.anomalies_found)
      ? parsed.anomalies_found
          .map((item) => sanitizeText(item, ""))
          .filter((item) => item.length > 0)
      : [];

    const packagingDetected = Boolean(parsed.packaging_issue_detected);
    const discolorationDetected =
      Boolean(parsed.slime_or_discoloration_detected) ||
      (rawAnomalies.length > 0 && !packagingDetected);

    const allowedStatuses = new Set([
      "fresh_likely",
      "suspicious_discoloration",
      "packaging_anomaly",
    ]);
    const rawStatus = typeof parsed.freshness_status === "string"
      ? parsed.freshness_status
      : "fresh_likely";

    let freshnessStatus = allowedStatuses.has(rawStatus)
      ? rawStatus
      : "fresh_likely";

    if (packagingDetected) {
      freshnessStatus = "packaging_anomaly";
    } else if (discolorationDetected || rawAnomalies.length > 0) {
      freshnessStatus = "suspicious_discoloration";
    }

    const rawConf = typeof parsed.confidence === "number"
      ? parsed.confidence
      : Number(parsed.confidence);
    const confidence = Number.isFinite(rawConf)
      ? Math.max(0, Math.min(1, Number(rawConf.toFixed(3))))
      : 0.8;

    const fallbackSummary = rawAnomalies.length > 0
      ? `Perlu perhatian: ${rawAnomalies.join("; ")}. Periksa bau dan kondisi makanan secara langsung.`
      : "Pemeriksaan foto selesai. Tetap konfirmasi dengan 3 pengecekan manual di bawah.";

    return jsonResponse({
      ok: true,
      provider: "gemini_flash",
      model: outcome.modelUsed,
      fallback_required: false,
      mode,
      freshness_status: freshnessStatus,
      confidence,
      slime_or_discoloration_detected: discolorationDetected,
      packaging_issue_detected: packagingDetected,
      anomalies_found: rawAnomalies,
      rice_check: sanitizeText(parsed.rice_check, ""),
      protein_check: sanitizeText(parsed.protein_check, ""),
      vegetable_check: sanitizeText(parsed.vegetable_check, ""),
      fruit_and_pack_check: sanitizeText(parsed.fruit_and_pack_check, ""),
      summary_id: sanitizeText(parsed.summary_id, fallbackSummary),
    });
  } catch (err) {
    console.error(`[analyze-food-vision] response handling error=${String(err)}`);
    return jsonResponse({
      ok: false,
      provider: "gemini_parse_error",
      fallback_required: true,
      mode,
      summary_id:
        "Hasil analisis AI belum dapat dibaca dengan sempurna. Coba foto ulang atau gunakan cek manual.",
    });
  }
});
