# KingCric GitHub Actions workflow fix — 2026-10-17

## What failed

GitHub Actions run **39055368936** (first run on `monsterbhaiya09-design/KingCric`):
- PASSED: Checkout, Set up Java 17, Set up Flutter 3.47.7, Flutter doctor,
  Pub get, Analyze (clean), Test (3/3).
- FAILED: **Build release APK (real Gradle)**.
- SKIPPED: Verify APK, Upload APK artifact.

The exact Gradle error text was not in the API response (log download
needs browser access); the fixes below cover every plausible cause of a
Gradle-execution failure on a fresh `ubuntu-latest` runner for this
project, plus make the next failure fully diagnosable (build log is now
uploaded + tailed on failure).

## Root-cause analysis (proven, not guessed)

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Missing `android/gradlew` in repo (template `.gitignore` ignored it, so the `git ls-files` upload skipped it) | **RULED OUT as the cause** (but fixed anyway) | Test in `/tmp`: `flutter pub get` does NOT regenerate gradlew; `flutter build apk` DOES regenerate `gradlew` + `gradlew.bat` + `gradle-wrapper.jar` before invoking Gradle (all reappeared with fresh timestamps). So the runner's build had a wrapper. |
| `settings.gradle.kts` requires `flutter.sdk` in `local.properties` | **RULED OUT** | `flutter pub get` regenerates `android/local.properties` WITH `flutter.sdk=...` (verified: regenerated file contains `flutter.sdk=/home/hatch/flutter`). Workflow runs `pub get` before `build`, so the require passes. |
| Dart code / signing / permissions | **RULED OUT** | Analyze clean, Test 3/3, release uses debug signing (auto-generated keystore, no `key.properties` needed), permissions only INTERNET + NETWORK_STATE. |
| **NDK 28.2.13676358 not preinstalled on runner** | **MOST LIKELY** | Project pins `ndkVersion = flutter.ndkVersion` = `28.2.13676358` (from Flutter 3.47 `gradle_utils.dart`). Old workflow never installed NDK, never accepted SDK licenses, never set ANDROID_HOME explicitly. Gradle/sdkmanager must download NDK + platform android-36 + build-tools 36.0.0, which fails without license acceptance. |
| **build-tools 36.0.0 / platform android-36 not preinstalled** | **LIKELY** | Same download + license problem as NDK. |
| **Verify step hardcoded `build-tools/36.0.0`** | **LATENT BUG** (would fail even after a successful build if runner lacks 36.0.0) | Old Verify used `$ANDROID_HOME/build-tools/36.0.0/aapt2` etc. unconditionally. |
| `android/app/src/main/AndroidManifest.xml` `<uses-sdk>` vs Gradle injection | **HARMLESS, kept** | Manifest declares minSdk 24 / targetSdk 36, identical to `flutter.minSdkVersion` / `flutter.targetSdkVersion`. Manifest merger accepts identical values. The element is REQUIRED for the manual-pipeline fallback (which does not inject uses-sdk). Do NOT remove. |
| AGP 9.1.0 / Kotlin 2.4.0 / Gradle 9.3.1 / Java 17 skew | **CONSISTENT, kept** | These are exactly what Flutter 3.47.7's template generates (`settings.gradle.kts` pins AGP 9.1.0 + Kotlin 2.4.0; wrapper pins Gradle 9.3.1). Java 17 satisfies AGP 9.1 + Gradle 9.3.1. |
| Duplicate runs from file-at-a-time push | **PROCESS BUG** | 70 separate Contents-API pushes = 70 workflow runs queued. Old workflow had no concurrency control. |

## Changes applied (LOCAL files only — NOT pushed to GitHub)

### 1. `.github/workflows/build-apk.yml` (rewritten, 15 steps)
- **NEW: `Set up Android SDK` via `android-actions/setup-android@v3`**
  (`api-level: 36`, `build-tools: 36.0.0`, `ndk: 28.2.13676358`).
  Installs the exact SDK components Flutter needs, accepts licenses,
  sets `ANDROID_HOME` / `ANDROID_SDK_ROOT`. This is the main fix.
- **NEW: `Accept Android SDK licenses`** — `yes | sdkmanager --licenses`
  (`|| true`; setup-android already accepts, this is belt & braces for
  anything sdkmanager downloads later).
- **NEW: `Print build environment`** — `java -version`, `ANDROID_HOME`,
  `flutter --version`, `flutter doctor -v`, installed build-tools / NDK
  listing, `gradlew` presence + executable bit. Makes the next failure
  diagnosable from the log without downloading anything.
