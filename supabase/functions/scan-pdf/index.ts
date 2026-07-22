import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// =============================================================================
// scan-pdf — Supabase Edge Function
// =============================================================================
//
// PURPOSE
// -------
// Performs heuristic PDF security validation before a file is accepted for
// upload. This function does NOT perform antivirus or malware signature
// scanning. It enforces structural rules that reject clearly invalid,
// malformed, encrypted, or actively dangerous PDF documents.
//
// WHAT THIS FUNCTION DOES
// -----------------------
// 1. Authenticates the request (Firebase ID token required)
// 2. Enforces server-side per-user rate limiting (5/hr, burst 2/30s)
// 3. Validates Content-Type header
// 4. Runs heuristic PDF validation:
//    - Magic bytes: file must begin with %PDF-
//    - PDF trailer: must contain %%EOF (rejects truncated/corrupted files)
//    - Encryption: rejects /Encrypt (password-protected PDFs)
//    - Active content: rejects /JavaScript, /Launch, /OpenAction,
//      /EmbeddedFile, /EmbeddedFiles, /SubmitForm, /ImportData,
//      /RichMedia, /Movie, /GoToR
//    - Embedded executables: rejects PE (MZ) and ELF magic bytes in body
//    - Page structure: must have /Page objects
// 5. Computes SHA-256 hash (used for deduplication in Firestore)
// 6. Optionally delegates to an external AV scanner (see EXTENSIBILITY below)
//
// WHAT THIS FUNCTION DOES NOT DO
// --------------------------------
// - Does NOT perform virus signature scanning
// - Does NOT detect polymorphic or encrypted malware
// - Does NOT run ClamAV or any antivirus engine
// - Does NOT sandbox or emulate file execution
// - Does NOT detect unknown/novel threats
//
// EXTENSIBILITY — ClamAV / External AV Service
// ---------------------------------------------
// When you are ready to integrate a real antivirus service (e.g., a ClamAV
// container on Google Cloud Run or Fly.io), set the Supabase Secret:
//
//   AV_SCAN_ENDPOINT=https://your-clamav-service.run.app/scan
//   AV_SCAN_SECRET=your-shared-secret
//
// This function will automatically call that endpoint after the heuristic
// scan passes, forwarding the file bytes and the computed SHA-256 hash.
// The external service must respond with:
//   { clean: boolean, threat?: string }
//
// The Flutter app and this Edge Function's API contract do NOT change when
// the AV service is added — only the Supabase Secrets need to be set.
// The heuristic scan always runs first as a fast pre-filter.
//
// RATE LIMITING
// -------------
// In-memory per Edge Function instance. For high-traffic production, swap
// uploadRateStore to Supabase KV or an external Redis instance.
//
// =============================================================================

// ─── CORS ─────────────────────────────────────────────────────────────────────
// Mobile Flutter clients send no Origin header — they pass through unconditionally.
// Web clients must originate from one of the known app origins below.
const ALLOWED_ORIGINS = [
  "https://studysphere.app",
  "https://studysphere-app-3a480.web.app",
  "https://studysphere-app-3a480.firebaseapp.com",
  "http://localhost",
  "http://localhost:3000",
]

