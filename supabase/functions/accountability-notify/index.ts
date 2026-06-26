// Accountability partner notifier for Reforged's Focus & Purity Shield.
//
// The iOS app POSTs here whenever the user attempts to LOWER their protection
// (toggle a block off, change the app picker, or remove the accountability lock).
// This function emails (Resend) or texts (Twilio) the partner the user designated.
//
// Deploy:  supabase functions deploy accountability-notify
// Secrets (set with `supabase secrets set ...`):
//   RESEND_API_KEY        - for email (https://resend.com)
//   RESEND_FROM           - e.g. "Reforged <accountability@yourdomain.com>"
//   TWILIO_ACCOUNT_SID    - for SMS (https://twilio.com)
//   TWILIO_AUTH_TOKEN
//   TWILIO_FROM           - your Twilio phone number, e.g. "+15551234567"
//
// The app sends: { contact, channel: "email"|"sms", reason, appName, timestamp }

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-client-platform",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

type NotifyRequest = {
  contact?: string
  channel?: "email" | "sms"
  reason?: string
  appName?: string
  timestamp?: string
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405)
    }

    const body = (await req.json()) as NotifyRequest
    const contact = (body.contact ?? "").trim()
    const channel = body.channel === "sms" ? "sms" : "email"
    const reason = (body.reason ?? "tried to lower their protection").trim()
    const appName = (body.appName ?? "Reforged").trim()

    if (!contact) {
      return json({ error: "Missing contact" }, 400)
    }

    const when = formatWhen(body.timestamp)
    const message =
      `${appName} accountability alert: your partner ${reason} on ${when}. ` +
      `This is a friendly nudge to check in with them.`

    if (channel === "email") {
      await sendEmail(contact, `${appName} accountability alert`, message)
    } else {
      await sendSMS(contact, message)
    }

    return json({ ok: true }, 200)
  } catch (error) {
    console.error("accountability-notify failed", error)
    return json({ error: "Internal server error" }, 500)
  }
})

async function sendEmail(to: string, subject: string, text: string) {
  const apiKey = mustEnv("RESEND_API_KEY")
  const from = mustEnv("RESEND_FROM")

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to: [to], subject, text }),
  })

  if (!res.ok) {
    const detail = await res.text()
    throw new Error(`Resend error ${res.status}: ${detail.slice(0, 300)}`)
  }
}

async function sendSMS(to: string, body: string) {
  const sid = mustEnv("TWILIO_ACCOUNT_SID")
  const token = mustEnv("TWILIO_AUTH_TOKEN")
  const from = mustEnv("TWILIO_FROM")

  const params = new URLSearchParams({ To: to, From: from, Body: body })
  const res = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${sid}:${token}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params,
    },
  )

  if (!res.ok) {
    const detail = await res.text()
    throw new Error(`Twilio error ${res.status}: ${detail.slice(0, 300)}`)
  }
}

function formatWhen(iso?: string): string {
  if (!iso) return "just now"
  const date = new Date(iso)
  if (isNaN(date.getTime())) return "just now"
  return date.toLocaleString("en-US", { dateStyle: "medium", timeStyle: "short" })
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function mustEnv(key: string): string {
  const value = Deno.env.get(key)
  if (!value) throw new Error(`Missing environment variable: ${key}`)
  return value
}
