# KingCric — Official GitHub Actions APK Build (Step-by-Step)

## Why this exists

The VM's sandbox blocks ALL Java-process outbound TCP, which breaks the
Gradle daemon's loopback TCP socket. Every APK assembled in the VM had to
use a manual Gradle-free pipeline. Those APKs passed local
`aapt2` / `apksigner` / `zipalign` checks, yet repeatedly failed to install
on the user's Realme GT 6T with just "App not installed" — even after
fixing `libdartjni.so`, the Crown + Bat-Ball icon, and `<uses-sdk>`.

**This is now the ONLY build path for a deliverable APK:** real Gradle on
GitHub's runner, where there is no such TCP block. Do NOT deliver another
manual-pipeline APK. The workflow is at
`.github/workflows/build-apk.yml`.

## What the workflow does

- Triggers on push to `main` (Dart / pubspec / android / workflow changes)
  and on manual `workflow_dispatch`.
- Runner: `ubuntu-latest`.
- Java 17 (Temurin) + Flutter 3.47.7 (stable, cached).
- `flutter pub get` → `flutter analyze` (must be clean) →
  `flutter test` (must pass 3/3) → `flutter build apk --release`
  (real Gradle, with daemon).
- **Verification gate (fails the job if any check fails):**
  - APK exists at `build/app/outputs/flutter-apk/app-release.apk`.
  - `aapt2 dump badging` shows `com.kingcric.app`, `minSdkVersion:'24'`,
    `targetSdkVersion:'36'`, `supports-any-density: 'true'`.
  - `apksigner verify` passes (v1+v2+v3).
  - `zipalign -c -P 16` passes (16 KB page alignment).
  - Zip integrity OK, and `lib/<abi>/{libflutter.so, libapp.so,
    libdartjni.so}` present for `arm64-v8a`, `armeabi-v7a`, `x86_64`.
  - Prints exact byte size + sha256.
- Uploads ONE artifact: `kingcric-app-release-apk` (retention 30 days).

## Prerequisites

- A GitHub account (free). The repo can be public (simplest) or private
  (Actions works the same; artifact download then needs sign-in).
- Git installed on the machine that pushes. No GitHub auth is stored in
  this project — the push step below is done by a human with their own
  GitHub login, NOT by the agent.
- Do NOT commit any secrets. There are none in this project: live mode
  takes its free API key via `--dart-define=CRIC_API_KEY=...` at build
  time, never checked in.

## Step 1 — Create the GitHub repo (once)

1. On github.com, create a NEW empty repo, e.g. `KingCric`.
   Do NOT initialise it with README / .gitignore / licence (the project
   already has its own files).
2. Note the repo URL, e.g. `https://github.com/<you>/KingCric.git`.

## Step 2 — Push this project (from the machine that has the files)

From the `kingcric/` folder (the folder containing `pubspec.yaml`):

```bash
cd ~/workspace/cricket-app/kingcric   # or wherever the project lives
git init
git add -A
# Make sure build/ artefacts are NOT committed (check .gitignore covers
# build/, .dart_tool/, .idea/, *.iml is already in the repo — verify with
# `git status` before committing).
git status
git commit -m "KingCric v1.0.0 - full app + official GitHub Actions APK build"
git branch -M main
git remote add origin https://github.com/<you>/KingCric.git
git push -u origin main
```

If the repo already exists and is ahead, pull first (`git pull --rebase`)
and resolve any conflicts before pushing.

## Step 3 — Run the workflow

- **Automatic:** the push to `main` triggers `Build KingCric APK`.
- **Manual:** GitHub repo → Actions → `Build KingCric APK` → Run workflow.
- Watch the run. It takes roughly 5–15 minutes (Flutter + Gradle first
  run). It MUST go green. If the verification gate fails, read the failing
  step's log — do NOT download an APK from a failed run.

## Step 4 — Cross-check BEFORE delivering (mandatory)

Team rule: nobody delivers an APK that only one person/machine checked.
Before sharing any link:

1. A second person (or a second agent run) re-reads the workflow log:
   `analyze` = clean, `test` = 3/3, verification gate = PASSED.
2. Compare the artifact's size + sha256 with the values printed in the
   verification step — they must match EXACTLY.
3. Confirm the artifact name is `kingcric-app-release-apk` and it contains
   exactly ONE file: `app-release.apk`.
4. Only then share the download link (Step 5). If anything mismatches,
   stop — do not share.

## Step 5 — Download the artifact APK

1. GitHub repo → Actions → the green `Build KingCric APK` run →
   Artifacts → `kingcric-app-release-apk` → Download.
2. Unzip it on your machine. Inside is exactly ONE file:
   `app-release.apk`.
3. Verify locally before sending it to a phone:

```bash
ls -l app-release.apk
sha256sum app-release.apk
# Compare both values with the numbers printed in the workflow's
# "Verify APK" step. If either differs, the download is corrupt —
# re-download, do NOT install.
```

## Step 6 — Deliver to the phone (ONE APK, ONE link)

- Share the APK as ONE direct download link (e.g. the remote-storage
  direct link used before, or the GitHub artifact link). Do NOT send two
  APKs, do NOT forward the APK file itself through WhatsApp.
- On the phone (Realme GT 6T): open the link in **Chrome** → Download →
  open **Files → Downloads** → tap the APK (**NOT inside WhatsApp**).
- Allow "Install unknown apps" for Files/Chrome if asked → Install →
  "Install anyway" on the unknown-developer warning (debug signature).
- Expected: Crown + Bat-Ball icon, app opens to Home with demo data.
  Live mode needs a free API key later (see `README.md`).

## If it still says "App not installed"

Do NOT fall back to another manual-pipeline APK. Collect and report:

- Phone model + Android version (Settings → About phone).
- Which artifact run (link + commit SHA) and the exact downloaded
  size + sha256.
- Screenshot of the exact error text.
- Confirmation the install was from Files/Downloads (not WhatsApp viewer).

Then fix the cause in source / workflow and rebuild via Actions.

## Files

- Workflow: `.github/workflows/build-apk.yml`
- Project README: `README.md`
- Crash / icon / uses-sdk history: `STARTUP_FIX.md`, `TEST_REPORT.md`