function getCorsHeaders(origin: string | null): Record<string, string> {
  if (!origin) {
    return {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type, x-firebase-token",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    }
  }
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-firebase-token",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  }
}

// ─── SERVER-SIDE RATE LIMITING ─────────────────────────────────────────────────
// 5 uploads per 60 minutes per user. Burst guard: max 2 in any 30-second window.
interface RateLimitEntry {
  count: number
  windowStart: number
  timestamps: number[]
}
const uploadRateStore = new Map<string, RateLimitEntry>()

const UPLOAD_WINDOW_MS  = 60 * 60 * 1000 // 1 hour
const UPLOAD_MAX_PER_WINDOW = 5
const BURST_WINDOW_MS   = 30 * 1000       // 30 seconds
const BURST_MAX         = 2

function checkUploadRateLimit(
  uid: string
): { allowed: boolean; retryAfterSecs?: number; reason?: string } {
  const now = Date.now()
  let entry = uploadRateStore.get(uid)

  if (!entry) {
    entry = { count: 0, windowStart: now, timestamps: [] }
  }

  // Reset hourly window if expired
  if (now - entry.windowStart >= UPLOAD_WINDOW_MS) {
    entry = { count: 0, windowStart: now, timestamps: [] }
  }

  // Prune timestamps older than burst window
  entry.timestamps = entry.timestamps.filter(t => now - t < BURST_WINDOW_MS)

  // Burst check
  if (entry.timestamps.length >= BURST_MAX) {
    const oldestBurst   = entry.timestamps[0]
    const retryAfterMs  = BURST_WINDOW_MS - (now - oldestBurst)
    return {
      allowed: false,
      retryAfterSecs: Math.ceil(retryAfterMs / 1000),
      reason: `Uploading too fast. Please wait ${Math.ceil(retryAfterMs / 1000)} seconds.`,
    }
  }

  // Hourly limit check
  if (entry.count >= UPLOAD_MAX_PER_WINDOW) {
    const retryAfterMs = UPLOAD_WINDOW_MS - (now - entry.windowStart)
    return {
      allowed: false,
      retryAfterSecs: Math.ceil(retryAfterMs / 1000),
      reason: "Upload limit reached (5 per hour). Please try again later.",
    }
  }

  entry.count++
  entry.timestamps.push(now)
  uploadRateStore.set(uid, entry)
  return { allowed: true }
}

// ─── FIREBASE TOKEN VERIFICATION ──────────────────────────────────────────────
async function verifyFirebaseToken(
  token: string,
  firebaseApiKey: string
): Promise<{ uid: string } | null> {
  try {
    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${firebaseApiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken: token }),
      }
    )
    const data = await res.json()
    if (!res.ok || !data.users?.[0]?.localId) return null
    return { uid: data.users[0].localId }
  } catch {
    return null
  }
}

// ─── HEURISTIC PDF VALIDATOR ───────────────────────────────────────────────────
// These checks operate on raw bytes without any antivirus engine or signature
// database. They enforce structural rules and block active content categories
// that are commonly weaponised in PDF-based attacks.
//
// Limitations:
// - Cannot detect polyglot files that are valid PDFs and valid executables
//   simultaneously (unless the executable magic bytes appear in small files)
// - Cannot detect encrypted or obfuscated payloads within image streams
// - Cannot detect novel attack techniques not covered by the pattern list
// - Has false-positive risk on PDFs with uncommon-but-legitimate content
//   (e.g., advanced form submissions using /SubmitForm)

const MAX_PDF_BYTES = 20 * 1024 * 1024  // 20 MB hard limit

// %PDF- magic bytes (ISO 32000-1, Section 7.5.2)
const PDF_MAGIC = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d])

// PDF operators associated with active/executable content.
// These are checked as byte patterns against the raw file body.
// Note: /XObject, /URI, /AcroForm, and /Sound are skipped due to high
// false-positive rate in legitimate academic PDFs.
const BLOCKED_OPERATORS: Array<{ name: string; bytes: Uint8Array }> = [
  { name: "JavaScript action",    bytes: new TextEncoder().encode("/JavaScript")  },
  { name: "JS shorthand",         bytes: new TextEncoder().encode("/JS ")         },
  { name: "JS shorthand (paren)", bytes: new TextEncoder().encode("/JS(")         },
  { name: "OpenAction",           bytes: new TextEncoder().encode("/OpenAction")  },
  { name: "Launch action",        bytes: new TextEncoder().encode("/Launch")      },
  { name: "EmbeddedFile",         bytes: new TextEncoder().encode("/EmbeddedFile")},
  { name: "EmbeddedFiles",        bytes: new TextEncoder().encode("/EmbeddedFiles")},
  { name: "SubmitForm",           bytes: new TextEncoder().encode("/SubmitForm")  },
  { name: "ImportData",           bytes: new TextEncoder().encode("/ImportData")  },
  { name: "RichMedia",            bytes: new TextEncoder().encode("/RichMedia")   },
  { name: "Movie action",         bytes: new TextEncoder().encode("/Movie")       },
  { name: "GoToR (remote goto)",  bytes: new TextEncoder().encode("/GoToR")       },
]

