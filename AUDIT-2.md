# KingCric — Independent Audit #2 (READ-ONLY)

Date: 2026-10-17
Auditor: independent audit worker (read-only; did NOT edit APKs or main source files)
Scope: Why does "App not installed" / "App isn't compatible" happen on Realme GT 6T (arm64, Snapdragon 7+ Gen 3, Android 14 / API 34)?
Target APKs audited (on disk at audit time):
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` — 19,855,072 bytes, sha256 `7e1877f4b0e65a3a3cc33b340c83c21cdf4d97ad77a2610640cd4ba8478f4c6d` (built 16:52, latest uses-sdk fix)
- `build/app/outputs/flutter-apk/app-release-universal.apk` — 54,093,963 bytes, sha256 `4fac67de89a3e655ce206bc52339759acf8cbdbda1afb180a6c644e4daa531f7` (built 16:52, latest)
- Also listed: `app-armeabi-v7a-release.apk` (17,245,926), `app-x86_64-release.apk` (21,325,527), and STALE `app-release.apk` (20,240,079 bytes, 15:18, superseded)

Sources read: `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, `lib/main.dart`, `TEST_REPORT.md`, `STARTUP_FIX.md`, `android/app/build.gradle.kts`, `android/app/src/main/java/com/kingcric/app/MainActivity.java`, `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`, `tools/build_apk_manual.sh` (read-only).
Tools used (read-only): `aapt2 dump badging`, `aapt2 dump xmltree --file AndroidManifest.xml`, `apksigner verify --verbose` (+ `--min-sdk-version 21 --max-sdk-version 23` check), `zipalign -c -P 16 4`, `python3 zipfile` listing + `testzip()`, `readelf -l/-h`, `dexdump`.

> Key distinction: "App not installed" happens at **install time** (PackageManager). The `libdartjni.so` crash happens at **launch time** (after install succeeds). Do not conflate them. A missing `libdartjni.so` CANNOT cause "App not installed" — it causes "failed to start several times" after install.

---

## 1. uses-sdk — FIXED in latest APKs (was the primary install blocker in prior builds)

- Source `AndroidManifest.xml` NOW contains:
  ```xml
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36" />
  ```
- Verified in binary manifest (aapt2 xmltree, arm64 APK):
  ```
  E: uses-sdk
    minSdkVersion = 24
    targetSdkVersion = 36
  ```
- Verified in badging (arm64 + universal):
  ```
  package: name='com.kingcric.app' versionCode='1' versionName='1.0.0' ... compileSdkVersion='36'
  minSdkVersion:'24'
  targetSdkVersion:'36'
  ```
- Status: **FIXED / PRESENT** in the 16:52 builds.
- Why it mattered: prior builds (e.g. 54,094,126 / 19,851,139 bytes) had NO `<uses-sdk>` in the binary manifest (per TEST_REPORT diagnosis). PackageManager then treated targetSdk as 1, and Android 14+ rejected install with `INSTALL_FAILED_DEPRECATED_SDK_VERSION` → "App isn't compatible". That explains the GT 6T "incompatible" reports for the older builds. It does NOT explain a failure of the 16:52 builds, which do have uses-sdk.
- Residual: `build.gradle.kts` uses `minSdk = flutter.minSdkVersion` / `targetSdk = flutter.targetSdkVersion` (Gradle-injected), while the manual pipeline hardcodes 24/36 in the manifest + `--min-sdk-version 24 --target-sdk-version 36` to `aapt2 link`. If Flutter defaults ever change, the two can diverge. Not a GT 6T blocker today, but a maintenance risk. The build script gate (`grep minSdkVersion:'24'` / `targetSdkVersion:'36'` / `supports-any-density: 'true'`) now fails the build if badging lacks them — verified present in `tools/build_apk_manual.sh` lines ~203-215.

## 2. supports-screens / anyDensity — FIXED

