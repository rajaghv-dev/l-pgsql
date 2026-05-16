# pgcrypto (pgcrypto)

Level: Intermediate
Available locally: Yes

## One-line purpose

Cryptographic functions inside PostgreSQL: password hashing with bcrypt, symmetric and PGP encryption/decryption, and secure random UUID generation.

## Why this exists

Moving cryptographic operations into the database layer removes the risk of application code accidentally logging plaintext secrets, ensures hash consistency regardless of which application instance runs the code, and provides auditable, version-controlled hashing parameters. pgcrypto implements NIST-approved algorithms and the bcrypt/Blowfish KDF (key derivation function) used by most modern password storage standards.

## Install

```sql
-- blocked: Docker not accessible
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT extname, extversion FROM pg_extension WHERE extname = 'pgcrypto';
```

## Core operations

### Password hashing with bcrypt

```sql
-- blocked: Docker not accessible
-- Hash a new password (cost factor 12 is a reasonable default; higher = slower = safer)
SELECT crypt('mysecretpassword', gen_salt('bf', 12));
-- Returns something like: $2a$12$...

-- Store in a table
CREATE TABLE users (
    id       SERIAL PRIMARY KEY,
    email    TEXT UNIQUE NOT NULL,
    pw_hash  TEXT NOT NULL   -- NEVER store plaintext passwords
);

INSERT INTO users (email, pw_hash)
VALUES ('user@example.com', crypt('mysecretpassword', gen_salt('bf', 12)));
```

### Password verification

```sql
-- blocked: Docker not accessible
-- CORRECT: compare hash to hash, never decrypt
SELECT id
FROM users
WHERE email = 'user@example.com'
  AND pw_hash = crypt('input_password', pw_hash);
-- Returns the row if the password matches; empty result if not

-- WRONG (never do this):
-- SELECT pw_hash FROM users ...  -- and compare in application
-- The hash must never leave the database as part of normal auth flow
```

### gen_salt options

| Algorithm | Identifier | Notes |
|-----------|-----------|-------|
| Blowfish (bcrypt) | `'bf'` | Recommended; adaptive cost; default cost = 6, use 10–12 |
| MD5 | `'md5'` | Weak; do not use for new code |
| SHA-256 / DES | `'xdes'`, `'des'` | Legacy; avoid |

```sql
-- blocked: Docker not accessible
SELECT gen_salt('bf', 12);   -- generate a bcrypt salt with cost 12
SELECT gen_salt('bf');        -- cost defaults to 6 — too low for production
```

### Symmetric encryption with pgp_sym

```sql
-- blocked: Docker not accessible
-- Encrypt a value
SELECT pgp_sym_encrypt('sensitive data', 'encryption_key');
-- Returns bytea ciphertext

-- Decrypt
SELECT pgp_sym_decrypt(
    pgp_sym_encrypt('sensitive data', 'encryption_key'),
    'encryption_key'
)::TEXT;
-- Returns: 'sensitive data'

-- Storing encrypted PII
CREATE TABLE profiles (
    id       SERIAL PRIMARY KEY,
    user_id  INT REFERENCES users(id),
    ssn      BYTEA  -- store ciphertext, never plaintext
);

INSERT INTO profiles (user_id, ssn)
VALUES (1, pgp_sym_encrypt('123-45-6789', current_setting('app.encryption_key')));
```

### Secure random bytes and digest

```sql
-- blocked: Docker not accessible
-- Random bytes (cryptographically secure)
SELECT gen_random_bytes(16);   -- 16 bytes of CSPRNG output

-- Digest functions
SELECT digest('hello', 'sha256');   -- bytea
SELECT encode(digest('hello', 'sha256'), 'hex');  -- hex string

-- Supported algorithms: md5, sha1, sha224, sha256, sha384, sha512
-- HMAC
SELECT hmac('message', 'secret_key', 'sha256');
```

### UUID generation (secure)

```sql
-- blocked: Docker not accessible
-- gen_random_uuid() is provided by pgcrypto (and also by core PG 13+)
SELECT gen_random_uuid();
-- Returns a version-4 (random) UUID: e.g., 550e8400-e29b-41d4-a716-446655440000
```

Note: In PostgreSQL 13+, `gen_random_uuid()` is available as a built-in without pgcrypto.

## Performance characteristics

- `crypt('bf', 12)` intentionally slow: ~100–300 ms per hash at cost 12 (by design — prevents brute force)
- Do not use cost factors that make hash verification take > 1s on your hardware; benchmark with `\timing`
- `pgp_sym_encrypt` / `pgp_sym_decrypt`: AES-128 by default; negligible overhead for single-row operations
- `gen_random_uuid()`: microseconds; safe to call in INSERT triggers
- Avoid running bcrypt inside tight loops or batch jobs — schedule off-peak or pipeline through a queue

## When to use

- Storing user passwords: always use `crypt()` + `gen_salt('bf', ≥10)`
- Encrypting PII (SSN, phone, card numbers) at rest: `pgp_sym_encrypt` with a key from Vault/env
- Generating secure tokens or API keys: `encode(gen_random_bytes(32), 'hex')`
- Verifying data integrity: `hmac()` for signed payloads stored in the database
- UUID primary keys: `gen_random_uuid()` when sequential IDs would leak record counts

## When NOT to use

- Full-disk or column-level encryption for the entire database — use PostgreSQL's native TDE or filesystem encryption
- Key management — pgcrypto has no key rotation; pair with HashiCorp Vault, AWS KMS, or similar
- Hashing large files or streams — use application-layer hashing
- MD5 or SHA-1 for passwords — they are not key derivation functions; always use bcrypt (`bf`)
- When you need asymmetric (public/private key) auth — consider application-layer solutions

## Alternatives

| Alternative | When to prefer |
|-------------|---------------|
| `auth.users` in Supabase/GoTrue | Managed user table with bcrypt handled by the platform |
| Application-layer bcrypt (argon2, scrypt) | More algorithm flexibility; better key rotation story |
| HashiCorp Vault transit secrets | Encryption-as-a-service with audit log and key rotation |
| `pgaudit` | Audit logging for who accessed encrypted columns (not available locally) |

## MCP and agent perspective

- **Never log password fields**: agents must explicitly exclude columns named `password`, `pw_hash`, `secret`, `token` from any SELECT * queries used for logging or debugging
- **Verification only**: when checking passwords, use the `crypt(input, stored_hash) = stored_hash` pattern entirely within SQL — the hash must never be returned to the application layer in a login check
- **Key injection**: encryption keys must come from `current_setting('app.encryption_key')` (set per-session by the application) or a Vault sidecar — never hardcoded in agent prompts or SQL strings
- **Audit trail**: if agents write to tables with encrypted columns, log the agent ID, timestamp, and row ID — not the plaintext value

## Ontology connection

- Lives under `extensions/security/` — the security pillar of the extension map
- Connects to: `uuid-ossp` (UUID generation overlap), `pg_stat_statements` (monitor slow bcrypt queries), `sslinfo` (TLS layer security complement)
- Concept map: pgcrypto → password hashing (bcrypt) → KDF cost factors → brute-force resistance

## References

- [PostgreSQL pgcrypto docs](https://www.postgresql.org/docs/16/pgcrypto.html)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [bcrypt cost factor guidance](https://security.stackexchange.com/questions/3959/recommended-of-iterations-when-using-pbkdf2-sha256)
