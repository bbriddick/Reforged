# Supabase Gemini Proxy

This repo includes a Supabase Edge Function that keeps the Gemini API key on the server:

- `supabase/functions/gemini-proxy/index.ts`
- `supabase/migrations/20260423130500_create_gemini_proxy_tables.sql`

## What it does

- Reads `GEMINI_API_KEY` from Supabase secrets
- Validates an incoming Supabase JWT when present
- Supports anonymous fallback with IP/user-agent based rate limiting
- Enforces request body and prompt size limits
- Logs requests to `public.ai_request_logs`
- Caches identical responses in `public.ai_response_cache`

## Required Supabase secrets

Set these before deploying:

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_key
supabase secrets set GEMINI_PROXY_REQUIRE_AUTH=false
supabase secrets set GEMINI_PROXY_RATE_LIMIT_ANON_PER_HOUR=30
supabase secrets set GEMINI_PROXY_RATE_LIMIT_AUTH_PER_HOUR=120
supabase secrets set GEMINI_PROXY_MAX_BODY_BYTES=25000
supabase secrets set GEMINI_PROXY_MAX_PROMPT_CHARS=12000
supabase secrets set GEMINI_PROXY_CACHE_TTL_SECONDS=21600
supabase secrets set GEMINI_MODEL=gemini-2.5-flash
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically in Supabase Edge Functions.

## Deploy

```bash
supabase db push
supabase functions deploy gemini-proxy
```

## iOS app config

Add your public Supabase values to `Reforged/Info.plist`:

- `SupabaseURL`
- `SupabaseAnonKey`
- `SupabaseGeminiFunctionName` (defaults to `gemini-proxy`)

These are safe to bundle in the app. The Gemini secret is not.

## Auth notes

The function will validate a Supabase JWT when the app sends one in the `Authorization` header.

Right now the iOS app invokes the function with the public anon key, which is enough for secure secret handling, caching, and rate limiting, but not enough for per-user authenticated enforcement.

If you later add Supabase Auth to the app, the function is already structured to use authenticated user IDs for stronger limits and auditing.
