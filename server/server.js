// ============================================================
//  SIKE HUB - Key Server (ban database)
//  Luu tru: Supabase (Postgres) neu co SUPABASE_URL + SUPABASE_KEY,
//           tu dong rớt ve file keys.json neu khong co.
//  Bien moi truong: LINK4M_API, SITE_URL, KEY_TTL_HOURS (48),
//                   ADMIN_KEY, SUPABASE_URL, SUPABASE_KEY
// ============================================================

const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const LINK4M_API = (process.env.LINK4M_API || "").trim();
const SITE_URL = (process.env.SITE_URL || "").trim().replace(/\/$/, "");
const KEY_TTL_HOURS = parseInt(process.env.KEY_TTL_HOURS || "48", 10);
const ADMIN_KEY = (process.env.ADMIN_KEY || "").trim();
const SUPABASE_URL = (process.env.SUPABASE_URL || "").trim().replace(/\/$/, "");
const SUPABASE_KEY = (process.env.SUPABASE_KEY || "").trim(); // dung SERVICE_ROLE key
const USE_DB = !!(SUPABASE_URL && SUPABASE_KEY);
const TOKEN_TTL_MIN = 30;

// ---------- Supabase REST helper ----------
async function sb(path, method = "GET", body = null, prefer = "return=representation") {
  const r = await fetch(`${SUPABASE_URL}/rest/v1${path}`, {
    method,
    headers: {
      "apikey": SUPABASE_KEY,
      "Authorization": `Bearer ${SUPABASE_KEY}`,
      "Content-Type": "application/json",
      "Prefer": prefer,
    },
    body: body ? JSON.stringify(body) : null,
  });
  const txt = await r.text();
  if (!r.ok) {
    const err = new Error(`Supabase ${r.status}: ${txt.slice(0, 200)}`);
    err.status = r.status;
    throw err;
  }
  return txt ? JSON.parse(txt) : null;
}

// ---------- storage: Supabase hoac file ----------
const DB_PATH = path.join(__dirname, "keys.json");
let mem = { keys: {}, pending: {} };
try {
  if (fs.existsSync(DB_PATH)) {
    const raw = JSON.parse(fs.readFileSync(DB_PATH, "utf8"));
    mem.keys = raw.keys || {};
    mem.pending = raw.pending || {};
  }
} catch (e) {
  console.error("[DB] load error:", e.message);
}
function saveFile() {
  try {
    fs.writeFileSync(DB_PATH, JSON.stringify(mem, null, 2));
  } catch (e) {
    console.error("[DB] save error:", e.message);
  }
}

const fromKeyRow = (r) => ({
  hwid: r.hwid, createdAt: r.created_at, expiresAt: r.expires_at,
  maxDevices: r.max_devices == null ? 0 : r.max_devices,
  hwids: Array.isArray(r.hwids) ? r.hwids : [], note: r.note || "",
});
const toKeyRow = (key, v) => ({
  key, hwid: v.hwid, created_at: v.createdAt, expires_at: v.expiresAt,
  max_devices: v.maxDevices == null ? 0 : v.maxDevices,
  hwids: Array.isArray(v.hwids) ? v.hwids : [], note: v.note || "",
});
const fromTokRow = (r) => ({ hwid: r.hwid, createdAt: r.created_at, used: !!r.used });
const toTokRow = (token, v) => ({ token, hwid: v.hwid, created_at: v.createdAt, used: !!v.used });

