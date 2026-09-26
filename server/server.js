// ============================================================
//  SIKE HUB - Key Server
//  Luong: Script -> /api/getlink -> user vuot link4m ->
//         getkey.html -> /api/redeem (cap key 48h) ->
//         Script -> /api/verify moi lan chay
//  Yeu cau: Node 18+
//  Bien moi truong: LINK4M_API, SITE_URL, KEY_TTL_HOURS (mac dinh 48)
// ============================================================

const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(cors()); // cho phep getkey.html (github pages) goi API
app.use(express.json());

const PORT = process.env.PORT || 3000;
const LINK4M_API = (process.env.LINK4M_API || "").trim();
const SITE_URL = (process.env.SITE_URL || "").trim().replace(/\/$/, ""); // vd: https://tenban.github.io/sikehub (KHONG co / cuoi)
const KEY_TTL_HOURS = parseInt(process.env.KEY_TTL_HOURS || "48", 10);
const TOKEN_TTL_MIN = 30; // link lay-key chi song 30 phut

const DB_PATH = path.join(__dirname, "keys.json");

// ---------- storage (file JSON don gian) ----------
let db = { keys: {}, pending: {} };
try {
  if (fs.existsSync(DB_PATH)) {
    const raw = JSON.parse(fs.readFileSync(DB_PATH, "utf8"));
    db.keys = raw.keys || {};
    db.pending = raw.pending || {};
  }
} catch (e) {
  console.error("[DB] load error:", e.message);
}

function saveDB() {
  try {
    fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
  } catch (e) {
    console.error("[DB] save error:", e.message);
  }
}

// ---------- helpers ----------
const KEY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // bo I,O,0,1 cho de doc

function genKey() {
  for (let attempt = 0; attempt < 20; attempt++) {
    const parts = [];
    for (let p = 0; p < 3; p++) {
      let s = "";
      const bytes = crypto.randomBytes(4);
      for (let i = 0; i < 4; i++) s += KEY_ALPHABET[bytes[i] % KEY_ALPHABET.length];
      parts.push(s);
    }
    const key = "SIKE-" + parts.join("-");
    if (!db.keys[key]) return key; // dam bao KHONG trung
  }
  // fallback (hiem khi xay ra)
  return "SIKE-" + Date.now().toString(36).toUpperCase() + "-" + crypto.randomBytes(4).toString("hex").toUpperCase();
}

function cleanup() {
  const now = Date.now();
  let changed = false;
  for (const [k, v] of Object.entries(db.keys)) {
    if (!v.expiresAt || v.expiresAt <= now) { delete db.keys[k]; changed = true; }
  }
  for (const [t, v] of Object.entries(db.pending)) {
    if (v.used || !v.createdAt || now - v.createdAt > TOKEN_TTL_MIN * 60 * 1000) {
      delete db.pending[t]; changed = true;
    }
  }
  if (changed) saveDB();
}
setInterval(cleanup, 10 * 60 * 1000);

function validHwid(h) {
  return typeof h === "string" && h.length >= 3 && h.length <= 256 && !/[\s"'<>\\`]/.test(h);
}

// chong spam getlink: moi HWID 60s/lan
const lastLinkAt = {};

// ---------- routes ----------
app.get("/", (req, res) => {
  res.json({ status: "success", service: "SIKE HUB Key Server", time: new Date().toISOString() });
});

// B1: Script goi de lay link vuot (da rut gon bang Link4m)
app.get("/api/getlink", async (req, res) => {
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
  db.pending[token] = { hwid, createdAt: now, used: false };
  saveDB();

  const dest = `${SITE_URL}/getkey.html?hwid=${encodeURIComponent(hwid)}&token=${token}`;
  // LUU Y: dung POST form thay vi GET. Cloudflare WAF cua link4m chan
  // tham so `url=` tren query string (403), nhung cho phep POST body.
  try {
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
    return res.json({ status: "error", message: "Khong goi duoc Link4m API." });
  }
});

// B2: Trang getkey.html goi sau khi user vuot link -> cap key 48h theo may
app.get("/api/redeem", (req, res) => {
  const hwid = (req.query.hwid || "").toString().trim();
  const token = (req.query.token || "").toString().trim();
  if (!validHwid(hwid) || !/^[a-f0-9]{32}$/.test(token)) {
    return res.json({ status: "error", message: "Link khong hop le. Hay lay link moi trong script." });
  }
  cleanup();
  const p = db.pending[token];
  if (!p || p.used || p.hwid !== hwid) {
    return res.json({ status: "error", message: "Link het han hoac da dung. Hay lay link moi trong script." });
  }

  // may da co key con han -> tra lai key cu (khong farm key moi)
  for (const [k, v] of Object.entries(db.keys)) {
    if (v.hwid === hwid && v.expiresAt > Date.now()) {
      p.used = true; saveDB();
      return res.json({ status: "success", key: k, expiresAt: v.expiresAt, reused: true });
    }
  }

  const key = genKey();
  const now = Date.now();
  db.keys[key] = { hwid, createdAt: now, expiresAt: now + KEY_TTL_HOURS * 3600 * 1000 };
  p.used = true;
  saveDB();
  return res.json({ status: "success", key, expiresAt: db.keys[key].expiresAt, reused: false });
});

// B3: Script kiem tra key moi lan chay
app.get("/api/verify", (req, res) => {
  const key = (req.query.key || "").toString().trim().toUpperCase();
  const hwid = (req.query.hwid || "").toString().trim();
  if (!key || !validHwid(hwid)) {
    return res.json({ status: "success", valid: false, reason: "missing" });
  }
  const v = db.keys[key];
  if (!v) return res.json({ status: "success", valid: false, reason: "not_found" });
  if (v.hwid !== hwid) return res.json({ status: "success", valid: false, reason: "wrong_hwid" });
  if (v.expiresAt <= Date.now()) {
    delete db.keys[key]; saveDB();
    return res.json({ status: "success", valid: false, reason: "expired" });
  }
  return res.json({ status: "success", valid: true, expiresAt: v.expiresAt });
});

app.listen(PORT, () => {
  console.log(`[SIKE HUB] Key server chay o port ${PORT} | key TTL ${KEY_TTL_HOURS}h`);
  if (!LINK4M_API) console.log("!! Chua co LINK4M_API (bien moi truong)");
  if (!SITE_URL) console.log("!! Chua co SITE_URL (bien moi truong)");
});