- Source manifest now has:
  ```xml
  <supports-screens smallScreens="true" normalScreens="true" largeScreens="true" xlargeScreens="true" anyDensity="true" />
  ```
- Badging (arm64 + universal): `supports-screens: 'small' 'normal' 'large' 'xlarge'`, `supports-any-density: 'true'`.
- Binary xmltree confirms `anyDensity=true` + all four screen sizes `true`.
- Status: **FIXED / PRESENT**. Prior builds had only `normal` + `anyDensity false` — that alone would not cause "incompatible" on GT 6T, but it is now correct.

## 3. Signing — PRESENT for GT 6T (with one reporting nuance)

- `apksigner verify --verbose` (arm64 + universal, default):
  ```
  Verifies
  Verified using v1 scheme (JAR signing): false
  Verified using v2 scheme (APK Signature Scheme v2): true
  Verified using v3 scheme (APK Signature Scheme v3): true
  Verified using v3.1: false, v4: false
  Number of signers: 1
  ```
- With `--min-sdk-version 21 --max-sdk-version 23`: `v1: true`, v2/v3 false (expected — apksigner checks only schemes applicable to that range).
- Cert: `CN=Android Debug, O=Android, C=US`, RSA 2048, SHA-256 digest `e3e3a5caaf30499c5a60a09cbed45457103bed15d16a9dd2f62570e11c0a17fb`.
- Status: **NOT A BLOCKER for GT 6T (API 34)**. For minSdk 24, v2+v3 suffice; Android 7+ does not require v1. The "v1: false" in default output is a reporting quirk, not a missing signature (TEST_REPORT correctly notes this).
- Caveats (not install blockers for sideload, but real):
  - Debug-signed, NOT Play Store signing. Sideload is allowed if "Install unknown apps" is granted; the user will see "unknown developer / Install anyway".
  - **All builds share the same package + versionCode 1 + same debug cert.** See §11 (signature/version collision).

## 4. zipalign / 16 KB page-size — PASS

- `zipalign -c -v -P 16 4` on arm64 + universal: `Verification successful`, exit 0.
- `.so` files are STORED (`compress_type 0`), not DEFLATED — correct for mmap.
- `readelf -l` LOAD Align:
  - arm64 `libapp.so` / `libflutter.so`: Align `0x10000` (64 KB) — ≥16 KB, OK.
  - arm64 `libdartjni.so`: Align `0x4000` (16 KB) — OK.
  - armeabi-v7a `libapp.so` / `libdartjni.so`: Align `0x4000`; `libflutter.so`: Align `0x10000` — OK.
- Status: **PASS — NOT A BLOCKER**. 16 KB page-size enforcement (Android 15+) is satisfied.

## 5. Native libs (.so) — PRESENT, correct ABI, correct ELF

Zip listing (arm64 APK, 23 entries, `testzip() = None`):
```
STORED lib/arm64-v8a/libflutter.so (11,747,496 bytes)
STORED lib/arm64-v8a/libapp.so (5,768,072 bytes)
STORED lib/arm64-v8a/libdartjni.so (132,016 bytes)
```
Zip listing (universal APK, 29 entries, `testzip() = None`):
```
STORED lib/armeabi-v7a/libflutter.so, libapp.so, libdartjni.so
STORED lib/arm64-v8a/libflutter.so, libapp.so, libdartjni.so
STORED lib/x86_64/libflutter.so, libapp.so, libdartjni.so
```
ELF checks:
- arm64: all three `ELF64`, `Machine: AArch64` — correct.
- armeabi-v7a (universal): all three `ELF32`, `Machine: ARM` — correct, no arm64 copy mistakenly placed in armeabi dir.
- x86_64: per TEST_REPORT, `ELF64`, `Machine: X86-64` — correct (not re-verified byte-by-byte in this audit; badging `native-code` lists all three).
- Badging `native-code`: arm64 APK → `'arm64-v8a'`; universal → `'arm64-v8a' 'armeabi-v7a' 'x86_64'` — correct for GT 6T (arm64).
- Status: **PRESENT / CORRECT — NOT A BLOCKER for install.** (libdartjni is a launch-time dependency, not an install-time one.)

