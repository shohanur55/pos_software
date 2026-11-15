# Background file transfers for a POS terminal

A Flutter module for moving large files on a point-of-sale terminal: product catalogs,
audit exports, media. Uploads and downloads keep running when the cashier switches screens
or minimises the app, they show up in the system tray, they can be paused and picked up
again, and there's one dashboard listing all of them. The terminal also has to stay usable
when the network doesn't cooperate, which shaped most of the decisions below.

## Running it

Flutter 3.47 or newer (Dart 3.13+), Android SDK platform 37, and Xcode if you want to
build for iOS.

```sh
flutter pub get
dart run build_runner build     # Retrofit + dart_mappable
flutter run
```

Accounts are created on the web portal, not in the app — the app only signs in. The login
screen shows the server address as a link; tapping it opens the portal in the device
browser.

The base URL lives in one file and only one file,
`lib/src/data/services/network/endpoints.dart`. Change `Endpoints.baseUrl` and login, the
file list, uploads, downloads and that login-screen link all follow it. If you move the
server to HTTPS, also delete `android:usesCleartextTraffic` from
`android/app/src/main/AndroidManifest.xml` and `NSAllowsArbitraryLoads` from
`ios/Runner/Info.plist`. They are in there purely because the provided server is plain HTTP.

Before trusting a change:

```sh
dart format .
flutter analyze                 # should come back clean
flutter test                    # 243 tests, no device needed
flutter build apk --debug
```

Golden images are committed. After a deliberate design change run
`flutter test --update-goldens` and actually look at the diffs before accepting them.

## How it's put together

```
lib/src/
  core/          Result + Failure, DI, config, constants, utils
  domain/        entities, repository contracts, use cases      (pure Dart)
  data/          models, repository implementations, services
  presentation/  pages, widgets, blocs, router, theme
```

The dependency rule I held to: `presentation` sees `domain` and `core` and nothing else,
`data` the same, and `domain` sees only `core/base`. `presentation` never imports `data`.
The single place the two sides meet is the composition root in `core/di`. That isn't
enforced by a lint — it's enforced by the tests, which mock repository contracts rather
than services, so a shortcut through the layers makes a test impossible to write before it
makes anything else break.

The transfer data flow looks like this in practice:

```
UploadBloc / TransferBloc
  → use case
  → TransferRepositoryImpl
  → BackgroundTransferService     (WorkManager / URLSession)
        |
        | status + progress callbacks, throttled to ~4/s
        ↓
   TransferDao (SQLite)
        |
        ↓
   TransferBloc ← watchTransfers()
        |
        └─ BlocSelector per tile / progress card / mini banner
```

Each transfer has a stable id that we own. The native task id underneath it can change —
on retry, on an upload restart, on a download that can't resume — and events from the
replaced task are dropped. Without that the dashboard grows a duplicate row every time
something is retried.

A few decisions worth explaining:

**`background_downloader` for both directions.** It's the only maintained Flutter plugin I
found that covers uploads *and* downloads with native background execution, tray
notifications with live progress, `Range`-based pause/resume, retries, its own task
database, and tap callbacks. Writing that against raw WorkManager and `URLSession` would
have been most of the assignment by itself. Dio and Retrofit are still there, but only for
the short API calls — login, list, delete.

**Exactly one file imports the plugin.** `BackgroundTransferService` owns it. Everything
above it works with our own `TransferEntity`, so swapping the engine later is a day's work
in one directory rather than a rewrite.

**`Result<T, Failure>` instead of thrown exceptions.** Every repository call returns a
typed outcome and the UI maps `FailureKind` to copy in `ui_messages.dart`. No status code,
no `DioException`, no stack trace ever reaches a cashier.

**SQLite for everything that has to survive.** A POS terminal is offline more often than a
phone is. Transfer history and the last known file list live in `sqflite`, so the app opens
with real content instead of a spinner, and losing the connection changes nothing on screen.
Two tables: `transfers` keyed by our stable id, and `cached_files` with the last confirmed
file list and a `cachedAt` stamp that drives the "Synced 5 min ago / Offline copy" bar.
Progress ticks stay in memory — only status changes hit disk, so a running transfer doesn't
write to SQLite several times a second.

