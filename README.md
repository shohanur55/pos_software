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
flutter test                    # 285 tests, no device needed
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

**The repository watches the connection, not the UI.** Parking transfers when the route
disappears has to happen whether or not anyone is looking at the Transfers tab, so
`TransferRepositoryImpl` holds the subscription itself. `ConnectivityCubit` still exists,
but only to draw the offline banner. The repository also owns the one thing that makes
that safe: all of it goes through the same serialized queue as native events and user
taps, so a park, a resume and a progress tick can never interleave halfway through.

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
- The upload size cap is the server's, and it's close to ours. Sending just a
  `Content-Length` header (nginx rejects on the header, before reading a body) and
  bisecting: `512 MB` → `100 Continue`, `600 MB` → `413`, boundary at roughly **520 MiB**.
  The app's own 512 MiB limit sits just under it, so a file that passes validation is one
  the server will accept — multipart overhead included. What this can't tell you is PHP's
  `upload_max_filesize`, which sits behind nginx and could be lower; a 60 MB upload is the
  largest I've actually confirmed end to end.
- `POST /upload` with `Content-Range: bytes */<size>` and an empty body → not a `308`.
  The endpoint has no resumable variant, which is what the upload resume probe exists to
  find out and what it caches. `OPTIONS /upload` → `204`, which is what the reachability
  probe uses: small, unauthenticated, and it proves the route without touching any data.

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

Uploads have a working folder of their own. The file picker returns a copy it made in the
app's cache directory, which the OS may purge at any time, so that copy is moved into
`<app support>/upload_sources/` before the task starts and deleted once the upload
finishes. A file the operator picked from their own storage is never moved — only the
picker's copy of it is.

The move is idempotent. A completed download is marked `pendingFinalize` before the move
runs, and that flag survives a restart. On every launch and resume the app looks for any
`pendingFinalize` row and tries the move again. If the source file is gone it checks shared
storage first; only if the file can't be found anywhere does the row get marked failed.

## Pause and resume

This is the part that matters most for a 500 MB catalog over shop Wi-Fi, so it is worth
being precise about what survives an interruption and what doesn't.

**Downloads continue from the byte they stopped at.** The partial file stays on disk and
the resume sends `Range: bytes=X-`. That holds across app restarts: the plugin keeps the
offset, and the app re-reads the token before resuming, because a download can sit paused
for longer than a 24-hour token lives — resuming with the header the task was created with
collects a 401 that looks like a resume failure and isn't one. If the server refuses the
range or the partial file is gone, the download starts over and says so.

**Uploads continue from their offset when the endpoint can take one, and say so plainly
when it can't.** Asking a server how much of an interrupted upload it still holds is the
same question in every resumable protocol: send the upload's identity with
`Content-Range: bytes */<total>` and an empty body, and a server that supports resuming
answers `308` with a `Range: bytes=0-<last>` header. `UploadResumeProbe` asks exactly that.
On a yes, the resume sends only the bytes after the offset as a raw body with
`Content-Range` set, and the progress bar carries on from where it was instead of snapping
back to zero. On a no, the upload restarts and the operator is told why — "This server
can't continue an interrupted upload, so it starts again from the beginning."

The endpoint this ships against answers no: `POST /upload` is a single multipart form with
no resumable variant, and there is no second endpoint to negotiate with. So in practice,
today, a paused upload does restart. What changed is that the app now *knows* that rather
than assuming it, it says so before the operator commits to waiting, and pointing
`Endpoints.baseUrl` at something that speaks the convention — tus, S3 multipart, Google's
resumable protocol — turns real upload resume on with no other change. The verdict is
cached per server, so an endpoint that has already said no is never asked again, and
uploads smaller than 8 MB skip the question entirely because re-sending them costs less
than the round trip.

A paused transfer always states what resuming will cost, while it is still paused and the
decision is still open: *"Continues from 412.6 MB when resumed"* or *"Starts again from the
beginning when resumed"*. That sentence is the whole point — an operator deciding whether
to wait for the shop Wi-Fi or carry the terminal to the back office needs to know whether
the 412 MB already sent survives the wait.

