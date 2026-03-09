# Server Union

Unified backend for the Flutter app and the web client.

## What this folder is

`server_union` is the consolidated server that combines the current web backend behavior with Flutter compatibility requirements.

## Run locally

1. Install dependencies:

```bash
cd server_union
npm install
```

2. Prepare environment:

```bash
cp .env.example .env
```

3. Start in development:

```bash
npm run dev
```

4. Health check:

```bash
curl http://localhost:3001/healthz
```

Expected response:

```json
{"ok":true}
```

## Notes

- API base URL: `http://localhost:3001/api`
- In production, set `CLIENT_ORIGINS` and keep `ENFORCE_HTTPS=true`.
- Auth migration mode via `AUTH_MODE`:
  - `firebase` (default): verify Firebase ID tokens only
  - `hybrid`: verify Firebase first, fallback to legacy JWT
  - `jwt`: legacy JWT only
- In Firebase Console, make sure Authentication is initialized (`Build > Authentication > Get started`).
- Firebase auth bridge requires:
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_WEB_API_KEY`
  - one of:
    - `FIREBASE_SERVICE_ACCOUNT_PATH` (recommended for local dev)
    - `FIREBASE_SERVICE_ACCOUNT_JSON`
    - `FIREBASE_SERVICE_ACCOUNT_BASE64`
    - `GOOGLE_APPLICATION_CREDENTIALS`
- Auth responses may include Firebase `refreshToken` and `expiresIn`.
- Session refresh endpoint: `POST /api/auth/session/refresh` with `{ "refreshToken": "..." }`.
- Guest checkout anti-bot protection supports either:
  - Web: reCAPTCHA token (`RECAPTCHA_SECRET` configured)
  - Mobile: Human Proof challenge via `POST /api/human-proof/challenge`
- Configure mobile proof with `HUMAN_PROOF_SECRET`, `HUMAN_PROOF_DIFFICULTY`, `HUMAN_PROOF_CHALLENGE_TTL_MS`, and `HUMAN_PROOF_MAX_NONCE`.
- This folder is independent from `server/` and `new server folder/`.

## Firestore products read rollout (phase 2)

1. Keep `USE_FIRESTORE_PRODUCTS_READS=false` while preparing data.
2. Run one-time migration from MongoDB to Firestore:

```bash
cd server_union
npm run migrate:firestore:products
```

3. Confirm script output includes `"ok": true` and non-zero `productsWritten` / `variantsWritten`.
4. Switch reads to Firestore:

```env
USE_FIRESTORE_PRODUCTS_READS=true
```

5. Restart server and verify these endpoints:
   - `GET /api/products/with-stats`
   - `GET /api/products/facets`
   - `GET /api/products/suggest?q=...`
   - `GET /api/products/:id?withVariants=1`

Rollback:
- Set `USE_FIRESTORE_PRODUCTS_READS=false` and restart server to return reads to Mongo immediately.

## Firestore-only cutover (no Mongo runtime)

The server runtime can run without MongoDB when Firestore data is available.

1. Migrate products/variants:

```bash
cd server_union
npm run migrate:firestore:products
```

2. Migrate core collections (users/orders/discounts/notifications/site settings/site ad/home collections):

```bash
npm run migrate:firestore:core
```

3. Enable Firebase mode in `.env`:

```env
AUTH_MODE=firebase
USE_FIRESTORE_PRODUCTS_READS=true
```

4. Restart server. MongoDB is no longer required for runtime requests.