## 6. libdartjni.so — PRESENT in latest APKs (launch fix, NOT an install blocker)

- Present in every ABI dir in both audited APKs (see §5).
- Status: **FIXED / PRESENT**. The original crash ("failed to start several times", `UnsatisfiedLinkError` from `JniPlugin` static initializer) was correctly diagnosed: manual APKs previously shipped only `libflutter.so` + `libapp.so`. That crash happens AFTER install succeeds, so it cannot explain "App not installed". Do not cite libdartjni as the cause of an install failure.

## 7. GeneratedPluginRegistrant — PRESENT, correct plugin set

- Repo file: `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` registers exactly two plugins, each in try/catch(Exception):
  - `com.github.dart_lang.jni.JniPlugin`
  - `io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin`
- Dex check (arm64 APK, `classes.dex`, 3,175 class defs): contains `Lcom/github/dart_lang/jni/JniPlugin;`, `Lio/flutter/plugins/sharedpreferences/SharedPreferencesPlugin;`, `Lio/flutter/plugins/GeneratedPluginRegistrant;`, `Lcom/kingcric/app/MainActivity;`, `Lio/flutter/embedding/android/FlutterActivity;`.
- Note: the registrant catches `Exception` only. `UnsatisfiedLinkError` is an `Error`, not an `Exception`, so a missing `libdartjni.so` would still kill startup — but lib is now present (§6), so this is not an active blocker.
- Status: **PRESENT / CORRECT — NOT AN INSTALL BLOCKER.** (Launch-time only.)

## 8. Package name / MainActivity / versionCode — PRESENT, but versionCode collision is a live risk

- Package: `com.kingcric.app` everywhere — source manifest, binary manifest (`package="com.kingcric.app"`), badging, `MainActivity.java` (`package com.kingcric.app; public class MainActivity extends FlutterActivity {}`), `build.gradle.kts` (`namespace` + `applicationId = "com.kingcric.app"`).
- Launchable activity (badging): `com.kingcric.app.MainActivity`.
- Binary xmltree: activity `.MainActivity`, `exported=true`, `MAIN` + `LAUNCHER` intent-filter — correct for Android 12+ (missing `exported` would be a manifest-malformed install failure; it is present).
- versionCode / versionName: `1` / `1.0.0` in binary manifest + badging, consistent across ALL APKs on disk.
- Status: **Package/activity/version PRESENT — but see §11 for the versionCode/signature collision blocker.** The values themselves are not wrong; the fact that FIVE different builds all share `versionCode 1` is the problem.

## 9. Permissions / required features — NOT BLOCKERS

- Permissions (badging + binary manifest): only `INTERNET` + `ACCESS_NETWORK_STATE`. No dangerous / install-blocking permissions. No `installLocation` restriction.
- Features (badging): only `android.hardware.faketouch` (default for all apps, `uses-implied-feature ... reason='default feature'`). No required hardware GT 6T lacks (no camera, GPS, NFC, telephony requirement).
- Status: **NOT BLOCKERS.**

## 10. targetSdk 36 on Android 14 (API 34) device — ALLOWED, residual uncertainty only

- GT 6T is API 34; APK targets API 36. Per AOSP PackageManager rules, `targetSdk` is the max-tested level, NOT a cap — installing a targetSdk-36 APK on API 34 is allowed.
- Status: **NOT A BLOCKER per AOSP.** Residual uncertainty: this audit did NOT run `adb install` on a real GT 6T / Realme UI device, so an OEM-specific Realme UI PackageInstaller quirk cannot be ruled out from static checks alone. No evidence in the APK suggests one.

## 11. CRITICAL BLOCKER (STILL PRESENT): versionCode 1 + same debug cert + stale APKs = update-incompatible / wrong-file risk