One more case the probe made visible: if the last bytes land and the connection dies before
the response arrives, the server holds the whole file. Resending it would leave a duplicate.
When the offset comes back equal to the file size the app marks the upload complete and
resolves the stored name from the file list instead.

## Losing the connection

Letting a native task spend its three retries against a dead network and then fail is the
wrong behaviour: it throws away a partial download and tells the operator nothing useful.
So the repository watches connectivity itself. When the route to the server goes away,
every running transfer is parked:

- A running download pauses in place — partial file and offset intact.
- Everything else (an upload, a queued task, a download whose server refuses ranges) has
  its native task stopped, and the row keeps its byte count.

Either way the row records *why* it stopped, and that reason is on screen: the status chip
reads **Waiting for internet** rather than **Paused**, the detail line reads *"No internet.
Continues from 412.6 MB as soon as the connection is back"*, and a snackbar says the
connection was lost. When the connection returns the app starts them again by itself,
oldest first, and says where each one picked up from.

A transfer the operator paused by hand is left alone. That was a decision, not an accident,
and the app does not overrule it.

Two guards sit around that loop. Parking and resuming run on one queue, so a connection
that drops and comes back while the parking is half done can't leave transfers parked with
nothing coming to start them. And a transfer that has to re-send the whole file is
restarted automatically at most three times — a flapping shop connection would otherwise
push the same 400 MB up the line all afternoon. Past that the row stays parked and waits
for a person. Transfers that keep their place aren't capped, because resuming them costs
nothing.

## Working offline

The file list is cached in SQLite. The Files tab opens with the last list the server
confirmed and a sync bar reading *Syncing…*, *Synced 5 min ago* or *Offline copy*, so an
operator always knows whether what they're looking at is live. A failed refresh keeps the
list on screen and marks it stale rather than blanking the page.

Starting a transfer with no connection still enqueues it; the OS holds it until there's a
network. Transfers that were already running are parked and started again, as described
above. Transfers that failed on the network before the app could park them are retried
once per outage — a transfer only becomes eligible again once it has actually run, so a
flapping connection can't create a retry loop. A snackbar says which transfer resumed.

"Online" here means *the server can be reached*, not *an interface is up*. `connectivity_plus`
only reports the second, and a terminal joined to a cafe hotspot behind a captive portal,
or to a shop router whose uplink is down, reports Wi-Fi and is unreachable. Acting on that
alone made the app announce "back online" and burn its one automatic retry against a dead
route. Every connectivity verdict now goes through a cheap `OPTIONS` probe against the
server — any HTTP answer, including 401 or 405, proves the route works; only a transport
failure counts as offline. And because a captive portal being signed in produces no further
platform event, a link that's up with nothing behind it is re-probed every 15 seconds until
it comes back.

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

## What broke when I thought about a real counter

Most of these only appear once you stop testing on a desk with good Wi-Fi. They're listed
because each one changed the code, and because the reasoning is the interesting part.

**A dropped connection destroyed a partial download.** The native task spent its three
retries against a dead network, failed, and the bytes went with it. An operator who was
380 MB into a catalog got a Retry button and nothing else. Parking the transfer the moment
the route disappears keeps the file and the offset, and costs nothing when the connection
comes straight back.

**Resuming replayed a token that had already expired.** A download can sit paused
overnight, and the resume re-sent the `Authorization` header the task was created with. The
401 that came back was reported as a failed resume, which is not what happened and sends
you looking in the wrong place. The session is re-read and the header replaced at resume
time now.

**"Online" didn't mean the server was reachable.** `connectivity_plus` reports interfaces.
A captive portal or a router with a dead uplink both look like healthy Wi-Fi, so the app
announced "back online" and spent its one automatic retry on a route that was never going
to work. Every verdict now goes through a cheap `OPTIONS` probe, and a link with nothing
behind it is re-probed until something answers.

**Pause refused to work and blamed the user.** Pausing a transfer that hadn't started yet,
or a download whose server won't do ranges, failed with "This action isn't available right
now." That explains nothing and leaves cancelling as the only way to stop something.
Pausing always works now; what differs is whether the bytes are kept, and the row says
which it is.

