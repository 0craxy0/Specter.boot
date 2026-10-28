"use strict";

const crypto = require("node:crypto");
const path = require("node:path");
const express = require("express");
const { DatabaseSync } = require("node:sqlite");

const required = ["SPECTER_TOKEN_SECRET", "SPECTER_HWID_PEPPER"];
for (const name of required) {
  if (!process.env[name] || process.env[name].length < 32) throw new Error(`${name} must be at least 32 characters`);
}

const PORT = Number(process.env.PORT || 8443);
const DB_PATH = process.env.SPECTER_DB_PATH || path.join(__dirname, "specter.sqlite");
const TOKEN_SECRET = Buffer.from(process.env.SPECTER_TOKEN_SECRET, "utf8");
const HWID_PEPPER = Buffer.from(process.env.SPECTER_HWID_PEPPER, "utf8");
const MAX_SKEW_MS = 60_000;
const NONCE_TTL_MS = 5 * 60_000;
const RATE_WINDOW_MS = 10 * 60_000;
const MAX_FAILURES = 6;

// Specter keeps authorization state local to the verification service.
const specterDb = new DatabaseSync(DB_PATH);
specterDb.exec(`
  PRAGMA journal_mode = WAL;
  PRAGMA foreign_keys = ON;
  CREATE TABLE IF NOT EXISTS installations (
    installation_id TEXT PRIMARY KEY,
    hwid_hash TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    expires_at INTEGER NOT NULL
  ) STRICT;
  CREATE TABLE IF NOT EXISTS used_nonces (
    nonce_hash TEXT PRIMARY KEY,
    expires_at INTEGER NOT NULL
  ) STRICT;
  CREATE TABLE IF NOT EXISTS verification_failures (
    subject TEXT PRIMARY KEY,
    window_started_at INTEGER NOT NULL,
    failures INTEGER NOT NULL
  ) STRICT;
`);

const specterStatements = {
  installation: specterDb.prepare("SELECT hwid_hash, enabled, expires_at FROM installations WHERE installation_id = ?"),
  nonce: specterDb.prepare("SELECT 1 FROM used_nonces WHERE nonce_hash = ? AND expires_at > ?"),
  insertNonce: specterDb.prepare("INSERT INTO used_nonces (nonce_hash, expires_at) VALUES (?, ?)"),
  removeNonces: specterDb.prepare("DELETE FROM used_nonces WHERE expires_at <= ?"),
  failure: specterDb.prepare("SELECT window_started_at, failures FROM verification_failures WHERE subject = ?"),
  replaceFailure: specterDb.prepare("INSERT OR REPLACE INTO verification_failures (subject, window_started_at, failures) VALUES (?, ?, ?)")
};

function digest(value) { return crypto.createHash("sha256").update(value).digest(); }
function hmac(value) { return crypto.createHmac("sha256", TOKEN_SECRET).update(value).digest(); }
function equal(left, right) {
  const a = Buffer.isBuffer(left) ? left : Buffer.from(left);
  const b = Buffer.isBuffer(right) ? right : Buffer.from(right);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
function base64Url(value) { return Buffer.from(value, "base64url"); }
function json(value) { try { return JSON.parse(base64Url(value).toString("utf8")); } catch { return null; } }
function normalizeHwid(value) {
  if (typeof value !== "string") return null;
  const normalized = value.normalize("NFKC").trim().toLowerCase().replace(/\s+/g, "");
  return normalized.length >= 16 && normalized.length <= 512 ? normalized : null;
}
function hashHwid(hwid) { return crypto.createHmac("sha256", HWID_PEPPER).update(hwid, "utf8").digest("hex"); }
function clientIp(request) {
  if (process.env.SPECTER_TRUST_PROXY === "true") return request.get("x-forwarded-for")?.split(",")[0].trim() || "unknown";
  return request.ip || request.socket.remoteAddress || "unknown";
}
function tokenClaims(header) {
  if (typeof header !== "string" || !header.startsWith("Bearer ")) return null;
  const parts = header.slice(7).split(".");
  if (parts.length !== 3 || !/^[A-Za-z0-9_-]+$/.test(parts[0]) || !/^[A-Za-z0-9_-]+$/.test(parts[1])) return null;
  const signed = `${parts[0]}.${parts[1]}`;
  const signature = base64Url(parts[2]);
  if (!equal(signature, hmac(signed))) return null;
  const payload = json(parts[1]);
  const now = Math.floor(Date.now() / 1000);
  if (!payload || payload.aud !== "specter-loader" || typeof payload.sub !== "string" || !Number.isInteger(payload.exp) || payload.exp <= now || payload.exp > now + 900) return null;
  return payload;
}
function limited(subject, now) {
  const entry = specterStatements.failure.get(subject);
  return Boolean(entry && now - entry.window_started_at < RATE_WINDOW_MS && entry.failures >= MAX_FAILURES);
}
function registerFailure(subject, now) {
  const entry = specterStatements.failure.get(subject);
  const current = entry && now - entry.window_started_at < RATE_WINDOW_MS ? entry.failures : 0;
  specterStatements.replaceFailure.run(subject, now, current + 1);
}

const specterApp = express();
specterApp.disable("x-powered-by");
specterApp.set("trust proxy", false);
specterApp.use(express.json({ limit: "8kb", strict: true }));

specterApp.post("/v1/verify", (request, response) => {
  const now = Date.now();
  const subject = digest(clientIp(request)).toString("hex");
  const deny = () => {
    registerFailure(subject, now);
    return response.status(401).json({ authorized: false, error: "authorization_failed" });
  };
  if (limited(subject, now)) return response.status(429).json({ authorized: false, error: "authorization_failed" });

  const claims = tokenClaims(request.get("authorization"));
  const body = request.body || {};
  const timestamp = body.timestamp;
  const hwid = normalizeHwid(body.hwid);
  if (!claims || claims.sub !== body.installationId || typeof body.nonce !== "string" || !/^[A-Za-z0-9_-]{22,128}$/.test(body.nonce) || !Number.isInteger(timestamp) || Math.abs(now - timestamp) > MAX_SKEW_MS || !hwid || typeof body.loaderVersion !== "string" || body.loaderVersion.length > 64) return deny();

  const nonceHash = digest(`${claims.sub}:${body.nonce}`).toString("hex");
  const installation = specterStatements.installation.get(claims.sub);
  if (!installation || installation.enabled !== 1 || installation.expires_at <= now || !equal(installation.hwid_hash, hashHwid(hwid)) || specterStatements.nonce.get(nonceHash, now)) return deny();

  try {
    specterDb.exec("BEGIN IMMEDIATE");
    if (specterStatements.nonce.get(nonceHash, now)) { specterDb.exec("ROLLBACK"); return deny(); }
    specterStatements.removeNonces.run(now);
    specterStatements.insertNonce.run(nonceHash, now + NONCE_TTL_MS);
    specterDb.exec("COMMIT");
  } catch {
    try { specterDb.exec("ROLLBACK"); } catch {}
    return response.status(503).json({ authorized: false, error: "authorization_failed" });
  }
  response.set("Cache-Control", "no-store");
  return response.status(200).json({ authorized: true, installationId: claims.sub, serverTimestamp: now });
});

// Keep malformed-request failures intentionally generic for API compatibility.
specterApp.use((_error, _request, response, _next) => response.status(400).json({ authorized: false, error: "authorization_failed" }));
specterApp.listen(PORT, "127.0.0.1", () => console.log(`Specter verification service listening on ${PORT}`));