// /Encrypt indicates password protection — these files cannot be safely inspected
const ENCRYPT_BYTES = new TextEncoder().encode("/Encrypt")

// PE (Windows executable) and ELF (Linux executable) magic bytes
const PE_MAGIC  = new Uint8Array([0x4d, 0x5a])             // MZ
const ELF_MAGIC = new Uint8Array([0x7f, 0x45, 0x4c, 0x46]) // \x7fELF

function containsBytes(haystack: Uint8Array, needle: Uint8Array): boolean {
  if (needle.length === 0 || haystack.length < needle.length) return false
  outer: for (let i = 0; i <= haystack.length - needle.length; i++) {
    for (let j = 0; j < needle.length; j++) {
      if (haystack[i + j] !== needle[j]) continue outer
    }
    return true
  }
  return false
}

function containsBytesInRange(
  haystack: Uint8Array,
  needle: Uint8Array,
  start: number,
  end: number
): boolean {
  return containsBytes(haystack.slice(start, Math.min(end, haystack.length)), needle)
}

interface HeuristicResult {
  valid: boolean
  hash: string
  reason?: string
  pdfVersion?: string
  pageCount?: number
}

async function runHeuristicValidation(bytes: Uint8Array): Promise<HeuristicResult> {
  // 1. Size
  if (bytes.length === 0) {
    return { valid: false, hash: "", reason: "File is empty." }
  }
  if (bytes.length > MAX_PDF_BYTES) {
    return { valid: false, hash: "", reason: "File exceeds the 20 MB size limit." }
  }

  // 2. Magic bytes — must begin with %PDF-
  if (!containsBytesInRange(bytes, PDF_MAGIC, 0, 10)) {
    return { valid: false, hash: "", reason: "File is not a valid PDF (missing PDF header)." }
  }

  // 3. Extract PDF version for the audit log
  let pdfVersion: string | undefined
  try {
    const header = new TextDecoder("latin1").decode(bytes.slice(0, 16))
    const m = header.match(/%PDF-(\d+\.\d+)/)
    if (m) pdfVersion = m[1]
  } catch { /* non-critical */ }

  // 4. SHA-256 hash (used for deduplication; also passed to optional AV service)
  const hashBuffer = await crypto.subtle.digest("SHA-256", bytes)
  const hash = Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("")

  // 5. EOF trailer — truncated files are rejected
  const eofBytes      = new TextEncoder().encode("%%EOF")
  const trailerWindow = bytes.slice(Math.max(0, bytes.length - 1024))
  if (!containsBytes(trailerWindow, eofBytes)) {
    return { valid: false, hash, reason: "PDF appears truncated or corrupted (missing %%EOF)." }
  }

  // 6. Encryption — password-protected PDFs cannot be validated
  if (containsBytes(bytes, ENCRYPT_BYTES)) {
    return { valid: false, hash, reason: "Encrypted PDFs are not accepted." }
  }

  // 7. Blocked active-content operators
  for (const op of BLOCKED_OPERATORS) {
    if (containsBytes(bytes, op.bytes)) {
      return {
        valid: false,
        hash,
        reason: `PDF contains disallowed content: ${op.name}.`,
      }
    }
  }

  // 8. Embedded executable headers
  const body = bytes.slice(8)
  if (containsBytes(body, PE_MAGIC) && bytes.length < 50_000) {
    // Small files: PE magic is suspicious. Large files: too many false positives
    // from JPEG/PNG image data that incidentally contains MZ bytes.
    return { valid: false, hash, reason: "PDF may contain an embedded Windows executable." }
  }
  if (containsBytes(body, ELF_MAGIC)) {
    return { valid: false, hash, reason: "PDF may contain an embedded Linux executable." }
  }

  // 9. Page content — must have at least one /Page object
  const pageBytes = new TextEncoder().encode("/Page")
  if (!containsBytes(bytes, pageBytes)) {
    return { valid: false, hash, reason: "PDF has no readable page content." }
  }

  // 10. Approximate page count (for the audit log)
  let pageCount: number | undefined
  try {
    const text = new TextDecoder("latin1").decode(bytes)
    const matches = text.match(/\/Type\s*\/Page[^s]/g)
    if (matches) pageCount = matches.length
  } catch { /* non-critical */ }

  return { valid: true, hash, pdfVersion, pageCount }
}