**A flapping connection would have re-sent the same file all afternoon.** Park, resume,
park, resume — and because an upload to this server starts over each time, every cycle
costs the full file again on a metered link. Automatic restarts are capped at three per
transfer; after that it waits for a person. Transfers that keep their place aren't capped,
because resuming them is free.

**A connection that dropped and returned mid-park stranded transfers.** The two handlers
ran independently, so "resume everything parked" could run while the parking was still in
flight and find nothing to do, leaving rows paused with nothing coming for them. They share
one queue now.

**Parking cancelled the native task, and the cancellation came back as an event** that
would have turned a paused row into a cancelled one. Our own cancellations are now
recognised and ignored.

**Progress on a resumed upload would have been measured against the wrong number.** The
native task only sends the bytes after the offset, so both the size and the fraction it
reports describe that remainder. Taken at face value, resuming at 80% would have shown 0%
and climbed to 100% over the last fifth of the file. The values are rebased onto the whole
file, which is also why the bar doesn't jump when a resume starts.

**An upload could have been sent twice.** If the last bytes land and the connection dies
before the response arrives, the server has the file and the app doesn't know it. Asking
for the offset answers that too — when it comes back equal to the file size the upload is
marked complete instead of being re-sent.

**A big upload could lose the file it was reading from.** The file picker doesn't hand
back the file you chose — it hands back a copy it wrote into the app's *cache* directory,
and Android is free to purge that whenever storage runs short. That's fine for a 2 MB CSV
that uploads in a second. It is not fine for a 500 MB video: the upload can be parked
overnight waiting for Wi-Fi, or sitting failed until someone comes in and taps Retry, and
the source can quietly evaporate in between. The resume then reports "Upload source is
gone", which is true and useless — nothing the operator did caused it and nothing they can
do fixes it.

Downloads already avoid this (`Config.useCacheDir` is `never`, for the same reason), so
uploads now do too: the picked copy is moved into `<app support>/upload_sources/` before
the task is enqueued. Both directories are inside the app's own container, so it's a
rename — instant, and it does not need a second 500 MB of free space. Files outside the
sandbox are a path the operator owns and are never moved or deleted. Names are stamped so
two uploads of `catalog.csv` can't land on each other, the copy is deleted when the upload
finishes, and a resync prunes anything no transfer refers to any more — otherwise a crash
between the move and the database write would strand half a gigabyte for good.

**The schema gained columns with no way to upgrade into them.** There was no `onUpgrade`,
so bumping the version would have thrown on every install that already had history in it —
on terminals already in shops. Migrations run step by step now, so a device that skipped a
release still lands on the right schema.

**Golden-test diff output was committed.** `test/golden/failures/` is written on every
failed comparison and had been checked in. Deleted and ignored.

## Tests

`flutter test` runs 285 tests and needs no device.

Unit tests cover the parsers (every documented response shape plus malformed input — the
mock API is loosely specified so the parsers are deliberately tolerant), upload validation,
URL building and encoding, byte and duration formatting, unique and sanitized file names,
status and progress mapping including the plugin's negative sentinel values, and error
mapping.

DAO tests run against an in-memory SQLite: row round-trips, upsert, ordering, bulk delete,
cache replacement inside a transaction, survival across a reopen. Repository tests go one
level up and check the offline-first behaviour end to end — a refresh caches the result, a
failure falls back to the cache, delete and logout leave the cache honest.

The pause-and-resume behaviour has its own set, because it is the part with the most ways
to be subtly wrong: losing the route parks a running download in place and records why;
regaining it resumes with a freshly read token; a transfer the operator paused is left
alone when the connection returns; a download that can't pause in place is parked by
cancelling it instead; an upload the server can't continue starts over and says so; one it
can continue keeps its progress; one the server already holds in full is completed rather
than re-sent; and a connection flapping five times restarts the same upload three times,
not five. A second set covers the upload's working file against real directories (with
`path_provider` standing in for the platform ones): a picked copy is moved out of the
cache rather than copied, a file the operator owns is left exactly where it is and is
never deleted, two uploads of the same name don't collide, and a prune drops the orphans
while keeping what a parked transfer is still waiting on.