- All five APKs on disk share `package com.kingcric.app` + `versionCode 1` + the same debug cert (`e3e3a5ca...`). Android treats an install over an existing install with the same package but a different signature as `INSTALL_FAILED_UPDATE_INCOMPATIBLE` → generic "App not installed" (no "incompatible" qualifier). It also treats a same-versionCode reinstall with different bytes as an update, not a fresh install.
- The user reports they "deleted everything", but this audit cannot verify on-device state. A partially staged install, a leftover staged session (`/data/app` / staged APK), or ANY prior KingCric install signed with a different keystore (e.g. the very first 20.2 MB build, if its keystore differed) would make EVERY subsequent install of the same package/versionCode fail with exactly "App not installed" — even though the new APK itself is valid. This is consistent with the user's report: "every time, both APKs, same error".
- Compounding: the STALE superseded `app-release.apk` (20,240,079 bytes, 15:18, pre-libdartjni, pre-uses-sdk-fix) is STILL in `build/app/outputs/flutter-apk/` alongside the new builds. Its badging also shows `minSdk 24 / targetSdk 36` in this audit's run (aapt2 derives some fields), so a user / script picking the wrong file by name (`app-release.apk` looks like "the" release APK) can easily install the wrong, superseded build. The output dir must contain exactly ONE shippable file, or the stale file must be deleted/renamed.
- Status: **CRITICAL BLOCKER (process, not bytes).** Fix: (a) bump `versionCode` to 2+ (and `versionName` to 1.0.1) for the next build so PackageManager treats it as an update; (b) DELETE or rename the stale `app-release.apk`; (c) ship exactly ONE APK file with ONE direct link; (d) instruct the user to fully uninstall KingCric, reboot, clear Downloads/staged files, then install the single new APK from Files.

## 12. CRITICAL BLOCKER (STILL PRESENT): no real Gradle build, no on-device install test