// ─── OPTIONAL EXTERNAL AV SERVICE ─────────────────────────────────────────────
// This is the plug-in point for a real antivirus service.
//
// When AV_SCAN_ENDPOINT is set in Supabase Secrets, this function forwards the
// file bytes (and the pre-computed hash) to the external service for scanning.
// The external service should return { clean: boolean, threat?: string }.
//
// If AV_SCAN_ENDPOINT is not set, this step is skipped entirely — no stub, no
// placeholder. The heuristic scan result is used as-is.
//
// Plug-in contract the external service must implement:
//   POST {AV_SCAN_ENDPOINT}
//   Headers:
//     Content-Type: application/octet-stream
//     X-File-Hash: <sha256>
//     Authorization: Bearer {AV_SCAN_SECRET}
//   Body: raw file bytes
//   Response 200: { "clean": true }
//   Response 200: { "clean": false, "threat": "Eicar-Test-Signature" }
//   Response 4xx/5xx: treated as scan error (see failOpen setting below)
//
// Compatible services:
//   - ClamAV + REST wrapper (e.g., https://github.com/benzino77/clamav-rest)
//     running on Google Cloud Run, Fly.io, or any container platform
//   - Any custom service implementing the contract above

interface AvResult {
  clean: boolean
  threat?: string
  skipped: boolean  // true when AV_SCAN_ENDPOINT is not configured
}

async function runExternalAvScan(
  bytes: Uint8Array,
  hash: string
): Promise<AvResult> {
  const endpoint = Deno.env.get("AV_SCAN_ENDPOINT")

  // AV service not configured — skip gracefully
  if (!endpoint) {
    return { clean: true, skipped: true }
  }

  const secret = Deno.env.get("AV_SCAN_SECRET") ?? ""

  try {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/octet-stream",
        "X-File-Hash": hash,
        "Authorization": `Bearer ${secret}`,
      },
      body: bytes,
      // Hard timeout — never block the upload indefinitely on AV service issues
      signal: AbortSignal.timeout(20_000),
    })

    if (!res.ok) {
      // AV service returned an error — log it but apply the fail-open policy
      // (see FAIL_OPEN_ON_AV_ERROR below). Never silently swallow the log.
      console.error(JSON.stringify({
        event: "av_scan_error",
        status: res.status,
        hash,
        ts: new Date().toISOString(),
      }))
      return { clean: FAIL_OPEN_ON_AV_ERROR, skipped: false }
    }

    const data = await res.json() as { clean: boolean; threat?: string }
    return { clean: data.clean, threat: data.threat, skipped: false }

  } catch (err) {
    // Network error or timeout — apply fail-open policy
    console.error(JSON.stringify({
      event: "av_scan_unreachable",
      error: String(err),
      hash,
      ts: new Date().toISOString(),
    }))
    return { clean: FAIL_OPEN_ON_AV_ERROR, skipped: false }
  }
}

// FAIL_OPEN_ON_AV_ERROR — behaviour when the external AV service is unreachable:
//   true  = allow the upload (fail open)  — better UX, slight security trade-off
//   false = block the upload (fail closed) — strict security, may impact availability
//
// Recommended: true for development; false for high-security production.
// Override by setting AV_FAIL_OPEN=false in Supabase Secrets.
const FAIL_OPEN_ON_AV_ERROR =
  (Deno.env.get("AV_FAIL_OPEN") ?? "true") !== "false"