**Upload start lives in `UploadBloc`, not `TransferBloc`.** It needs the transfer id the
repository returns to follow that specific upload's progress. `TransferBloc` learns about
the upload from the repository stream, the same way it learns about anything else.

**Progress is throttled; status isn't.** Progress callbacks can fire many times a second,
so they're capped at roughly 4/s per task. And because native callbacks and user taps both
mutate the same transfer map, every mutation goes through one serialized queue.

## What I found when I tested against the real server

I had an account from the web portal and ran these against the live server from an Android
emulator:

- `GET /get` without a token → `401 {"success": false, "error": "Missing token"}`.
  Good — the error shape is consistent, so the error mapper handles all 401s the same way.
- `POST /token` with wrong credentials → `401`. The app shows "Incorrect username or
  password." and nothing else.
- `POST /token` with valid credentials → `200` with the documented token body. That token
  drove every call after it.
- `POST /upload` with a 60 MB MP4 (multipart field `file`) → accepted, but the server
  renamed the file to `big_video_ef9f35e5.mp4`. That's why the uploaded file name is
  resolved from the response or the refreshed list rather than assumed. If the app trusted
  the name it sent, the Files tab would show a file that doesn't exist on the server.
- `GET /get?file=NAME` → served the 60 MB file. Sent a `Range: bytes=X-` header mid-way
  through and the server honoured it, so download pause/resume works against this server.
- `GET /register` → `405`. Registration is server-rendered only; the app can't do it.

About 25 hours after that login the app landed on the login screen on its own — the 24 h
token had expired and the session check caught it.

## Background execution, and where Android pushes back

The work is handed to the OS, not kept in Dart: WorkManager workers on Android, a
background `URLSession` on iOS. The Flutter isolate can be suspended or killed and the
transfer carries on. On launch and on every resume, `FileDownloader().start()` and
`resumeFromBackground()` replay whatever happened while the app was away, and the
repository reconciles that against the local database.

The Android constraints that actually bit, and what the app does about them:

WorkManager kills an ordinary worker at around nine minutes, which is nothing for a 500 MB
file. Transfers therefore run with `Config.runInForeground`, which promotes them to a
foreground service and lifts the limit; downloads also set `allowPause` so the plugin can
resume across worker cycles. Android 14 wants that service declared, so there's a
`dataSync` entry in the manifest and the matching `FOREGROUND_SERVICE_DATA_SYNC`
permission.

Android 13 and up need a runtime notification permission. The app asks for it on the first
transfer with a one-line rationale, never at launch — asking before the user has done
anything is how you get a permanent denial. Refusing doesn't block transfers; it shows a
dismissible banner explaining that progress won't appear in the status bar.

Doze, App Standby and the OEM battery managers on Xiaomi, Oppo, Huawei and Samsung can
still delay or kill a foreground service. There is no way around that from inside the app,
so it's documented and the user may need to exempt the app from battery optimisation. A
force-stop from system settings cancels all pending work outright; rows whose native task
has been missing for more than two minutes get marked failed so they can be retried, instead
of sitting at 40% forever.

Scoped storage means Android 10+ can't write to a public folder directly. Downloads land
in private app storage and are then moved into `Downloads/POS Software` through MediaStore,
which needs no permission at all. Android 9 and below use the legacy
`WRITE_EXTERNAL_STORAGE` permission capped at `maxSdkVersion=28`; if it's denied the file
stays in private storage and is still openable from inside the app. One other trap: the
cache directory can be purged mid-transfer, so `Config.useCacheDir` is `never` — otherwise
the system can delete a partial download out from under a resume.

On iOS the system schedules background `URLSession` work when it feels like it. Force-
quitting from the app switcher cancels pending transfers. Progress notifications can't update
while the app is suspended (completion and failure still fire). A multipart upload needs
temporary disk space roughly the size of the file. And uploads can't be paused at all.

## Where files actually land

