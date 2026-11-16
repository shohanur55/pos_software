# POS Software

A Flutter POS (Point of Sale) app for uploading and downloading large files — product catalogs, audit exports, media — with background transfer support, real-time progress, and offline resilience.

Works on **Android** and **iOS**.

## Features

- **File upload** — pick any file and upload via multipart POST; runs in the background even when the app is minimised or terminated.
- **File download** — download previously uploaded files with background progress
- **Real-time progress** — percentage, progress bar, speed and ETA on every transfer
- **Pause & resume** — pause/resume downloads; uploads restart if the server doesn't support resuming (see below)
- **Background execution** — transfers continue via WorkManager (Android) / URLSession (iOS)
- **System notifications** — persistent tray notification with live progress; tapping it returns to the relevant screen
- **Offline handling** — transfers auto-pause on connection loss, auto-resume when back online
- **Central dashboard** — one screen listing all transfers with status, accessible from anywhere via a persistent mini-banner
- **Error handling** — user-friendly messages for network issues, server errors, invalid files, with retry options
- **File validation** — checks file type, size (max 512 MB), and empty files before uploading

## Running

**Requirements:** Flutter 3.47+ (Dart 3.13+), Android SDK 37, Xcode (for iOS)

```sh
flutter pub get
dart run build_runner build
flutter run
```

Server URL is in `lib/src/data/services/network/endpoints.dart` — change `Endpoints.baseUrl` to point to your server.

## Issues Found & Fixed

**Upload pause/resume → server limitation**
The server only accepts one complete multipart POST — no resumable upload protocol. When an upload is paused or the connection drops, it has to start over from zero. This is a **server-side limitation**, not an app bug. The app detects this automatically and tells the user on-screen before they pause. If the server ever supports resumable uploads ( S3, etc.), the app will use it without any code change.

**Download pause/resume → works fully**
The server supports HTTP Range requests (`206 Partial Content`). Downloads pause and resume from the exact byte they stopped at, even across app restarts. Verified against the real server.

**Connection loss destroyed partial downloads**
Previously, losing the internet would fail the transfer and lose all progress. Now transfers are parked immediately when the connection drops, keeping the partial file intact. They auto-resume when the connection returns.

**"Online" didn't mean reachable**
`connectivity_plus` only reports if an interface is up — a captive portal or dead router looks like working Wi-Fi. Now every connectivity check includes a server reachability probe. Re-checks every 15 seconds while a link exists but the server is unreachable.

**Expired token on resume**
A download paused overnight would resume with the old token and get a 401. Now the session is re-read and the header refreshed at resume time.

**Upload source file disappeared from cache**
The file picker copies files into the app's cache directory, which Android can purge anytime. Large uploads waiting for Wi-Fi could lose their source file. Now the picked copy is moved to a safe directory (`upload_sources/`) before the upload starts.

**No database migration**
Adding new columns without `onUpgrade` would crash every existing install. Now SQLite migrations run step by step, so devices that skip a version still get the right schema.

**Flapping connection re-sent files endlessly**
A connection dropping and returning repeatedly would restart the same upload each time. Auto-restarts are now capped at 3 per transfer; after that it waits for the user.

**Progress jumped to 0% on resumed uploads**
The native task only reports progress for the remaining bytes. Now progress is rebased onto the full file size, so the bar continues smoothly from where it stopped.

## Working Offline

- File list is cached in **SQLite** — the app opens with real data even without internet, showing "Offline copy" in the sync bar
- Internet checking uses `connectivity_plus` + a server reachability probe — detects captive portals and dead routers
- Transfers auto-pause on connection loss (with reason shown) and auto-resume when back online
- Transfers that were queued offline start automatically when the connection arrives

## Architecture

```
lib/src/
  core/          Result, Failure, DI, config, constants, utils
  domain/        entities, repository contracts, use cases (pure Dart)
  data/          models, repository implementations, services
  presentation/  pages, widgets, blocs, router, theme
```

**Clean Architecture** — `presentation` never imports `data`; they meet only at the DI root. This makes testing easy and swapping implementations straightforward.

**BLoC (flutter_bloc)** — state management for auth, transfers, files, uploads, connectivity. Each transfer tile rebuilds independently via `BlocSelector`.

**`background_downloader`** — handles both uploads and downloads with native background execution, tray notifications, Range-based resume, and tap callbacks. Only one file imports the plugin — swapping it later is isolated.

**SQLite (`sqflite`)** — transfer history and file list survive offline. Progress stays in memory; only status changes hit disk.

**`Result<T, Failure>`** — no exceptions cross layer boundaries. Every error maps to a user-friendly message; no status codes or stack traces reach the screen.

## Transfer Flow (simplified)

```
User action → BLoC → Use Case → Repository → BackgroundTransferService (native)
                                                    ↓
                                              status/progress callbacks
                                                    ↓
                                              SQLite (persist) → BLoC → UI update
```

Each transfer has a stable app-level ID. The native task ID can change on retry/restart — events from replaced tasks are dropped so the dashboard never shows duplicates.

## Android & iOS

| | Android | iOS |
|---|---|---|
| Background | WorkManager foreground service | Background URLSession |
| Downloads folder | `Downloads/POS Software` via MediaStore | `Documents/Downloads` (visible in Files app) |
| Notifications | Full support, needs runtime permission (Android 13+) | Completion/failure only while suspended |
| Upload pause | Pauses (restarts if server can't resume) | Not supported by OS |

**Android platform limits:**
- **9-minute worker limit** — WorkManager kills ordinary workers at ~9 min; transfers run as a foreground service (`dataSync` type) to lift this
- **Doze / battery optimisation** — OEM battery managers (Xiaomi, Samsung, etc.) can still delay or kill foreground services; user may need to exempt the app
- **Force-stop** — cancels all pending work; stale tasks are marked failed after 2 min so they can be retried
- **Scoped storage** — downloads land via MediaStore into `Downloads/POS Software`, no permission needed
- **Notification permission** — required on Android 13+; asked on first transfer with rationale, not at launch; refusing doesn't block transfers

**iOS:** configured with background URLSession and `UIFileSharingEnabled`. Force-quitting from app switcher cancels pending transfers. Progress notifications can't update while suspended (completion/failure still fire).

## What's Not Finished

- **Upload resume** — server limitation; the app is ready, waiting for server-side support
- **HTTPS** — cleartext enabled only because the test server is HTTP; production needs TLS
- **No token refresh** — 24h token with no renewal endpoint; expiry sends user to login
- **Session storage** — currently in SharedPreferences; production should use Keystore/Keychain
- **iOS unverified** — configured but never built or device-tested (no Xcode available)

**With more time:** upload queue for batch imports, checksum verification after download, per-transfer settings (Wi-Fi only, priority), proper migration test suite as schema grows.

## Tests

322 tests, no device needed — `flutter test`

Covers: parsers, validation, formatting, SQLite round-trips, offline fallback, pause/resume behaviour, upload source safety, connectivity probing, resume negotiation, all blocs, notification tap routing, full app flows, and layout at 8 device sizes × 2 text scales with overflow checks.