const store = {
  async getKey(key) {
    if (!USE_DB) return mem.keys[key] || null;
    const rows = await sb(`/sike_keys?key=eq.${encodeURIComponent(key)}&select=*`);
    return rows[0] ? fromKeyRow(rows[0]) : null;
  },
  async setKey(key, v) {
    if (!USE_DB) { mem.keys[key] = v; saveFile(); return; }
    await sb("/sike_keys", "POST", toKeyRow(key, v), "resolution=merge-duplicates,return=representation");
  },
  async insertKey(key, v) { // insert moi, trung PK thi nem loi 409
    if (!USE_DB) {
      if (mem.keys[key]) { const e = new Error("duplicate"); e.status = 409; throw e; }
      mem.keys[key] = v; saveFile(); return;
    }
    await sb("/sike_keys", "POST", toKeyRow(key, v), "return=representation");
  },
  async delKey(key) {
    if (!USE_DB) { delete mem.keys[key]; saveFile(); return; }
    await sb(`/sike_keys?key=eq.${encodeURIComponent(key)}`, "DELETE");
  },
  async allKeys() {
    if (!USE_DB) return Object.entries(mem.keys).map(([key, v]) => ({ key, ...v }));
    const rows = await sb("/sike_keys?select=*&order=created_at.desc&limit=5000");
    return rows.map((r) => ({ key: r.key, ...fromKeyRow(r) }));
  },
  async findValidByHwid(hwid) {
    const now = Date.now();
    if (!USE_DB) {
      for (const [key, v] of Object.entries(mem.keys)) {
        if (v.hwid === hwid && v.expiresAt > now) return { key, expiresAt: v.expiresAt };
      }
      return null;
    }
    const rows = await sb(`/sike_keys?hwid=eq.${encodeURIComponent(hwid)}&select=key,expires_at`);
    for (const r of rows) {
      if (r.expires_at > now) return { key: r.key, expiresAt: r.expires_at };
    }
    return null;
  },
  async getPending(token) {
    if (!USE_DB) return mem.pending[token] || null;
    const rows = await sb(`/sike_pending?token=eq.${encodeURIComponent(token)}&select=*`);
    return rows[0] ? fromTokRow(rows[0]) : null;
  },
  async setPending(token, v) {
    if (!USE_DB) { mem.pending[token] = v; saveFile(); return; }
    await sb("/sike_pending", "POST", toTokRow(token, v), "resolution=merge-duplicates,return=representation");
  },
};

// ---------- helpers ----------
const KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function genKey() {
  const parts = [];
  for (let p = 0; p < 3; p++) {
    let s = "";
    const bytes = crypto.randomBytes(4);
    for (let i = 0; i < 4; i++) s += KEY_ALPHABET[bytes[i] % KEY_ALPHABET.length];
    parts.push(s);
  }
  return "SIKE-" + parts.join("-");
}

async function genUniqueKey() {
  for (let i = 0; i < 5; i++) {
    const k = genKey();
    if (!(await store.getKey(k))) return k;
  }
  return "SIKE-" + Date.now().toString(36).toUpperCase() + "-" + crypto.randomBytes(4).toString("hex").toUpperCase();
}

async function cleanup() {
  const now = Date.now();
  if (!USE_DB) {
    let changed = false;
    for (const [k, v] of Object.entries(mem.keys)) {
      if (v.expiresAt && v.expiresAt <= now) { delete mem.keys[k]; changed = true; }
    }
    for (const [t, v] of Object.entries(mem.pending)) {
      if (v.used || !v.createdAt || now - v.createdAt > TOKEN_TTL_MIN * 60 * 1000) {
        delete mem.pending[t]; changed = true;
      }
    }
    if (changed) saveFile();
    return;
  }
  const cutoff = now - TOKEN_TTL_MIN * 60 * 1000;
  await sb(`/sike_keys?expires_at=gt.0&expires_at=lte.${now}`, "DELETE");
  await sb(`/sike_pending?or=(used.eq.true,created_at.lt.${cutoff})`, "DELETE");
}
setInterval(() => { cleanup().catch((e) => console.error("[cleanup]", e.message)); }, 10 * 60 * 1000);

