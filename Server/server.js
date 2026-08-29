// Pickwise API — holds the Anthropic key, meters usage, gates on Polar subscriptions.
// Env: ANTHROPIC_API_KEY (secret), POLAR_ORG_ID, REDIS_URL (optional; in-memory fallback),
//      FREE_LIMIT (default 5), MONTHLY_LIMIT (default 50), PORT.
import http from "node:http";
import Redis from "ioredis";

const PORT = process.env.PORT || 8787;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const POLAR_ORG_ID = process.env.POLAR_ORG_ID || "";
const FREE_LIMIT = Number(process.env.FREE_LIMIT || 5);
const MONTHLY_LIMIT = Number(process.env.MONTHLY_LIMIT || 50);
const MODEL = "claude-opus-5";
if (!ANTHROPIC_API_KEY) { console.error("ANTHROPIC_API_KEY is not set"); process.exit(1); }

// ---- storage: Redis if configured, else in-memory (dev only; resets on restart) ----
const mem = new Map();
const redis = process.env.REDIS_URL ? new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 2 }) : null;
const store = {
  async get(k) { return redis ? Number(await redis.get(k) || 0) : (mem.get(k) || 0); },
  async incr(k, ttlSec) {
    if (redis) { const n = await redis.incr(k); if (n === 1 && ttlSec) await redis.expire(k, ttlSec); return n; }
    const n = (mem.get(k) || 0) + 1; mem.set(k, n); return n;
  },
  async decr(k) { if (redis) return redis.decr(k); mem.set(k, Math.max(0, (mem.get(k) || 0) - 1)); },
};
const month = () => new Date().toISOString().slice(0, 7);
const secondsLeftInMonth = () => { const d = new Date(); return Math.ceil((new Date(d.getFullYear(), d.getMonth() + 1, 1) - d) / 1000); };

// ---- prompt + schema (moved here from the app) ----
const SYSTEM = `You are Pickwise, a brutally practical purchase advisor. The user gives you 2–5 products (names, URLs, pasted specs, or screenshots of product pages). Your job:
1. Identify each product precisely. Use web search to get CURRENT pricing and specs; cite URLs in \`sources\`.
2. Build a comparison table of the criteria that actually matter for this product category (price, key specs, build, ecosystem, warranty, longevity, etc.). Keep cells short. \`values\` must have exactly one entry per product, in the same order the products were given.
3. Give honest pros and cons per product (3–6 each). No marketing fluff.
4. Score each product 0–100 for overall value to a typical buyer.
5. Deliver ONE clear verdict: which product to buy and why, in plain language. Name a runner-up and list caveats (situations where the runner-up wins instead).
Never invent specs. If something is unknown, say "Unknown". Never include affiliate links.`;

const SCHEMA = {
  type: "object", additionalProperties: false,
  required: ["title", "products", "table", "verdict", "sources"],
  properties: {
    title: { type: "string", description: "Short title, e.g. 'iPhone 16 vs Pixel 9'" },
    products: { type: "array", items: { type: "object", additionalProperties: false,
      required: ["name", "summary", "price", "pros", "cons", "score"],
      properties: { name: { type: "string" }, summary: { type: "string" },
        price: { type: "string", description: "Current typical price with currency, or 'Unknown'" },
        pros: { type: "array", items: { type: "string" } }, cons: { type: "array", items: { type: "string" } },
        score: { type: "integer", description: "0–100 overall value score" } } } },
    table: { type: "array", items: { type: "object", additionalProperties: false,
      required: ["criterion", "values", "bestIndex"],
      properties: { criterion: { type: "string" }, values: { type: "array", items: { type: "string" } }, bestIndex: { type: "integer" } } } },
    verdict: { type: "object", additionalProperties: false,
      required: ["winner", "headline", "reasoning", "runnerUp", "caveats"],
      properties: { winner: { type: "string" }, headline: { type: "string", description: "One sentence: 'Go with X.'" },
        reasoning: { type: "string" }, runnerUp: { type: "string" }, caveats: { type: "array", items: { type: "string" } } } },
    sources: { type: "array", items: { type: "string" }, description: "URLs consulted" },
  },
};