`UploadResumeProbe` is covered separately against a mocked client — `308` with a
`Range` header, a bare tus-style offset, a `200` meaning the file is already there, an
offset past the end of the file, an unreachable server, and the caching that means an
endpoint which has said no is never asked twice. `ConnectivityServiceImpl` is tested for
the case that caused the trouble: an interface that is up with nothing reachable behind it.
`TransferModel` covers the progress rebasing, so a resumed upload can't report its own
remainder as the whole file.

Every bloc has `bloc_test` coverage with mocked repositories and real use cases:
`AuthBloc` (session restore, login, logout, the expiry timer), `TransferBloc` (history,
live updates, ordering, derived counters, auto-retry, and what the operator is told when a
transfer is parked by the network and when it picks up again), `UploadBloc`, `FilesBloc`.

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

Enable airplane mode while a transfer is running. Within a few seconds the row should go
to **Waiting for internet** rather than failing, a snackbar should say the connection was
lost, and the detail line should say what resuming will cost. Disable airplane mode and the
transfer should start again on its own; a download should name the position it continued
from. Try it on a download at around 80% and confirm the progress bar does not go back to
zero.

For the captive-portal case, join a Wi-Fi network with no working uplink (an emulator with
`-netdelay none -netspeed none` plus a blocked host, or a hotspot with mobile data off).
The app should say there is no connection to the server even though Wi-Fi shows as
connected, and recover within about 15 seconds of the route coming back.

Swipe the app away (not force stop), wait a moment, then reopen. The history should be
intact, any completed downloads should be in `Downloads/POS Software`, and running tasks
should still be running.

Pause and resume a download, and then pause it again, restart the app and resume — the
partial file should be kept and the resume should continue from where it left off, with the
paused row stating the position beforehand. Pause an upload and confirm the row says it
will start again from the beginning *before* you resume it, then resume and confirm the
snackbar explains that this server can't continue an interrupted upload.

To see the resumable-upload path actually run you need an endpoint that answers the offset
request. Point `Endpoints.baseUrl` at a tus server (`tusd -behind-proxy`) or anything else
that replies `308` with a `Range` header, pause a large upload past 8 MB, and resume: the
progress bar should carry on from where it stopped instead of resetting.

Install the previous build, start a couple of transfers, then install this one over it. The
history should still be there — the database migrates rather than being recreated.

For the upload working file: start a 500 MB upload, pause it, then clear the app's cache
from Android settings (Storage → Clear cache, *not* Clear data). Resume — it should still
run, because the source was moved out of the cache before the task started.

Worth knowing about disk space at this size. A 500 MB upload needs 500 MB free for the
picker's copy, and "Preparing file..." is a real copy taking a few seconds with no progress
bar. A 500 MB download needs 500 MB plus 50 MB headroom to start — the plugin checks that
up front and fails immediately with "Not enough storage space" rather than wasting the
bandwidth — and then briefly needs another 500 MB when the finished file is copied into
`Downloads/POS Software` through MediaStore. If that last copy can't fit, the download
stays in private storage and is still openable from inside the app; it just won't appear in
the Files app.

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

**Uploads to this server still restart from zero when interrupted.** The negotiation, the
offset plumbing and the honest messaging are all in place and tested; what's missing is a
server that answers the question. It's a constraint of the API, not the app, and it stops
being one the day the endpoint speaks any of the standard resumable protocols.

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

One rough edge I know about: when the OS parks a download for us, Android's notification
reads "Download paused" whether the operator paused it or the connection did. The in-app
row distinguishes the two; the notification can't, because its copy is configured per group
rather than per task. Worth fixing with per-task notification config if it ever confuses
anyone.

With more time I'd add an upload queue that batches catalog imports instead of firing them
one at a time, checksum verification after download,
per-transfer settings (Wi-Fi only, priority), a proper migration suite as the schema grows,
and the layout tests wired into CI.
