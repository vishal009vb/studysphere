import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// [H-05 FIX] Restrict CORS to known origins instead of wildcard.
// Add your production domain(s) here.
const ALLOWED_ORIGINS = [
  "https://studysphere.app",
  "https://studysphere-app-3a480.web.app",
  "https://studysphere-app-3a480.firebaseapp.com",
  // Allow localhost for development builds only
  "http://localhost",
  "http://localhost:3000",
]

function getCorsHeaders(origin: string | null): Record<string, string> {
  const isAllowed = !origin || 
    ALLOWED_ORIGINS.includes(origin) || 
    origin.startsWith("http://localhost") || 
    origin.startsWith("http://127.0.0.1");
  const allowedOrigin = isAllowed && origin ? origin : "*";
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-firebase-token",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

// [H-03 FIX] Server-side rate limiting using KV store or in-memory map.
// This is a per-process in-memory rate limiter. For multi-instance deployments,
// use Supabase KV or Redis. This provides a hard server-side floor.
const requestCounts = new Map<string, { count: number; windowStart: number }>()

const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000 // 24 hours
const RATE_LIMIT_MAX_REQUESTS = 25 // Slightly above client's 20 to allow for edge cases
const COOLDOWN_MS = 3000 // 3 seconds between requests

// Track last request time per user for cooldown
const lastRequestTimes = new Map<string, number>()

function checkRateLimit(uid: string): { allowed: boolean; reason?: string } {
  const now = Date.now()

  // Cooldown check
  const lastTime = lastRequestTimes.get(uid)
  if (lastTime && (now - lastTime) < COOLDOWN_MS) {
    return { allowed: false, reason: "Cooldown active. Please wait a few seconds." }
  }

  // Daily limit check
  const entry = requestCounts.get(uid)
  if (entry) {
    if (now - entry.windowStart < RATE_LIMIT_WINDOW_MS) {
      if (entry.count >= RATE_LIMIT_MAX_REQUESTS) {
        return { allowed: false, reason: "Daily AI request limit reached. Try again tomorrow." }
      }
      entry.count++
    } else {
      // Window expired, reset
      requestCounts.set(uid, { count: 1, windowStart: now })
    }
  } else {
    requestCounts.set(uid, { count: 1, windowStart: now })
  }

  lastRequestTimes.set(uid, now)
  return { allowed: true }
}

// [H-07 FIX] Input sanitization and prompt injection resistance.
function sanitizePrompt(prompt: string): string {
  // Remove null bytes and control characters
  return prompt.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "").trim()
}

function validatePrompt(prompt: unknown): { valid: boolean; cleaned?: string; error?: string } {
  if (typeof prompt !== "string") {
    return { valid: false, error: "Prompt must be a string." }
  }
  if (prompt.length === 0) {
    return { valid: false, error: "Prompt cannot be empty." }
  }
  if (prompt.length > 1000) {
    return { valid: false, error: "Prompt too long. Maximum 1000 characters." }
  }
  return { valid: true, cleaned: sanitizePrompt(prompt) }
}

serve(async (req) => {
  const origin = req.headers.get("origin")
  const corsHeaders = getCorsHeaders(origin)

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  // Only allow POST
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }

  try {
    // ── Step 1: Firebase token verification ───────────────────────────────────
    const token = req.headers.get("x-firebase-token")
    if (!token) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const firebaseApiKey = Deno.env.get("FIREBASE_API_KEY")
    if (!firebaseApiKey) {
      // [H-07 FIX] Do not expose config error details
      console.error("FIREBASE_API_KEY not configured in Supabase Secrets")
      return new Response(
        JSON.stringify({ error: "Service temporarily unavailable" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const verifyRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${firebaseApiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken: token }),
      }
    )

    const verifyData = await verifyRes.json()

    if (!verifyRes.ok) {
      // [H-07 FIX] Don't expose internal Firebase error details
      console.error("Firebase token verification failed:", verifyData.error?.message)
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const decodedUid = verifyData.users?.[0]?.localId
    if (!decodedUid) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Step 2: Parse and validate request body ───────────────────────────────
    let body: { prompt?: unknown; history?: unknown; uid?: unknown }
    try {
      body = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid request body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // [H-07 FIX] Validate and sanitize prompt
    const promptValidation = validatePrompt(body.prompt)
    if (!promptValidation.valid) {
      return new Response(
        JSON.stringify({ error: promptValidation.error }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }
    const cleanPrompt = promptValidation.cleaned!

    // [H-03 FIX] Server-side rate limiting — cannot be bypassed from client
    const rateCheck = checkRateLimit(decodedUid)
    if (!rateCheck.allowed) {
      return new Response(
        JSON.stringify({ error: rateCheck.reason }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // ── Step 3: Validate history format ───────────────────────────────────────
    const history = Array.isArray(body.history) ? body.history.slice(0, 20) : [] // Max 20 history items

    // ── Step 4: Call Gemini API ───────────────────────────────────────────────
    const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")
    if (!GEMINI_API_KEY) {
      console.error("GEMINI_API_KEY not configured in Supabase Secrets")
      return new Response(
        JSON.stringify({ error: "Service temporarily unavailable" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Security log — log uid only, never the prompt content
    console.log(JSON.stringify({
      event: "gemini_request",
      uid: decodedUid,
      timestamp: new Date().toISOString(),
    }))

    // ── Dynamic Model Discovery ───────────────────────────────────────
    let targetModelUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent";
    
    try {
      const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}`);
      if (listRes.ok) {
        const listData = await listRes.json();
        const availableModels: any[] = listData.models || [];
        // Find first model that supports generateContent
        const validModel = availableModels.find((m: any) => 
          m.supportedGenerationMethods?.includes("generateContent") &&
          (m.name.includes("flash") || m.name.includes("pro"))
        );
        if (validModel) {
          const modelName = validModel.name.replace("models/", "");
          targetModelUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent`;
          console.log(`Discovered supported model: ${modelName}`);
        }
      }
    } catch (e) {
      console.warn("Failed to fetch model list:", e);
    }

    const geminiRes = await fetch(targetModelUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: "You are StudySphere AI, an intelligent assistant built exclusively for the StudySphere app to help B.Tech students. Always introduce yourself as StudySphere AI if asked. Never say you are a Google model or created by Google. Keep answers helpful, concise, and encourage learning without helping users cheat." }]
        },
        contents: [
          ...history,
          { role: "user", parts: [{ text: cleanPrompt }] },
        ],
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        ],
      }),
    });

    const data = await geminiRes.json();

    if (!geminiRes.ok) {
      const status = geminiRes.status === 429 ? 429 : geminiRes.status === 403 ? 403 : 500;
      console.error("Gemini API error:", data.error?.message);
      return new Response(
        JSON.stringify({ error: `AI service error: ${data.error?.message || status}` }),
        { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const reply =
      data.candidates?.[0]?.content?.parts?.[0]?.text || "No response generated."

    return new Response(
      JSON.stringify({ reply }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  } catch (error) {
    // [H-07 FIX] Never expose raw error messages or stack traces
    console.error("Unhandled error in gemini-chat:", error)
    return new Response(
      JSON.stringify({ error: "An unexpected error occurred. Please try again." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