function validHwid(h) {
  return typeof h === "string" && h.length >= 3 && h.length <= 256 && !/[\s"'<>\\`]/.test(h);
}

const lastLinkAt = {};

// ---------- routes ----------
app.get("/", (req, res) => {
  res.json({ status: "success", service: "SIKE HUB Key Server", storage: USE_DB ? "supabase" : "file", time: new Date().toISOString() });
});

app.get("/api/getlink", async (req, res) => {
  try {
    const hwid = (req.query.hwid || "").toString().trim();
    if (!validHwid(hwid)) return res.json({ status: "error", message: "Thieu HWID hop le." });
    if (!LINK4M_API) return res.json({ status: "error", message: "Server chua cau hinh LINK4M_API." });
    if (!SITE_URL) return res.json({ status: "error", message: "Server chua cau hinh SITE_URL." });

    const now = Date.now();
    if (lastLinkAt[hwid] && now - lastLinkAt[hwid] < 60 * 1000) {
      return res.json({ status: "error", message: "Cho 60s roi lay link moi." });
    }
    lastLinkAt[hwid] = now;

    const token = crypto.randomBytes(16).toString("hex");
    await store.setPending(token, { hwid, createdAt: now, used: false });

    const dest = `${SITE_URL}/getkey.html?hwid=${encodeURIComponent(hwid)}&token=${token}`;
    const r = await fetch("https://link4m.co/api-shorten/v2", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
      },
      body: new URLSearchParams({ api: LINK4M_API, url: dest }).toString(),
    });
    const text = await r.text();
    let data = null;
    try { data = JSON.parse(text); } catch (_) { /* Cloudflare HTML */ }
    if (data && data.status === "success" && data.shortenedUrl) {
      return res.json({ status: "success", link: data.shortenedUrl });
    }
    if (data && data.message) {
      return res.json({ status: "error", message: "Link4m loi: " + data.message });
    }
    return res.json({ status: "error", message: "Link4m chan request (HTTP " + r.status + "). Thu lai sau." });
  } catch (e) {
    console.error("[getlink]", e.message);
    return res.json({ status: "error", message: "Loi server, thu lai sau." });
  }
});

app.get("/api/redeem", async (req, res) => {
  try {
    const hwid = (req.query.hwid || "").toString().trim();
    const token = (req.query.token || "").toString().trim();
    if (!validHwid(hwid) || !/^[a-f0-9]{32}$/.test(token)) {
      return res.json({ status: "error", message: "Link khong hop le. Hay lay link moi trong script." });
    }
    await cleanup();
    const p = await store.getPending(token);
    if (!p || p.used || p.hwid !== hwid) {
      return res.json({ status: "error", message: "Link het han hoac da dung. Hay lay link moi trong script." });
    }

    const old = await store.findValidByHwid(hwid);
    if (old) {
      p.used = true; await store.setPending(token, p);
      return res.json({ status: "success", key: old.key, expiresAt: old.expiresAt, reused: true });
    }

    const key = await genUniqueKey();
    const now = Date.now();
    await store.insertKey(key, { hwid, createdAt: now, expiresAt: now + KEY_TTL_HOURS * 3600 * 1000 });
    p.used = true;
    await store.setPending(token, p);
    const v = await store.getKey(key);
    return res.json({ status: "success", key, expiresAt: v.expiresAt, reused: false });
  } catch (e) {
    console.error("[redeem]", e.message);
    return res.json({ status: "error", message: "Loi server, thu lai sau." });
  }
});

app.get("/api/verify", async (req, res) => {
  try {
    const key = (req.query.key || "").toString().trim().toUpperCase();
    const hwid = (req.query.hwid || "").toString().trim();
    if (!key || !validHwid(hwid)) {
      return res.json({ status: "success", valid: false, reason: "missing" });
    }
    const v = await store.getKey(key);
    if (!v) return res.json({ status: "success", valid: false, reason: "not_found" });
    if (v.hwid !== "*" && v.hwid !== hwid) {
      return res.json({ status: "success", valid: false, reason: "wrong_hwid" });
    }
    if (v.expiresAt && v.expiresAt <= Date.now()) {
      await store.delKey(key);
      return res.json({ status: "success", valid: false, reason: "expired" });
    }
    if (v.hwid === "*") {
      v.hwids = Array.isArray(v.hwids) ? v.hwids : [];
      if (!v.hwids.includes(hwid)) {
        const max = (v.maxDevices == null || v.maxDevices <= 0) ? Infinity : v.maxDevices;
        if (v.hwids.length >= max) {
          return res.json({ status: "success", valid: false, reason: "device_limit" });
        }
        v.hwids.push(hwid);
        await store.setKey(key, v);
      }
    }
    return res.json({ status: "success", valid: true, expiresAt: v.expiresAt });
  } catch (e) {
    console.error("[verify]", e.message);
    return res.json({ status: "success", valid: false, reason: "dberr" });
  }
});

// ---------- ADMIN ----------
function needAdmin(req, res) {
  const a = (req.query.admin || "").toString();
  if (!ADMIN_KEY || a !== ADMIN_KEY) {
    res.json({ status: "error", message: "Sai admin key." });
    return false;
  }
  return true;
}