// ---- helpers ----
const json = (res, status, body, extra = {}) => {
  res.writeHead(status, { "content-type": "application/json", ...extra });
  res.end(JSON.stringify(body));
};
const readBody = (req, limit = 25 * 1024 * 1024) => new Promise((resolve, reject) => {
  let size = 0; const chunks = [];
  req.on("data", c => { size += c.length; if (size > limit) { reject(new Error("payload too large")); req.destroy(); } else chunks.push(c); });
  req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
  req.on("error", reject);
});

async function polarValidate(key, activationId) {
  const r = await fetch("https://api.polar.sh/v1/customer-portal/license-keys/validate", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ key, organization_id: POLAR_ORG_ID, activation_id: activationId }),
  });
  const body = await r.json().catch(() => ({}));
  return { ok: r.ok && body.status === "granted", status: r.status, body };
}

/// Decide who's calling and whether they have quota. Returns {plan, key, limit, used} or throws {status, code, message}.
async function entitle({ licenseKey, activationId, deviceId }) {
  if (licenseKey) {
    if (!POLAR_ORG_ID) throw { status: 503, code: "licensing_unconfigured", message: "Subscriptions are not configured on the server yet." };
    const v = await polarValidate(licenseKey, activationId);
    if (!v.ok) throw { status: 402, code: "subscription_invalid", message: v.body?.detail || `Subscription key is ${v.body?.status || "invalid"}.` };
    const k = `sub:${v.body.id}:${month()}`;
    return { plan: "pro", key: k, limit: MONTHLY_LIMIT, used: await store.get(k), ttl: secondsLeftInMonth() };
  }
  if (!deviceId || !/^[0-9A-F-]{36}$/i.test(deviceId)) throw { status: 400, code: "bad_device", message: "Missing device id." };
  const k = `free:${deviceId}`;
  return { plan: "free", key: k, limit: FREE_LIMIT, used: await store.get(k), ttl: 0 };
}

async function callAnthropic(content) {
  const body = {
    model: MODEL, max_tokens: 16000, system: SYSTEM, stream: true,
    thinking: { type: "adaptive" },
    output_config: { effort: "high", format: { type: "json_schema", schema: SCHEMA } },
    tools: [{ type: "web_search_20260209", name: "web_search", max_uses: 12 }],
    messages: [{ role: "user", content }],
  };
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "content-type": "application/json", "x-api-key": ANTHROPIC_API_KEY, "anthropic-version": "2023-06-01" },
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    const err = await r.json().catch(() => ({}));
    throw { status: r.status >= 500 || r.status === 529 ? 503 : 502, code: "upstream_error",
            message: err?.error?.message || `Upstream HTTP ${r.status}`, requestId: r.headers.get("request-id") };
  }
  // Consume the SSE stream. Text blocks are accumulated PER BLOCK INDEX — the
  // web-search tool interleaves several text blocks, so "last started block"
  // bookkeeping corrupts the output (fragments like ",Ap]" survive).
  const texts = new Map();   // block index -> accumulated text
  let stopReason = null, buf = "";
  const dec = new TextDecoder();
  for await (const chunk of r.body) {
    buf += dec.decode(chunk, { stream: true });
    let i;
    while ((i = buf.indexOf("\n\n")) >= 0) {
      const frame = buf.slice(0, i); buf = buf.slice(i + 2);
      const line = frame.split("\n").find(l => l.startsWith("data:"));
      if (!line) continue;
      let ev; try { ev = JSON.parse(line.slice(5)); } catch { continue; }
      if (ev.type === "content_block_start" && ev.content_block?.type === "text") texts.set(ev.index, "");
      else if (ev.type === "content_block_delta" && ev.delta?.type === "text_delta" && texts.has(ev.index)) texts.set(ev.index, texts.get(ev.index) + ev.delta.text);
      else if (ev.type === "message_delta") stopReason = ev.delta?.stop_reason || stopReason;
      else if (ev.type === "error") throw { status: 502, code: "upstream_error", message: ev.error?.message || "stream error" };
    }
  }
  if (stopReason === "refusal") throw { status: 422, code: "refused", message: "The model declined this request." };
  if (stopReason === "max_tokens") throw { status: 422, code: "truncated", message: "Response was cut off. Try fewer products or shorter inputs." };
  // The structured-output JSON is the last text block that parses as an object.
  let result = null;
  const ordered = [...texts.entries()].sort((a, b) => a[0] - b[0]).map(([, t]) => t.trim()).filter(Boolean);
  for (const t of ordered.reverse()) {
    try { const p = JSON.parse(t); if (p && typeof p === "object") { result = p; break; } } catch {}
  }
  if (!result) throw { status: 502, code: "bad_json", message: "Couldn't parse the model's response." };
  const n = result.products.length;
  result.products = result.products.map(p => ({ ...p, score: Math.min(100, Math.max(0, p.score | 0)) }));
  result.table = result.table.map(row => {
    let values = row.values.slice(0, n); while (values.length < n) values.push("—");
    return { ...row, values, bestIndex: row.bestIndex >= n ? -1 : row.bestIndex };
  });
  return result;
}