On Android, a download sits in the app's private storage while it's in progress, then
moves to `Downloads/POS Software` through MediaStore when it finishes. The user finds it
in the Files app under Downloads → POS Software. On iOS it goes into `Documents/Downloads`
inside the app; `UIFileSharingEnabled` exposes that folder in Files app → On My iPhone →
POS Software → Downloads.

If a file with the same name is already there, the app adds a suffix: `report (1).csv`,
`report (2).csv`, and so on. Characters that are illegal on either file system are
replaced before the name is used.

The move is idempotent. A completed download is marked `pendingFinalize` before the move
runs, and that flag survives a restart. On every launch and resume the app looks for any
`pendingFinalize` row and tries the move again. If the source file is gone it checks shared
storage first; only if the file can't be found anywhere does the row get marked failed.

## Pause and resume

Download pause is real: the partial file is kept on disk and the resume sends an HTTP
`Range: bytes=X-` request. That holds across app restarts too — the plugin stores the
offset and picks up from there. If the server rejects the range or the partial file is gone,
the download restarts from zero and the app says so: "Couldn't resume. Restarting from the
beginning."

Upload pause is not real, because the API accepts a single multipart `POST` with no chunked
or resumable variant. Pausing cancels the in-flight request and keeps the row with the
local file path; resuming sends the whole file again. The UI says "Upload restarts from the
beginning" under a paused upload rather than pretending otherwise. With a resumable endpoint
— `tus`, S3 multipart — this becomes a real pause.

## Working offline

The file list is cached in SQLite. The Files tab opens with the last list the server
confirmed and a sync bar reading *Syncing…*, *Synced 5 min ago* or *Offline copy*, so an
operator always knows whether what they're looking at is live. A failed refresh keeps the
list on screen and marks it stale rather than blanking the page.

Starting a transfer with no connection still enqueues it; the OS holds it until there's a
network. When the connection comes back the app retries whatever died on the network, once
per outage, and refreshes the list. That retry is capped at one attempt per outage — a
flapping connection can't create a retry loop because a transfer is only eligible again once
it's actually run. A snackbar says which transfer resumed.

Logging out cancels running transfers and clears the local history and file cache so the
next account starts clean. A session *expiry* clears neither, because it's the same user
and they'll want to retry after signing back in.

## The UI

Material 3, light and dark, laid out for phones, tablets and landscape. Bottom navigation
below 840 px, a navigation rail above it, content capped at 720 px wide.

Lists load behind shimmer skeletons rather than spinners, so the screen keeps its shape and
doesn't jump when the data lands. Progress values animate between updates instead of
snapping, with a `Transferred / Speed / Remaining` strip underneath. File types are
colour-coded — catalog green, image blue, video purple — because at a glance that's faster
than reading an extension.

Snackbars carry a tone (info, success, warning, error) that decides the tint, the icon and
how long the message stays. That started as a real bug: a snackbar that leaves
`backgroundColor` to the theme gets Material's `inverseSurface`, while body text defaults
to `onSurface`. Both are dark, so the message is unreadable on screen but looks fine in
code review. Each tone now owns both colours explicitly, and there's a test asserting
WCAG AA contrast for every tone in both themes — the kind of thing that has to be measured,
not eyeballed. The banners (offline status, transfer summary) live in
`Scaffold.bottomNavigationBar` rather than the body, so a floating snackbar is always laid
out above them instead of covering them.

The dashboard has filter chips with counts, a persistent mini banner on every other tab, a
badge in each app bar, and it highlights and scrolls to the right row when you arrive from
a notification tap.

Theme tokens throughout (`context.color`, `context.spacing`, `context.radius`), typography
widgets instead of raw `Text`, every string in `AppStrings`. No localization — the brief
asked for English only — but having the strings centralized means adding it later is
mechanical.

## Tests

`flutter test` runs 243 tests and needs no device.

Unit tests cover the parsers (every documented response shape plus malformed input — the
mock API is loosely specified so the parsers are deliberately tolerant), upload validation,
URL building and encoding, byte and duration formatting, unique and sanitized file names,
status and progress mapping including the plugin's negative sentinel values, and error
mapping.

