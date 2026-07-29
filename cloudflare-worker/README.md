# MasilPet Cloudflare Worker

This Worker exposes the existing MasilPet callable backend over authenticated
HTTPS while Firebase stays on the Spark plan.

## Required bindings

Plain variables are declared in `wrangler.jsonc`.

The deployed Worker additionally requires these encrypted secrets:

- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `TOUR_API_KEY`

The Firebase credentials should belong to a dedicated service account with the
minimum Firestore data-access role required by this backend. Never commit a
service-account JSON file or `.dev.vars` file.

## Install and validate

The Worker reuses the callable handlers in `../functions/src/index.ts`, so both
Node projects must be installed.

```powershell
npm --prefix functions ci
npm --prefix cloudflare-worker ci
npm --prefix functions run build
npm --prefix cloudflare-worker run check
npm --prefix cloudflare-worker run dry-run
```

## Local development

Create `cloudflare-worker/.dev.vars` locally:

```dotenv
FIREBASE_CLIENT_EMAIL="..."
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
TOUR_API_KEY="..."
```

Then start the Worker:

```powershell
npm --prefix cloudflare-worker run dev
```

Health check:

```text
GET http://127.0.0.1:8787/health
```

## Flutter configuration

Build the app with the deployed Worker URL:

```powershell
flutter build web --release
```

The production Worker URL defaults to
`https://masilpet-api.firstghrn818.workers.dev`. Override it for another
environment with:

```powershell
flutter build web --release --dart-define=MASILPET_API_BASE_URL=https://example.workers.dev
```
