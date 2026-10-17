# KingCric — GitHub Actions Gradle Build Failure Diagnosis

**Date:** 2026-10-17
**Run:** `monsterbhaiya09-design/KingCric` → Actions run `39055368936` ("Build KingCric APK")
**Result:** FAILED at step **"Build release APK (real Gradle)"**
**Passed before the failure:** Checkout ✓, Set up Java 17 ✓, Set up Flutter 3.47.7 ✓,
Flutter doctor ✓, Pub get ✓, Analyze (clean) ✓, Test (3/3) ✓
**Skipped after the failure:** Verify APK, Upload APK artifact
**Scope of this file:** READ-ONLY audit. No code was changed, nothing was pushed.
The fixes in §4 are proposals — they have NOT been applied yet.

> ⚠️ Honesty note: the failed step's log was NOT available to this audit
> (the log download path needs the Actions log blob, which this environment
> could not fetch). The ranking below is therefore evidence-based
> hypothesis, ordered by how well each candidate fits the files in the repo
> and known Flutter-3.47 CI failure modes. The log is the only way to
> confirm. §5 tells you exactly what to look for in it.

## 1. What the passing steps already prove

- The repo contents are correct: all 70 files are on `main`, including
  `.github/workflows/build-apk.yml`, `pubspec.yaml`, and the whole `android/`
  tree. (If the workflow file were missing/corrupt, the run would never
  have started.)
- Java 17 + Flutter 3.47.7 install and work on the runner.
- The Android SDK is found (`flutter doctor` passed, `flutter pub get`
  ran — pub get resolves the Android side and writes `local.properties`).
- Dart code is clean: analyze has no issues, all 3 tests pass.
- So the failure is **Android/Gradle configuration or runner environment**,
  not Dart code, not the workflow YAML, not the upload.

## 2. Key context: the Android Gradle build has NEVER succeeded anywhere

`flutter build web` passed locally, but the VM's sandbox blocks Java TCP,
so `flutter build apk` (real Gradle) could never run locally. Every APK
shipped so far was assembled by the manual Gradle-free pipeline. That means
every Android-specific Gradle setting in this repo — AGP/Kotlin/Gradle
versions, NDK version, `settings.gradle.kts`, the manifest — is
**unvalidated**. The GitHub run is the first real Gradle execution, so a
first-time Gradle configuration failure is the expected shape of this bug,
not a surprise.

## 3. Top 5 most likely failure causes (ranked)

### Cause 1 (MOST LIKELY) — NDK 28.2.13676358 is not installed on the runner

**Evidence:**
- `android/app/build.gradle.kts` sets `ndkVersion = flutter.ndkVersion`.
- Flutter 3.47.7's `FlutterExtension.kt` pins
  `ndkVersion = "28.2.13676358"` (verified in `~/flutter/packages/
  flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`).
- The workflow installs Java + Flutter but **never installs an NDK**
  and never sets `ANDROID_NDK_HOME`. It relies on whatever NDKs happen
  to be preinstalled on `ubuntu-latest`.
- `flutter doctor` does NOT fail on a missing/mismatched NDK, so the
  earlier green steps do not rule this out.
- This is the single most common Flutter-Android CI failure:
  Gradle aborts configuration with
  `No version of NDK matched the requested version 28.2.13676358`
  / `NDK version 28.2.13676358 is not installed`.

**Typical log signature to confirm:** `NDK`, `28.2.13676358`,
`No version of NDK matched`, `ndk.dir`, `NDK not configured`.

### Cause 2 — `settings.gradle.kts` throws `flutter.sdk not set in local.properties`

**Evidence:**
- `android/settings.gradle.kts` does a hard `require(...)`:
  ```kotlin
  val flutterSdkPath = run {
      val properties = java.util.Properties()
      file("local.properties").inputStream().use { properties.load(it) }
      val flutterSdkPath = properties.getProperty("flutter.sdk")
      require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
      flutterSdkPath
  }
  ```
  This runs at **settings evaluation** — the very first thing Gradle does.
  If `local.properties` is missing or lacks `flutter.sdk`, the build dies
  immediately with that exact message, before any task runs.
- `android/local.properties` is **gitignored** (`.gitignore` +
  `android/.gitignore` both list it) and was **not** in the repo
  (`git ls-files` shows no `local.properties`). The build depends on the
  Flutter tool regenerating it at build time (`updateLocalProperties`
  in `gradle_utils.dart` writes `sdk.dir` + `flutter.sdk` + build
  mode/version). `flutter pub get` normally does this — but if that step
  wrote it to a different location, or the runner's Flutter layout
  differs (e.g. `subosito/flutter-action` cache layout), Gradle reads a
  stale/missing file and the `require()` throws.
- Note the local `android/local.properties` in this VM contains
  `flutter.sdk=/home/hatch/flutter` — a machine-specific path that must
  NOT be committed; the runner needs its own.