// ─── MAIN HANDLER ─────────────────────────────────────────────────────────────
serve(async (req) => {
  const origin      = req.headers.get("origin")
  const corsHeaders = getCorsHeaders(origin)

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }

  try {
    // ── Step 1: Authenticate ───────────────────────────────────────────────────
    const token = req.headers.get("x-firebase-token")
    if (!token) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const firebaseApiKey = Deno.env.get("FIREBASE_API_KEY")
    if (!firebaseApiKey) {
      console.error("[scan-pdf] FIREBASE_API_KEY not set in Supabase Secrets")
      return new Response(
        JSON.stringify({ error: "Service temporarily unavailable" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const user = await verifyFirebaseToken(token, firebaseApiKey)
    if (!user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Step 2: Rate limiting ──────────────────────────────────────────────────
    const rateCheck = checkUploadRateLimit(user.uid)
    if (!rateCheck.allowed) {
      console.log(JSON.stringify({
        event: "upload_rate_limited", uid: user.uid, ts: new Date().toISOString(),
      }))
      return new Response(
        JSON.stringify({ error: rateCheck.reason }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": String(rateCheck.retryAfterSecs ?? 60),
          },
        }
      )
    }

    // ── Step 3: Content-Type ───────────────────────────────────────────────────
    const contentType = req.headers.get("content-type") ?? ""
    if (
      !contentType.includes("application/octet-stream") &&
      !contentType.includes("application/pdf")
    ) {
      return new Response(
        JSON.stringify({ error: "Content-Type must be application/octet-stream or application/pdf" }),
        { status: 415, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Step 4: Read bytes ─────────────────────────────────────────────────────
    const bodyBuffer = await req.arrayBuffer()
    const bytes      = new Uint8Array(bodyBuffer)

    if (bytes.length === 0) {
      return new Response(
        JSON.stringify({ error: "Empty file received" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Step 5: Heuristic PDF validation ──────────────────────────────────────
    const heuristicResult = await runHeuristicValidation(bytes)

    if (!heuristicResult.valid) {
      console.log(JSON.stringify({
        event: "pdf_heuristic_rejected",
        uid: user.uid,
        reason: heuristicResult.reason,
        sizeBytes: bytes.length,
        ts: new Date().toISOString(),
      }))
      return new Response(
        JSON.stringify({ safe: false, reason: heuristicResult.reason }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Step 6: External AV scan (optional — plug-in point) ───────────────────
    // If AV_SCAN_ENDPOINT is not set, avResult.skipped = true and this is a no-op.
    const avResult = await runExternalAvScan(bytes, heuristicResult.hash)

    if (!avResult.clean) {
      console.log(JSON.stringify({
        event: "pdf_av_rejected",
        uid: user.uid,
        threat: avResult.threat,
        hash: heuristicResult.hash,
        sizeBytes: bytes.length,
        ts: new Date().toISOString(),
      }))
      return new Response(
        JSON.stringify({ safe: false, reason: "File was rejected by the security scanner." }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Audit log ──────────────────────────────────────────────────────────────
    console.log(JSON.stringify({
      event: "pdf_validation_passed",
      uid: user.uid,
      sizeBytes: bytes.length,
      pdfVersion: heuristicResult.pdfVersion,
      pageCount: heuristicResult.pageCount,
      avScanned: !avResult.skipped,
      ts: new Date().toISOString(),
    }))

    return new Response(
      JSON.stringify({
        safe: true,
        hash: heuristicResult.hash,
        pdfVersion: heuristicResult.pdfVersion,
        pageCount: heuristicResult.pageCount,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (err) {
    console.error("[scan-pdf] Unhandled error:", err)
    return new Response(
      JSON.stringify({ error: "An unexpected error occurred" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