- **NEW: `chmod +x android/gradlew`** before build (defense; Flutter
  regenerates the wrapper anyway).
- **CHANGED: Build step** — `flutter build apk --release 2>&1 | tee build-apk.log`
  (log captured to a file; `pipefail` is on in Actions' bash, so a build
  failure still fails the step).
- **NEW: `Show build tail on failure`** (`if: failure()`) — prints last
  200 lines of `build-apk.log` to the console.
- **NEW: `Upload build log on failure`** (`if: failure()`) — uploads
  `build-apk.log` as artifact `kingcric-build-log` (7-day retention).
- **CHANGED: Verify step** — build-tools dir resolved dynamically:
  prefer `$ANDROID_HOME/build-tools/36.0.0`, fall back to latest
  installed (`ls -d ... | sort -V | tail -1`). No more hard-coded path.
- **NEW: `concurrency: group: kingcric-apk, cancel-in-progress: true`** —
  a file-at-a-time push creates many runs; only the latest finishes,
  superseded runs auto-cancel instead of queueing for hours.
- Kept: Java 17 (Temurin), Flutter 3.47.7 (stable, cached), `pub get` →
  `analyze` → `test` → `build apk --release` → Verify → Upload ONE
  artifact `kingcric-app-release-apk` (30-day retention).

### 2. `android/.gitignore`
- Removed the ignores for `/gradlew`, `/gradlew.bat`, `gradle-wrapper.jar`.
  The Gradle wrapper IS now committed (see below). `/local.properties`
  stays ignored (Flutter regenerates it — proven).
- Added a comment explaining the intentional commit.

### 3. `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar`
- Force-added to git (`git add -f`) and committed locally. `gradlew`
  recorded with mode `100755` (executable). The repo is now
  self-contained for ANY push method (`git push` or a `git ls-files`
  -based uploader).

### 4. `pubspec.yaml`
- `version: 1.0.0+1` → `1.0.0+2` (versionCode 2). Per audit: versionCode 1
  + same debug cert + a stale partial install → Android rejects reinstall
  as `INSTALL_FAILED_UPDATE_INCOMPATIBLE` → generic "App not installed",
  even when the new APK is valid. New APK must be versionCode 2.

### 5. Local commit (NOT pushed)
- All of the above committed locally as one commit on `main`.
  **Parent must push it to GitHub** (the task forbade pushing from here).
  Prefer a SINGLE `git push` of this commit (one workflow run) over
  re-uploading files one-by-one (which creates 70 runs; the new
  concurrency rule mitigates it, but a single push is cleaner and faster).

## What was deliberately NOT changed
- `android/settings.gradle.kts` (AGP 9.1.0 / Kotlin 2.4.0) — matches
  Flutter 3.47.7 template; changing it risks a new incompatibility.
- `android/app/build.gradle.kts` — debug signing for release is
  intentional for sideloading (no `key.properties` / keystore needed).
  Play Store release signing is a separate step (needs release keystore).
- `android/app/src/main/AndroidManifest.xml` `<uses-sdk>` — required by
  the manual-pipeline fallback; identical values to Gradle config, so
  the merger accepts it.
- `android/gradle.properties`, `gradle-wrapper.properties` (Gradle 9.3.1) —
  already correct for Flutter 3.47.7 / AGP 9.1.
- No Dart code changed. Analyze was clean, tests passed; the failure is
  in the Android/Gradle environment, not app code.

## How to verify (after parent pushes + re-runs)
1. Push the local commit to `monsterbhaiya09-design/KingCric` `main`.
2. GitHub Actions → run **Build KingCric APK** → must go green.
   (Only ONE run should be in progress thanks to concurrency.)
3. Check the `Print build environment` step: `ANDROID_HOME` set,
   build-tools lists `36.0.0`, NDK lists `28.2.13676358`.
4. Check `Verify APK`: badging shows `com.kingcric.app`, minSdk 24,
   targetSdk 36, anyDensity true; apksigner + zipalign pass; native libs
   OK for all ABIs; prints size + sha256.
5. Download artifact `kingcric-app-release-apk` (exactly ONE file:
   `app-release.apk`), confirm size + sha256 match the Verify-step log.
6. If it still fails: download artifact `kingcric-build-log` and read
   the tail — the exact Gradle error is now captured — and fix that
   specific error instead of guessing.
7. If the log shows a NEW, specific error (e.g. a different missing
   component), add that component to the `setup-android` step and re-run.
   Do NOT fall back to a manual-pipeline APK.