DAO tests run against an in-memory SQLite: row round-trips, upsert, ordering, bulk delete,
cache replacement inside a transaction, survival across a reopen. Repository tests go one
level up and check the offline-first behaviour end to end — a refresh caches the result, a
failure falls back to the cache, delete and logout leave the cache honest.

Every bloc has `bloc_test` coverage with mocked repositories and real use cases:
`AuthBloc` (session restore, login, logout, the expiry timer), `TransferBloc` (history,
live updates, ordering, derived counters, auto-retry), `UploadBloc`, `FilesBloc`.

Above those, `app_flow_test.dart` drives the real app with mocked repositories through the
flows that matter: offline fallback, recovery on reconnect, the permission prompt, an
oversize file, live progress reaching the banner, a 401 dropping back to login.
`app_layout_test.dart` renders every screen at eight device sizes and two text scales, with
long file names and every transfer state, and fails on overflow. Golden images pin the look
of the transfer tiles, selected-file tiles and skeletons in both themes.

## Trying it on a real device

Create some test files first:

```sh
dd if=/dev/urandom of=test_80mb.mp4 bs=1m count=80
dd if=/dev/zero of=test_600mb.csv bs=1m count=600   # over the 512 MB limit
: > empty.csv
```

Push them to the device (`adb push test_80mb.mp4 /sdcard/Download/`, or AirDrop / Files on
iOS) and then try these scenarios:

Start an upload and switch to another tab — the mini banner should show progress and the
badge should read 1. Minimise the app and check the system notification on Android; it
should keep updating. Reopen and confirm the progress still matches.

Enable airplane mode while a transfer is running. The status should change to "Waiting for
network, retrying..." and after three failed attempts the row should fail with a Retry
button. Disable airplane mode and it should pick up automatically.

Swipe the app away (not force stop), wait a moment, then reopen. The history should be
intact, any completed downloads should be in `Downloads/POS Software`, and running tasks
should still be running.

Pause and resume a download, and then pause it again, restart the app and resume — the
partial file should be kept and the resume should continue from where it left off. Pause
and resume an upload and confirm it shows the restart note and starts from 0%.

Tap a completion notification from the foreground, the background and from a killed app.
A completed upload should open the Files tab; everything else should open Transfers with
the row highlighted.

Log in, then wait 24 hours (or edit the stored token to something expired). Any action
should land you back on the login screen with "Your session has expired."

Try uploading an empty file, a file over 512 MB and a file with an unsupported extension.
All three should show inline validation messages before anything is sent.

For network throttling on the emulator: Extended controls → Cellular → Network type
"EDGE". The speed and ETA in the progress strip should update smoothly. Set text scale to
130% and check that nothing overflows, especially the transfer tiles with long file names.

## What isn't finished

**Pausing an upload restarts it from zero** — covered above, but worth calling out again
because it's the most visible limitation. It's a constraint of the API, not the app.

**It's HTTP, not HTTPS.** Cleartext is enabled on both platforms only because the provided
server is plain HTTP. Production needs TLS and both exemptions gone.

**No token refresh.** The token lasts 24 hours and the API offers no way to renew it, so an
expiry or any 401 sends the user to login. Transfers are kept so they can be retried after
signing in again.

**The session sits in SharedPreferences.** For a real deployment it belongs in the
Keystore/Keychain through `flutter_secure_storage`. It's one small record — that's why it's
not in SQLite — but that's not an argument for leaving it unencrypted.

**iOS is configured but unverified.** Login including the 401 path, a 60 MB upload,
background notifications, notification taps, download, pause and resume, the move into
`Downloads/POS Software`, opening the saved file and the portal link were all exercised on
an Android emulator against the real server. The iOS side is written and configured —
background `URLSession`, SPM, `UIFileSharingEnabled` — but it was never built, because
there's no Xcode on the machine I worked on. I'd want a device run before claiming it
works.

With more time I'd add a resumable upload protocol, an upload queue that batches catalog
imports instead of firing them one at a time, checksum verification after download,
per-transfer settings (Wi-Fi only, priority), a proper migration suite as the schema grows,
and the layout tests wired into CI.
