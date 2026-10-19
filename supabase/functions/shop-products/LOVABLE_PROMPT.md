# Lovable prompt: fix the wrong shop in `shop-products`

Paste everything below the line into Lovable.

---

Update the existing Supabase Edge Function `shop-products` (do not change its name, secrets or response shape).

Problem: the Reforged iOS app's shop card ("Wear the mission.") shows 3 products from a different Printful store. The real store at https://reforged.printful.me has 12 products (Unashamed tee, die-cut sticker, water bottle, rope cap, sweatshirts, quarter zip, hoodies, crewnecks). The function lists products from the first store the Printful token can see, which is the wrong one.

Fix: treat the public Quick Store (https://reforged.printful.me) as the source of truth. Read its product list from the storefront page first, and only fall back to the Printful API if the storefront can't be read. The API token is then optional, so do not return a 500 when it is missing.

Replace the whole file `supabase/functions/shop-products/index.ts` with the file contents from the repo at `supabase/functions/shop-products/index.ts` (pasted below), then deploy it.

Keep the response exactly: `{ storeURL, products: [{ id, name, price, currency, imageURL, url }] }`, cached 30 minutes at the edge.

After deploying, call the function and confirm it returns 12 products whose `url` values all start with `https://reforged.printful.me/product/`.

```ts
// shop-products — the Reforged Shop catalog for the iOS app.
//
// Keeps the Printful API token on the server (secret PRINTFUL_API_TOKEN) and
// returns a small, read-only product list, so new products appear in the app
// automatically without a release. Checkout happens on the Printful Quick
// Store (physical goods can't use Apple In-App Purchase).
//
// Response: { storeURL, products: [{ id, name, price, currency, imageURL, url }] }
// Cached at the edge for 30 minutes.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-client-platform",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
}

const API = "https://api.printful.com"
const STORE_URL = Deno.env.get("SHOP_STORE_URL") ?? "https://reforged.printful.me"

type ShopProduct = {
  id: string
  name: string
  price: number | null
  currency: string
  imageURL: string | null
  url: string
}

function json(body: unknown, status = 200, cacheSeconds = 0) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...(cacheSeconds > 0 ? { "Cache-Control": `public, max-age=${cacheSeconds}` } : {}),
    },
  })
}

function slugify(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFKD").replace(/[̀-ͯ]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}

async function printful(path: string, token: string, storeId?: number) {
  const headers: Record<string, string> = { Authorization: `Bearer ${token}` }
  if (storeId) headers["X-PF-Store-Id"] = String(storeId)
  const res = await fetch(`${API}${path}`, { headers })
  if (!res.ok) throw new Error(`Printful ${path} → HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`)
  return (await res.json()).result
}

/** Product slugs/links as the public Quick Store publishes them, keyed by
 *  normalized name — used to build exact product-page links. Best effort. */
async function storefrontIndex(): Promise<Map<string, { name: string; slug: string; price?: number; imageURL?: string }>> {
  const index = new Map<string, { name: string; slug: string; price?: number; imageURL?: string }>()
  try {
    const html = await (await fetch(STORE_URL)).text()
    const match = html.match(/data-page="([^"]*)"/)
    if (!match) return index
    const decoded = match[1]
      .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">").replace(/&amp;/g, "&")
    const page = JSON.parse(decoded)
    for (const p of page?.props?.products ?? []) {
      if (p?.name && p?.slug) {
        index.set(slugify(p.name), { name: p.name, slug: p.slug, price: p.min_price, imageURL: p.imageUrl })
      }
    }
  } catch (_) { /* storefront optional */ }
  return index
}

async function loadProducts(token: string | undefined): Promise<ShopProduct[]> {
  const storefront = await storefrontIndex()

  // The public Quick Store IS the Reforged shop. When it can be read, it is the
  // source of truth for what to show: an account-level token can see several
  // Printful stores, and listing the first one returned a different shop's products.
  if (storefront.size > 0) {
    return [...storefront.values()].map((s) => ({
      id: s.slug,
      name: s.name,
      price: s.price ?? null,
      currency: "USD",
      imageURL: s.imageURL ?? null,
      url: `${STORE_URL}/product/${s.slug}`,
    }))
  }

  // Storefront unreadable: fall back to the Printful API.
  if (!token) throw new Error("Storefront unavailable and no Printful token is set")

  // Account-level tokens need a store id; store-level tokens don't.
  let storeId: number | undefined
  try {
    const stores = await printful("/stores", token)
    if (Array.isArray(stores) && stores.length > 0) {
      const preferred = Deno.env.get("PRINTFUL_STORE_ID")
      // Prefer the store whose site or name is Reforged's, not just the first one listed.
      const reforged = stores.find((st: any) =>
        /reforged/i.test(`${st?.name ?? ""} ${st?.website ?? ""}`))
      storeId = preferred ? Number(preferred) : (reforged?.id ?? stores[0].id)
    }
  } catch (_) { /* store-level token */ }

  const list = await printful("/store/products?limit=100", token, storeId)

  const products = await Promise.all((list ?? []).map(async (p: any): Promise<ShopProduct | null> => {
    if (p.is_ignored) return null
    let price: number | null = null
    let currency = "USD"
    try {
      const detail = await printful(`/store/products/${p.id}`, token, storeId)
      const prices = (detail?.sync_variants ?? [])
        .filter((v: any) => !v.is_ignored)
        .map((v: any) => { currency = v.currency ?? currency; return Number(v.retail_price) })
        .filter((n: number) => Number.isFinite(n) && n > 0)
      if (prices.length) price = Math.min(...prices)
    } catch (_) { /* keep list data */ }

    const key = slugify(p.name ?? "")
    const fromStore = storefront.get(key)
    return {
      id: String(p.id),
      name: p.name ?? "Product",
      // The Quick Store's own price is what customers pay at checkout; the
      // API's retail_price can differ from it, so prefer the store's.
      price: fromStore?.price ?? price ?? null,
      currency,
      // Store mockups (on a model or product photo) read better than the
      // API's flat design previews (e.g. a white sticker on white).
      imageURL: fromStore?.imageURL ?? p.thumbnail_url ?? null,
      url: `${STORE_URL}/product/${fromStore?.slug ?? key}`,
    }
  }))

  const fromAPI = products.filter((p): p is ShopProduct => p !== null)
  if (fromAPI.length > 0) return fromAPI

  // Quick Store items that the API doesn't list: fall back to the storefront.
  return [...storefront.values()].map((s) => ({
    id: s.slug,
    name: s.name,
    price: s.price ?? null,
    currency: "USD",
    imageURL: s.imageURL ?? null,
    url: `${STORE_URL}/product/${s.slug}`,
  }))
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  // Accept the common secret names so an existing secret works as-is.
  const token = ["PRINTFUL_IOS_API_KEY", "PRINTFUL_API_TOKEN", "PRINTFUL_API_KEY"]
    .map((name) => Deno.env.get(name))
    .find((value) => value && value.length > 0)
  // The token is only needed if the public storefront can't be read.
  try {
    const products = await loadProducts(token)
    return json({ storeURL: STORE_URL, products }, 200, 1800)
  } catch (error) {
    console.error(error)
    return json({ error: "Could not load products" }, 502)
  }
})
```
