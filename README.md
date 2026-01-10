# Dikori

Dikori is a Flutter storefront app with an Express + MongoDB API. The app
consumes the backend under `/api` and the server includes payments (Lahza),
reCAPTCHA, and optional SMS/email integrations.

## Components

### Flutter app (client)
- Location: `lib/`
- Features: home feed, product list/details, favorites, cart, account, orders.
- Assets: `assets/` and `lib/logo.png` are declared in `pubspec.yaml`.
- API base is configured via `--dart-define=API_BASE=...` (see `lib/config.dart`).

### Server (API)
- Location: `server/`
- Stack: Express + MongoDB, JWT auth, Lahza payments + webhook, reCAPTCHA,
  optional SMS + email.
- Health check: `GET /healthz`.
- Core routes: `/api/auth`, `/api/products`, `/api/orders`, `/api/payments`,
  `/api/discounts`, `/api/notifications`, `/api/contact`,
  `/api/home-collections`, `/api/recaptcha`.

## Project structure
- `lib/` Flutter app code
- `assets/` and `lib/logo.png` static assets/fonts
- `server/` backend API (Express + MongoDB)
- `test/` Flutter tests
- `server/test/` API tests
- `android/`, `ios/`, `web/`, `macos/`, `linux/`, `windows/` platform shells

## Prerequisites
- Flutter SDK (Dart >= 3.10.1 per `pubspec.yaml`)
- Node.js + npm (for `server/`)
- MongoDB instance (for `server/`)
- Optional integrations: Lahza account, reCAPTCHA keys, SMTP credentials,
  SMS provider credentials

## Installation and running

### Server API
```bash
cd server
npm install
```

Create `server/.env` (see below), then:

```bash
npm run dev   # nodemon
# or
npm start
```

### Flutter app
```bash
flutter pub get
```

Run the app and point it at the API:
```bash
flutter run --dart-define=API_BASE=http://localhost:3001/api
```

Build a release:
```bash
flutter build <platform>
```

## Configuration

### Flutter API base
The API base is a compile-time define:
- Default: `http://10.10.10.110:3001/api`
- Override: `--dart-define=API_BASE=http://<host>:3001/api`

### Server environment variables

Required:
- `MONGO_URI` MongoDB connection string
- `JWT_SECRET` at least 32 characters (used for JWT signing)

Common optional:
- `PORT` (default 3001)
- `CLIENT_ORIGINS` comma-separated list for CORS; if unset, localhost is allowed
  in dev
- `PAY_CURRENCY` (default `ILS`)
- `PAYMENT_MINOR_TOLERANCE` (minor units; default 1)
- `LAHZA_SECRET_KEY` for Lahza payments + webhook verification
- `WEBHOOK_IP_WHITELIST` (`true`/`false`, default true)
- `WEBHOOK_ALLOWED_IPS` comma-separated IPs (default set in code)
- `RECAPTCHA_SECRET` reCAPTCHA server secret
- `RECAPTCHA_MIN_SCORE` (default 0.5)
- `RECAPTCHA_TEST_BYPASS` set to `1` to bypass reCAPTCHA in tests/dev
- `RESET_PASSWORD_MAX_ATTEMPTS` (default 5)

Email (contact form):
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`
- `CONTACT_FROM` default `no-reply@yourdomain.com`
- `CONTACT_TO` default `SMTP_USER`

SMS (HTD provider):
- `SEND_SMS_ENABLED` (`true`/`false`, default false)
- `DEV_ECHO_SMS` (`true`/`false`, default true)
- `SMS_HTD_BASE` (or `SMS_BASE`)
- `SMS_HTD_API_STYLE` (`auto`, `simple`, `classic`)
- `SMS_USERNAME` (or `SMS_USER`)
- `SMS_PASSWORD` (or `SMS_PASS` / `SMS_HTD_PASSWORD` / `SMS_HTD_PASS`)
- `SMS_SENDER` (or `SMS_HTD_SENDER`)
- `SMS_HTD_ID` (or `SMS_ID`)
- `SMS_RECIPIENT_FORMAT` (`E164`, `INT`, `LOCAL`)

Example `server/.env`:
```bash
MONGO_URI=mongodb://localhost:27017/dikori
JWT_SECRET=replace-with-32+chars
PORT=3001
CLIENT_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

## Scripts

### Flutter
- `flutter analyze`
- `flutter test`
- `dart format .`

### Server
- `cd server && npm test`
- `cd server && npm run download:images`
- `cd server && npm run export:image-manifests`
