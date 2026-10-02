# Slip

Receipt tracker for India: scan a bill, check the merchant, date, total,
GST split and category, save it. Budgets, GST summaries and insights come
from the receipts. Android, built with Flutter; data stays on the phone.

## Download

**[Download Slip Free](https://github.com/ish-codes-magic/expense-tracker/releases/latest)**
for Android: open the link on your phone, download the APK and tap it. Android
asks once to allow installing from your browser.

## Two editions

| APK | App name | What it does |
|---|---|---|
| `Slip-AI-<version>.apk` | Slip | Reads receipts with a cheap AI model via the reader in `worker/`, with on-phone reading as fallback |
| `Slip-Free-<version>.apk` | Slip Free | Keeps the photo; every field is typed in by hand; nothing leaves the phone |

Both can be installed on one phone at the same time. Only Slip Free is
published here: the AI edition contains the app token for a private reader,
so it is built and shared privately.

## Building

Needs Flutter and the Android SDK. `app/secrets.json` (see
`app/secrets.example.json`) holds the reader's address and app token for
the AI edition; it is git-ignored. Release APKs are signed with the key
named in `app/android/key.properties` (also git-ignored); without that file
they are signed with the debug key and cannot update a published install.

```
powershell -File tool\Build-Apks.ps1      # both editions -> dist/
cd app && flutter test                    # app tests
cd worker && npm test                     # reader tests
```

Running on a phone during development needs a flavor:
`flutter run --flavor ai --dart-define-from-file=secrets.json` or
`flutter run --flavor free --dart-define=SLIP_EDITION=free`.

## The reader (`worker/`)

A Cloudflare Worker that holds the OpenRouter key. The app posts a photo;
the Worker asks a vision model for the receipt's fields, checks them and
returns them. `GET /usage` reports what it has spent. Deploy with
`npx wrangler deploy`; secrets with `npx wrangler secret put`.

## License

MIT