app.get("/api/admin/create", async (req, res) => {
  try {
    if (!needAdmin(req, res)) return;
    let hours = parseFloat((req.query.hours || "48").toString());
    if (isNaN(hours)) hours = 48;
    hours = Math.max(0, Math.min(hours, 87600));

    let hwid = (req.query.hwid || "*").toString().trim() || "*";
    if (hwid !== "*" && !validHwid(hwid)) {
      return res.json({ status: "error", message: "HWID khong hop le (de trong = moi may)." });
    }

    let max = parseInt((req.query.max || "0").toString(), 10);
    if (isNaN(max) || max < 0) max = 0;
    max = Math.min(max, 1000);

    let key = (req.query.key || "").toString().trim().toUpperCase();
    if (key) {
      if (!/^SIKE-[A-Z0-9-]{1,32}$/.test(key)) {
        return res.json({ status: "error", message: "Key tu chon phai dang SIKE-... (chu/so/gach-ngang)." });
      }
      if (await store.getKey(key)) {
        return res.json({ status: "error", message: "Key da ton tai." });
      }
    } else {
      key = await genUniqueKey();
    }

    const now = Date.now();
    const rec = {
      hwid, createdAt: now,
      expiresAt: hours <= 0 ? 0 : now + hours * 3600 * 1000,
      maxDevices: hwid === "*" ? max : 1,
      hwids: [], note: "admin",
    };
    await store.insertKey(key, rec);
    res.json({ status: "success", key, hwid, hours, maxDevices: rec.maxDevices, expiresAt: rec.expiresAt });
  } catch (e) {
    if (e.status === 409) return res.json({ status: "error", message: "Key da ton tai." });
    console.error("[admin/create]", e.message);
    return res.json({ status: "error", message: "Loi server, thu lai sau." });
  }
});

app.get("/api/admin/revoke", async (req, res) => {
  try {
    if (!needAdmin(req, res)) return;
    const key = (req.query.key || "").toString().trim().toUpperCase();
    if (!key || !(await store.getKey(key))) {
      return res.json({ status: "error", message: "Key khong ton tai." });
    }
    await store.delKey(key);
    res.json({ status: "success", message: "Da xoa key " + key });
  } catch (e) {
    console.error("[admin/revoke]", e.message);
    return res.json({ status: "error", message: "Loi server, thu lai sau." });
  }
});

app.get("/api/admin/reset", async (req, res) => {
  try {
    if (!needAdmin(req, res)) return;
    const key = (req.query.key || "").toString().trim().toUpperCase();
    const v = await store.getKey(key);
    if (!key || !v) {
      return res.json({ status: "error", message: "Key khong ton tai." });
    }
    v.hwids = [];
    await store.setKey(key, v);
    res.json({ status: "success", message: "Da reset so may cua key " + key });
  } catch (e) {
    console.error("[admin/reset]", e.message);
    return res.json({ status: "error", message: "Loi server, thu lai sau." });
  }
});

app.get("/api/admin/list", async (req, res) => {
  try {
    if (!needAdmin(req, res)) return;
    await cleanup();
    const now = Date.now();
    const all = await store.allKeys();
    const out = all.map(({ key, hwid, hwids, maxDevices, expiresAt }) => {
      const used = Array.isArray(hwids) ? hwids.length : (hwid === "*" ? 0 : 1);
      const max = maxDevices == null ? 0 : maxDevices;
      return {
        key, hwid,
        devices: used,
        max: hwid === "*" ? max : 1,
        expiresAt,
        left: !expiresAt ? "vinh vien" : Math.max(0, Math.round((expiresAt - now) / 3600000)) + "h",
      };
    });
    res.json({ status: "success", count: out.length, keys: out });
  } catch (e) {
    console.error("[admin/list]", e.message);
    return res.json({ status: "error", message: "Loi server, thu lai sau." });
  }
});

app.listen(PORT, () => {
  console.log(`[SIKE HUB] Key server chay o port ${PORT} | storage: ${USE_DB ? "supabase" : "file"} | key TTL ${KEY_TTL_HOURS}h`);
  if (!LINK4M_API) console.log("!! Chua co LINK4M_API");
  if (!SITE_URL) console.log("!! Chua co SITE_URL");
  if (!ADMIN_KEY) console.log("!! Chua co ADMIN_KEY - API admin dang TAT");
  if (!USE_DB) console.log("!! Chua co SUPABASE_URL/SUPABASE_KEY - dang dung file tam");
});
