import { createClient } from "npm:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-client-platform",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

type GenerateRequest = {
  operation?: string
  prompt?: string
  maxTokens?: number
}

type AuthContext = {
  userId: string | null
  identityKey: string
  isAuthenticated: boolean
}

const encoder = new TextEncoder()

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const startedAt = Date.now()
  let authContext: AuthContext = { userId: null, identityKey: "anonymous", isAuthenticated: false }
  let promptLength = 0
  let cacheKey = ""

  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405)
    }

    const contentLength = Number(req.headers.get("content-length") ?? "0")
    const maxBodyBytes = Number(Deno.env.get("GEMINI_PROXY_MAX_BODY_BYTES") ?? "25000")
    if (contentLength > maxBodyBytes) {
      return json({ error: "Request body too large" }, 413)
    }

    const body = (await req.json()) as GenerateRequest
    const prompt = (body.prompt ?? "").trim()
    const maxTokens = clampNumber(body.maxTokens ?? 400, 32, 2048)
    const operation = (body.operation ?? "generate").trim() || "generate"
    promptLength = prompt.length

    if (!prompt) {
      return json({ error: "Missing prompt" }, 400)
    }

    const maxPromptChars = Number(Deno.env.get("GEMINI_PROXY_MAX_PROMPT_CHARS") ?? "12000")
    if (prompt.length > maxPromptChars) {
      return json({ error: "Prompt too large" }, 413)
    }

    const supabaseUrl = mustEnv("SUPABASE_URL")
    const serviceRoleKey = mustEnv("SUPABASE_SERVICE_ROLE_KEY")
    const geminiApiKey = mustEnv("GEMINI_API_KEY")
    const geminiModel = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash"
    const requireAuth = (Deno.env.get("GEMINI_PROXY_REQUIRE_AUTH") ?? "false").toLowerCase() === "true"
    const cacheTtlSeconds = Number(Deno.env.get("GEMINI_PROXY_CACHE_TTL_SECONDS") ?? "21600")

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    authContext = await resolveAuthContext(req, supabaseUrl, serviceRoleKey)
    if (requireAuth && !authContext.isAuthenticated) {
      return json({ error: "Authentication required" }, 401)
    }

    const anonLimit = Number(Deno.env.get("GEMINI_PROXY_RATE_LIMIT_ANON_PER_HOUR") ?? "30")
    const authLimit = Number(Deno.env.get("GEMINI_PROXY_RATE_LIMIT_AUTH_PER_HOUR") ?? "120")
    const rateLimit = authContext.isAuthenticated ? authLimit : anonLimit
    if (rateLimit > 0) {
      const windowStart = new Date(Date.now() - 60 * 60 * 1000).toISOString()
      const { count, error } = await supabaseAdmin
        .from("ai_request_logs")
        .select("*", { count: "exact", head: true })
        .eq("identity_key", authContext.identityKey)
        .gte("created_at", windowStart)

      if (error) {
        console.error("Failed to read rate limits", error)
      } else if ((count ?? 0) >= rateLimit) {
        await insertLog(supabaseAdmin, {
          user_id: authContext.userId,
          identity_key: authContext.identityKey,
          operation,
          cache_key: null,
          prompt_chars: prompt.length,
          status_code: 429,
          duration_ms: Date.now() - startedAt,
          error_message: "rate_limited",
        })
        return json({ error: "Rate limit exceeded" }, 429)
      }
    }

    cacheKey = await sha256(`${operation}:${maxTokens}:${prompt}`)
    const nowIso = new Date().toISOString()

    if (cacheTtlSeconds > 0) {
      const { data: cachedRow, error: cacheError } = await supabaseAdmin
        .from("ai_response_cache")
        .select("response_text, expires_at")
        .eq("cache_key", cacheKey)
        .gt("expires_at", nowIso)
        .maybeSingle()

      if (cacheError) {
        console.error("Failed to read cache", cacheError)
      } else if (cachedRow?.response_text) {
        await insertLog(supabaseAdmin, {
          user_id: authContext.userId,
          identity_key: authContext.identityKey,
          operation,
          cache_key: cacheKey,
          prompt_chars: prompt.length,
          status_code: 200,
          duration_ms: Date.now() - startedAt,
          error_message: null,
        })
        return json({ text: cachedRow.response_text, cached: true }, 200)
      }
    }

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${geminiApiKey}`
    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          maxOutputTokens: maxTokens,
          temperature: 0.7,
        },
      }),
    })

    const geminiText = await geminiResponse.text()
    if (!geminiResponse.ok) {
      await insertLog(supabaseAdmin, {
        user_id: authContext.userId,
        identity_key: authContext.identityKey,
        operation,
        cache_key: cacheKey,
        prompt_chars: prompt.length,
        status_code: geminiResponse.status,
        duration_ms: Date.now() - startedAt,
        error_message: geminiText.slice(0, 500),
      })
      return json({ error: "Gemini upstream error" }, geminiResponse.status)
    }

    const parsed = JSON.parse(geminiText)
    const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text
    if (typeof text !== "string" || !text.trim()) {
      await insertLog(supabaseAdmin, {
        user_id: authContext.userId,
        identity_key: authContext.identityKey,
        operation,
        cache_key: cacheKey,
        prompt_chars: prompt.length,
        status_code: 502,
        duration_ms: Date.now() - startedAt,
        error_message: "missing_text",
      })
      return json({ error: "Invalid Gemini response" }, 502)
    }

    if (cacheTtlSeconds > 0) {
      const expiresAt = new Date(Date.now() + cacheTtlSeconds * 1000).toISOString()
      const { error: upsertError } = await supabaseAdmin
        .from("ai_response_cache")
        .upsert({
          cache_key: cacheKey,
          operation,
          response_text: text,
          expires_at: expiresAt,
        }, { onConflict: "cache_key" })

      if (upsertError) {
        console.error("Failed to write cache", upsertError)
      }
    }

    await insertLog(supabaseAdmin, {
      user_id: authContext.userId,
      identity_key: authContext.identityKey,
      operation,
      cache_key: cacheKey,
      prompt_chars: prompt.length,
      status_code: 200,
      duration_ms: Date.now() - startedAt,
      error_message: null,
    })

    return json({ text, cached: false }, 200)
  } catch (error) {
    console.error("gemini-proxy failed", error)

    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL")
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
      if (supabaseUrl && serviceRoleKey) {
        const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
          auth: { persistSession: false, autoRefreshToken: false },
        })
        await insertLog(supabaseAdmin, {
          user_id: authContext.userId,
          identity_key: authContext.identityKey,
          operation: "generate",
          cache_key: cacheKey || null,
          prompt_chars: promptLength,
          status_code: 500,
          duration_ms: Date.now() - startedAt,
          error_message: String(error).slice(0, 500),
        })
      }
    } catch (logError) {
      console.error("Failed to log gemini-proxy error", logError)
    }

    return json({ error: "Internal server error" }, 500)
  }
})

async function resolveAuthContext(req: Request, supabaseUrl: string, serviceRoleKey: string): Promise<AuthContext> {
  const authHeader = req.headers.get("authorization") ?? ""
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return anonymousAuthContext(req)
  }

  const token = authHeader.slice("Bearer ".length).trim()
  if (!token) {
    return anonymousAuthContext(req)
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  })

  const { data, error } = await client.auth.getUser(token)
  if (error || !data.user) {
    return anonymousAuthContext(req)
  }

  return {
    userId: data.user.id,
    identityKey: `user:${data.user.id}`,
    isAuthenticated: true,
  }
}

async function anonymousAuthContext(req: Request): Promise<AuthContext> {
  const forwardedFor = req.headers.get("x-forwarded-for") ?? ""
  const ip = forwardedFor.split(",")[0]?.trim() || "unknown"
  const userAgent = req.headers.get("user-agent") ?? "unknown"
  const hash = await sha256(`anon:${ip}:${userAgent}`)
  return {
    userId: null,
    identityKey: `anon:${hash}`,
    isAuthenticated: false,
  }
}

async function insertLog(
  supabaseAdmin: ReturnType<typeof createClient>,
  row: {
    user_id: string | null
    identity_key: string
    operation: string
    cache_key: string | null
    prompt_chars: number
    status_code: number
    duration_ms: number
    error_message: string | null
  },
) {
  const { error } = await supabaseAdmin.from("ai_request_logs").insert(row)
  if (error) {
    console.error("Failed to insert ai_request_logs row", error)
  }
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  })
}

function mustEnv(key: string): string {
  const value = Deno.env.get(key)
  if (!value) throw new Error(`Missing environment variable: ${key}`)
  return value
}

function clampNumber(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}

async function sha256(input: string): Promise<string> {
  const data = encoder.encode(input)
  const digest = await crypto.subtle.digest("SHA-256", data)
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("")
}