**Typical log signature to confirm:** `flutter.sdk not set in local.properties`,
`settings.gradle.kts`, `Could not compile settings file`, or
`local.properties` + `FileNotFoundException`.

### Cause 3 — AGP 9.1.0 / Kotlin 2.4.0 / Gradle 9.3.1 version skew

**Evidence:**
- `android/settings.gradle.kts` pins:
  `id("com.android.application") version "9.1.0"`,
  `id("org.jetbrains.kotlin.android") version "2.4.0"`.
- `android/gradle/wrapper/gradle-wrapper.properties` pins
  `gradle-9.3.1-all.zip`.
- These are the `flutter create` template values for Flutter 3.47.7, so
  they *should* be mutually compatible — but they have never been
  executed, and AGP 9.x is strict about Kotlin/Gradle pairings. A skew
  shows up as a configuration-phase error such as
  `Kotlin version ... is not compatible with AGP`, `Minimum supported
  Gradle version is ...`, or a Kotlin-DSL compilation error in
  `build.gradle.kts`.
- Secondary smell: `android/gradle.properties` sets
  `android.newDsl=false` and `android.builtInKotlin=false`. These are
  legacy template flags; AGP 9.x removed/ignored several of them.
  Unknown `gradle.properties` keys are normally ignored, not fatal —
  but a removed AGP flag is a plausible contributor if the log mentions
  `newDsl` / `builtInKotlin`.

**Typical log signature to confirm:** `Kotlin`, `AGP`, `Minimum supported
Gradle version`, `newDsl`, `builtInKotlin`, `Could not compile build file`.

### Cause 4 — Manifest `<uses-sdk>` conflicts with Gradle-injected `uses-sdk`

**Evidence:**
- `android/app/src/main/AndroidManifest.xml` declares:
  ```xml
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36" />
  ```
  This was added deliberately for the **manual** pipeline, because the
  manual pipeline does not inject `uses-sdk` (its absence caused
  `INSTALL_FAILED_DEPRECATED_SDK_VERSION` on Android 14).
- Real Gradle **also** injects `uses-sdk` from
  `defaultConfig { minSdk = flutter.minSdkVersion /* 24 */
  targetSdk = flutter.targetSdkVersion /* 36 */ }`.
- The values currently match (24/36, confirmed against
  `FlutterExtension.kt`: `minSdkVersion = 24`, `targetSdkVersion = 36`,
  `compileSdkVersion = 36`), so the manifest merger should accept them.
  But AGP 9's merger is stricter than AGP 8's about duplicate
  `uses-sdk` declarations, and any drift (e.g. a Flutter patch changing
  a default) turns this into a hard
  `Manifest merger failed : uses-sdk:minSdkVersion ...` error.
- The manual-pipeline workaround is now a liability on the official path:
  it is redundant under real Gradle and a merger-failure risk.

**Typical log signature to confirm:** `Manifest merger failed`,
`uses-sdk`, `minSdkVersion`, `targetSdkVersion`, `Merging Errors`.

### Cause 5 — Runner environment: Android platform / build-tools / dependency resolution

**Evidence:**
- `compileSdk = flutter.compileSdkVersion` = **36**. The runner must have
  `platforms;android-36` installed. `ubuntu-latest` images ship it, but
  if the runner image lagged or the SDK is partial, Gradle fails with
  `Failed to find target with hash string 'android-36'` /
  `SDK location not found`.
- The workflow's **Verify** step hardcodes
  `$ANDROID_HOME/build-tools/36.0.0/aapt2` (and apksigner/zipalign).
  That step is post-build, so it did NOT cause *this* failure — but it
  is a latent landmine: if the runner's newest build-tools is not
  exactly `36.0.0`, Verify will fail even after a successful build.
- Gradle must download the `gradle-9.3.1-all.zip` distribution and all
  plugin dependencies (AGP, Kotlin, Flutter plugin) from the network.
  A transient download/proxy failure looks like
  `Could not download gradle-9.3.1-all.zip`, `Could not resolve
  com.android.application`, or a timeout — indistinguishable from a
  config error without the log.

**Typical log signature to confirm:** `android-36`, `build-tools`,
`Could not download`, `Could not resolve`, `Connection reset`,
`timeout`.

## 3b. Ruled OUT (do not "fix" these — the fix would be a red herring)

- **Missing `android/gradlew` / `gradle-wrapper.jar` in the repo.**
  `android/.gitignore` ignores `/gradlew`, `/gradlew.bat`, and
  `gradle-wrapper.jar`, so they were not in `git ls-files` and not
  uploaded to GitHub. This is **NOT** fatal: Flutter's
  `GradleUtils.getExecutable()` calls `injectGradleWrapperIfNeeded()`
  first, which copies the wrapper scripts + jar from the Flutter cache
  artifact (`GradleWrapper` in `flutter_cache.dart`) when they are
  missing, without overriding existing files. `flutter build apk`
  regenerates them on the runner. Do not commit them to "fix" the build.