- Every APK on disk was built by the manual Gradle-free pipeline (`tools/build_apk_manual.sh`), because Gradle is blocked in this VM (Java TCP intercepted by sandbox). The pipeline is careful (uses-sdk gate, zipalign, apksigner, ELF checks), but it is NOT `flutter build apk --release`.
- Deviations from a real Gradle build found in this audit:
  - Binary manifest `android:name="android.app.Application"` (from `${applicationName}` placeholder not resolved the way Gradle does). A real Gradle build would set the Flutter application class (`FlutterApplication` / `FlutterPlayStoreSplitApplication`). `android.app.Application` is not an install blocker — `FlutterActivity` still inits the engine — but it is a deviation that has never been tested on-device.
  - `AssetManifest.bin` is 2 bytes in the APK (TEST_REPORT notes web is also 2 bytes; Flutter's newer asset-manifest format). Not proven to be a blocker, but it has never been validated by a real device launch from THESE APKs.
  - `META-INF/ANDROIDD.SF/RSA/MF` use `ANDROIDD` naming (from apksigner with the debug key) — standard for apksigner, not a blocker.
  - No `adb install` / PackageManager test has ever been run on any APK in this VM (no KVM, no device). `aapt2` + `apksigner` + `zipalign` passing does NOT prove PackageManager will accept the APK. Prior "VERIFIED" claims overstated this.
- Status: **CRITICAL BLOCKER (verification gap).** The only way to close it is a real Gradle build (e.g. GitHub Actions `flutter build apk --release` on a runner with network + Gradle) + an on-device `adb install` test on a GT 6T-class device (or at minimum `bundletool` / `apkanalyzer` + PackageManager-equivalent checks). Until then, every "fixed" claim is static-only.

## 13. CRITICAL BLOCKER (STILL PRESENT): delivery / install-method — bytes the user installed were never hash-verified

- User history (per TEST_REPORT + parent context): sandbox links inflated APKs to ~31.4 MB (vs 20.2 MB on disk); WhatsApp forwarding changed bytes; user installed by tapping APKs INSIDE WhatsApp viewer (`content://` URI from WhatsApp private storage), not via Files/Downloads PackageInstaller. On Android 14, WhatsApp-viewer installs frequently fail with a generic "App not installed / isn't compatible" even for a valid APK (no "Install unknown apps" grant for that flow, PackageInstaller cannot reliably read the content URI, download may still be in progress).
- This audit verified the bytes ON DISK. It cannot verify the bytes the user actually tapped on the phone. If the user installed from WhatsApp viewer, or from a stale/partial download, the on-disk validity is irrelevant.
- Status: **CRITICAL BLOCKER (delivery).** Fix: ship ONE remote-storage direct link, require the user to (a) download in Chrome, (b) check size + sha256 in Files BEFORE tapping Install (arm64 19,855,072 bytes / sha256 `7e1877f4...`; universal 54,093,963 / `4fac67de...`), (c) install from Files → Downloads, never from WhatsApp viewer, (d) confirm "Install unknown apps" is granted to Files/Chrome. If size/sha mismatch, delete and re-download — do not install.

## 14. Dart / startup hardening — PRESENT (launch, not install)

- `lib/main.dart`: `WidgetsFlutterBinding.ensureInitialized()`, `runZonedGuarded` + `FlutterError.onError`, guarded `AutoUpdateService.start()`. No `ErrorWidget.builder` override (correctly removed after it broke tests).
- `pubspec.yaml`: `cached_network_image` removed (zero Dart usages); `shared_preferences` retained (hence `jni`/`JniPlugin` still in registrant — correct, lib now bundled). No hardcoded secrets; API key only via `--dart-define`.
- `flutter analyze`: "No issues found!" per TEST_REPORT; `flutter test`: 3/3 pass. Web build succeeds.
- Status: **PRESENT — NOT AN INSTALL BLOCKER.** These affect launch stability, not PackageManager acceptance.

## 15. Icon — FIXED

- Mipmap PNGs present in APK at all 5 densities (`res/mipmap-*/ic_launcher.png`). Per TEST_REPORT/STARTUP_FIX, pixels verified identical to the Crown + Bat-Ball logo. User's latest screenshot shows the Crown + Bat-Ball icon in the install popup — icon fix confirmed by user.
- Status: **FIXED — NOT A BLOCKER.**

---

## Verdict: what still blocks "App not installed" on GT 6T

The 16:52 APK bytes themselves pass every static check this audit could run: uses-sdk, supports-screens, signing (v2+v3), zipalign, .so alignment/ELF/ABI, libdartjni present, registrant present, package/activity/version present, permissions/features clean. **There is no remaining static defect in the 16:52 APKs that by itself explains "App not installed" on GT 6T.**

The remaining critical blockers are NOT in the APK bytes — they are in verification, versioning, and delivery:

1. **No real Gradle build + no on-device install test.** All "verified" claims are static-only. Close with a real `flutter build apk --release` (e.g. GitHub Actions) + `adb install` on a GT 6T-class device.
2. **versionCode 1 + same debug cert + stale `app-release.apk` still in the output dir.** Any leftover/partial prior install makes every new install fail as an incompatible update. Bump versionCode, delete the stale file, ship exactly ONE APK.
3. **Delivery / install-method never hash-verified.** The user must verify size + sha256 in Files BEFORE installing, and must install from Files → Downloads (Chrome download), never from WhatsApp viewer. Until the user confirms "downloaded X bytes, sha256 Y, installed from Files", an install failure cannot be attributed to the APK.

If the user does (1) fresh uninstall + reboot, (2) Chrome download of the single new APK, (3) size/sha match in Files, (4) install from Files, and it STILL says "App not installed", the next step is `adb logcat` / `adb install -r` output (which gives the exact `INSTALL_FAILED_*` code) — the generic dialog alone does not distinguish these causes. Do NOT ship another manual-pipeline APK without that log.
