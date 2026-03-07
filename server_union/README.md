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
- This folder is independent from `server/` and `new server folder/`.
