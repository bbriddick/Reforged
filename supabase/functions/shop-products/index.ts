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

async function loadProducts(token: string): Promise<ShopProduct[]> {
  // Account-level tokens need a store id; store-level tokens don't.
  let storeId: number | undefined
  try {
    const stores = await printful("/stores", token)
    if (Array.isArray(stores) && stores.length > 0) {
      const preferred = Deno.env.get("PRINTFUL_STORE_ID")
      storeId = preferred ? Number(preferred) : stores[0].id
    }
  } catch (_) { /* store-level token */ }

  const [list, storefront] = await Promise.all([
    printful("/store/products?limit=100", token, storeId),
    storefrontIndex(),
  ])

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
  if (!token) return json({ error: "Printful token secret is not set" }, 500)
  try {
    const products = await loadProducts(token)
    return json({ storeURL: STORE_URL, products }, 200, 1800)
  } catch (error) {
    console.error(error)
    return json({ error: "Could not load products" }, 502)
  }
})
