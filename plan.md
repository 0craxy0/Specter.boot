# Specter Script Ecosystem Blueprint

## 1. Loader Handshake

- On execution, `Specter.boot` sends a TLS-protected POST through the executor's HTTP utility containing the loader version, nonce, timestamp, installation token, and a privacy-preserving HWID-derived value rather than the raw HWID.
- Include `Authorization` with a short-lived signed token, `Content-Type: application/json`, a client build identifier, and an integrity signature/HMAC covering the request body to resist tampering and replay.

## 2. Server-Side Verification

- Normalize HWID input consistently, then create a keyed hash (such as HMAC-SHA-256 with a server-held pepper) before querying the database; do not store plaintext HWIDs.
- Use constant-time comparisons for secrets and signatures, enforce failed-attempt rate limits, validate timestamp and nonce uniqueness, and return generic authorization errors to avoid enumeration.

## 3. Secure Memory Ingestion

- After verification, the API returns a short-lived, signed, encrypted/obfuscated payload envelope bound to the requesting installation and loader version.
- The client verifies the signature, expiry, audience, and integrity before decrypting in memory and supplying only validated source to `loadstring()`; do not cache payloads locally, clear transient variables where practical, and fail closed on verification errors.