- **Dart code / tests / analyze.** All green before the build step.
- **Workflow YAML syntax.** The run started and executed 8 steps.
- **Debug signing.** `signingConfig = signingConfigs.getByName("debug")`
  auto-generates a debug keystore; it does not block a release build.
- **Permissions.** `permissions: contents: read` is sufficient for
  build + artifact upload; no repo write is needed.

## 4. Suggested fixes (NOT yet applied — apply after confirming with the log)

Apply in this order; each is independent and safe:

1. **Install the exact NDK (fixes Cause 1).** Add a step before the
   build step:
   ```yaml
   - name: Install NDK 28.2.13676358
     run: |
       echo "y" | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "ndk;28.2.13676358"
       ls "$ANDROID_HOME/ndk"
   ```
   (If `cmdline-tools/latest` is absent on the runner, use
   `android-actions/setup-android@v3` with `ndk-version: 28.2.13676358`
   instead, or add a `sdkmanager --list_installed` diagnostic first.)

2. **Guarantee `local.properties` before Gradle runs (fixes Cause 2).**
   Add a step after Pub get:
   ```yaml
   - name: Ensure android/local.properties
     run: |
       flutter pub get
       cat android/local.properties
       grep -q '^flutter.sdk=' android/local.properties
   ```
   If `flutter.sdk` is ever missing, write it explicitly from the
   Flutter install on PATH:
   ```yaml
   - name: Write android/local.properties (fallback)
     run: |
       printf 'sdk.dir=%s\nflutter.sdk=%s\n' "$ANDROID_HOME" "$(dirname "$(dirname "$(which flutter)")")" > android/local.properties
       cat android/local.properties
   ```
   (Keep `android/local.properties` gitignored — never commit a
   machine-specific `flutter.sdk` path.)

3. **Remove the redundant `<uses-sdk>` from the manifest (fixes Cause 4).**
   Delete the `<uses-sdk ... />` line from
   `android/app/src/main/AndroidManifest.xml`. Real Gradle injects
   `uses-sdk` from `defaultConfig` (minSdk 24 / targetSdk 36). Keep the
   `<supports-screens ... />` block — it is harmless and correct.
   (This also retires the manual-pipeline workaround; do not ship
   another manual APK.)

4. **Make the Verify step build-tools-agnostic (fixes Cause 5 latent).**
   Replace the hardcoded `36.0.0` with the newest installed build-tools:
   ```bash
   BT="$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -n 1)"
   "$BT/aapt2" dump badging "$APK" | tee /tmp/badging.txt
   "$BT/apksigner" verify --verbose "$APK"
   "$BT/zipalign" -c -v -P 16 4 "$APK"
   ```

5. **Add diagnostics + keep the build log readable.**
   - Add a pre-build diagnostic step:
     ```yaml
     - name: Android environment diagnostics
       run: |
         flutter doctor -v
         ls "$ANDROID_HOME/ndk" || echo "NO NDK DIR"
         "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --list_installed || true
         cat android/local.properties || echo "NO local.properties"
         cat android/gradle/wrapper/gradle-wrapper.properties
     ```
   - Keep the build step as `flutter build apk --release` (do NOT add
     `--verbose` by default — it floods the log; use it only for one
     diagnostic re-run if the normal log is inconclusive).

6. **If the log shows Cause 3 (AGP/Kotlin skew):** regenerate the
   Android side from the Flutter 3.47.7 template (`flutter create`
   into a temp project, diff `android/settings.gradle.kts`,
   `android/gradle/wrapper/gradle-wrapper.properties`,
   `android/gradle.properties`) and adopt the template's exact
   AGP/Kotlin/Gradle triple instead of hand-editing versions.

## 5. How to confirm (read the failed step's log)

In GitHub: repo → **Actions** → run `39055368936` (or the latest run)
→ job **"Build release APK (official Gradle)"** → step
**"Build release APK (real Gradle)"** → expand, then search for:

| Log text | Means |
|---|---|
| `NDK`, `28.2.13676358`, `No version of NDK matched` | Cause 1 — install the NDK (§4.1) |
| `flutter.sdk not set in local.properties`, `settings.gradle.kts` | Cause 2 — guarantee `local.properties` (§4.2) |
| `Kotlin`, `AGP`, `Minimum supported Gradle version`, `newDsl` | Cause 3 — adopt template version triple (§4.6) |
| `Manifest merger failed`, `uses-sdk` | Cause 4 — remove `<uses-sdk>` from manifest (§4.3) |
| `android-36`, `build-tools`, `Could not download`, `Could not resolve` | Cause 5 — runner env / network; retry, then pin SDK packages |
| `What went wrong:` (Gradle's own section header) | Read the 10 lines under it — that is the root error |

**Do not** ship another manual-pipeline APK as a workaround for this
failure. The manual APKs are what failed on the GT 6T; the fix is to get
the official Gradle build green, then deliver exactly ONE artifact
(`kingcric-app-release-apk`) after verifying its size + sha256 against
the workflow log.