// ---- HTTP ----
const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "GET" && req.url === "/health") return json(res, 200, { ok: true, model: MODEL, redis: !!redis });
    if (req.method === "POST" && req.url === "/v1/compare") {
      let body; try { body = JSON.parse(await readBody(req)); } catch { return json(res, 400, { code: "bad_request", message: "Invalid JSON." }); }
      const { candidates, licenseKey, activationId, deviceId } = body;
      if (!Array.isArray(candidates) || candidates.length < 2 || candidates.length > 5)
        return json(res, 400, { code: "bad_request", message: "Send 2–5 candidates." });

      const ent = await entitle({ licenseKey, activationId, deviceId });
      if (ent.used >= ent.limit)
        return json(res, 402, { code: ent.plan === "free" ? "free_exhausted" : "quota_exhausted", plan: ent.plan,
                                 used: ent.used, limit: ent.limit,
                                 message: ent.plan === "free" ? "You've used your free comparisons." : "You've used this month's comparisons." });

      // Build content blocks.
      const content = [];
      candidates.forEach((c, i) => {
        const t = (c.text || "").trim();
        content.push({ type: "text", text: `Product ${i + 1}:${t ? " " + t : ""}` });
        if (c.imagePNG) content.push({ type: "image", source: { type: "base64", media_type: "image/png", data: c.imagePNG } });
      });
      content.push({ type: "text", text: `Compare these ${candidates.length} products and tell me which one to buy.` });

      // Keep the client connection alive while the model works (can take 30–120s).
      res.writeHead(200, { "content-type": "application/json", "transfer-encoding": "chunked", "cache-control": "no-store" });
      const beat = setInterval(() => res.write(" "), 10000);
      const used = await store.incr(ent.key, ent.ttl);   // charge up front; refund on upstream failure
      try {
        const result = await callAnthropic(content);
        clearInterval(beat);
        res.end(JSON.stringify({ result, plan: ent.plan, used, limit: ent.limit }));
      } catch (e) {
        clearInterval(beat);
        await store.decr(ent.key);
        // Status line already sent: deliver the error in-band.
        res.end(JSON.stringify({ error: { code: e.code || "error", message: e.message || String(e), requestId: e.requestId || null } }));
      }
      return;
    }
    json(res, 404, { code: "not_found" });
  } catch (e) {
    if (e && e.status) return json(res, e.status, { code: e.code, message: e.message });
    console.error(e);
    json(res, 500, { code: "server_error", message: e?.message || "Unexpected error" });
  }
});
server.requestTimeout = 0; server.headersTimeout = 0; server.keepAliveTimeout = 65000;
server.listen(PORT, () => console.log(`pickwise-server on :${PORT} (redis: ${!!redis}, free ${FREE_LIMIT}, monthly ${MONTHLY_LIMIT})`));
