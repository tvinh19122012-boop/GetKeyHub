// ============================================================
//  SIKE HUB - Key Server
//  Luong: Script -> /api/getlink -> user vuot link4m ->
//         getkey.html -> /api/redeem (cap key 48h) ->
//         Script -> /api/verify moi lan chay
//  Admin: /api/admin/create|revoke|reset|list (can ADMIN_KEY)
//  Yeu cau: Node 18+
//  Bien moi truong: LINK4M_API, SITE_URL, KEY_TTL_HOURS (48), ADMIN_KEY
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
const ADMIN_KEY = (process.env.ADMIN_KEY || "").trim(); // key admin tu dat, vd: sike-admin-xxxx
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
    // expiresAt = 0 nghia la VINH VIEN -> khong xoa
    if (v.expiresAt && v.expiresAt <= now) { delete db.keys[k]; changed = true; }
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
  // key khoa cung theo 1 may (key vuot link)
  if (v.hwid !== "*" && v.hwid !== hwid) {
    return res.json({ status: "success", valid: false, reason: "wrong_hwid" });
  }
  if (v.expiresAt && v.expiresAt <= Date.now()) {
    delete db.keys[key]; saveDB();
    return res.json({ status: "success", valid: false, reason: "expired" });
  }
  // key nhieu may: dem may den truoc phuc vu truoc, du slot thi chan
  if (v.hwid === "*") {
    if (!Array.isArray(v.hwids)) v.hwids = [];
    if (!v.hwids.includes(hwid)) {
      const max = (v.maxDevices == null || v.maxDevices <= 0) ? Infinity : v.maxDevices;
      if (v.hwids.length >= max) {
        return res.json({ status: "success", valid: false, reason: "device_limit" });
      }
      v.hwids.push(hwid);
      saveDB();
    }
  }
  return res.json({ status: "success", valid: true, expiresAt: v.expiresAt });
});

// ---------- ADMIN (can ADMIN_KEY) ----------
function needAdmin(req, res) {
  const a = (req.query.admin || "").toString();
  if (!ADMIN_KEY || a !== ADMIN_KEY) {
    res.json({ status: "error", message: "Sai admin key." });
    return false;
  }
  return true;
}

// Tao key tay: ?admin=SECRET&hours=168&hwid=*&max=3&key=SIKE-TU-CHON
//   hours: so gio (0 = VINH VIEN, max 87600 = 10 nam), mac dinh 48
//   hwid: khoa theo may, de trong/* = moi may dung duoc
//   max: so may toi da (chi ap dung khi hwid=*; 0 = khong gioi han)
//   key: tu dat ten (dang SIKE-...), de trong = tu tao ngau nhien
app.get("/api/admin/create", (req, res) => {
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
  max = Math.min(max, 1000); // 0 = khong gioi han

  let key = (req.query.key || "").toString().trim().toUpperCase();
  if (key) {
    if (!/^SIKE-[A-Z0-9-]{1,32}$/.test(key)) {
      return res.json({ status: "error", message: "Key tu chon phai dang SIKE-... (chu/so/gach-ngang)." });
    }
    if (db.keys[key]) {
      return res.json({ status: "error", message: "Key da ton tai." });
    }
  } else {
    key = genKey();
  }

  const now = Date.now();
  db.keys[key] = {
    hwid,
    createdAt: now,
    expiresAt: hours <= 0 ? 0 : now + hours * 3600 * 1000, // 0 = vinh vien
    maxDevices: hwid === "*" ? max : 1,
    hwids: [],
    note: "admin",
  };
  saveDB();
  res.json({ status: "success", key, hwid, hours, maxDevices: db.keys[key].maxDevices, expiresAt: db.keys[key].expiresAt });
});

// Xoa key: ?admin=SECRET&key=SIKE-XXXX
app.get("/api/admin/revoke", (req, res) => {
  if (!needAdmin(req, res)) return;
  const key = (req.query.key || "").toString().trim().toUpperCase();
  if (!key || !db.keys[key]) {
    return res.json({ status: "error", message: "Key khong ton tai." });
  }
  delete db.keys[key]; saveDB();
  res.json({ status: "success", message: "Da xoa key " + key });
});

// Reset danh sach may cua key (khi doi may / het slot): ?admin=SECRET&key=SIKE-XXXX
app.get("/api/admin/reset", (req, res) => {
  if (!needAdmin(req, res)) return;
  const key = (req.query.key || "").toString().trim().toUpperCase();
  const v = db.keys[key];
  if (!key || !v) {
    return res.json({ status: "error", message: "Key khong ton tai." });
  }
  v.hwids = []; saveDB();
  res.json({ status: "success", message: "Da reset so may cua key " + key });
});

// Xem tat ca key: ?admin=SECRET
app.get("/api/admin/list", (req, res) => {
  if (!needAdmin(req, res)) return;
  cleanup();
  const now = Date.now();
  const out = Object.entries(db.keys).map(([key, v]) => {
    const used = Array.isArray(v.hwids) ? v.hwids.length : (v.hwid === "*" ? 0 : 1);
    const max = v.maxDevices == null ? 0 : v.maxDevices;
    return {
      key,
      hwid: v.hwid,
      devices: used,
      max: v.hwid === "*" ? max : 1,
      expiresAt: v.expiresAt,
      left: !v.expiresAt ? "vinh vien" : Math.max(0, Math.round((v.expiresAt - now) / 3600000)) + "h",
    };
  });
  res.json({ status: "success", count: out.length, keys: out });
});

app.listen(PORT, () => {
  console.log(`[SIKE HUB] Key server chay o port ${PORT} | key TTL ${KEY_TTL_HOURS}h`);
  if (!LINK4M_API) console.log("!! Chua co LINK4M_API (bien moi truong)");
  if (!SITE_URL) console.log("!! Chua co SITE_URL (bien moi truong)");
  if (!ADMIN_KEY) console.log("!! Chua co ADMIN_KEY (bien moi truong) - API admin dang TAT");
});
