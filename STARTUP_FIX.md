# KingCric — Startup Crash Fix (2026-10-17)

## What the user saw
- App **installed** (KingCric icon on the home screen) but on launch Android
  showed: **"KingCric failed to start several times. Restore it by
  clearing its history? Cancel / Clear now"** — a crash loop.
- Tapping **"Clear now" did NOT fix it** (so it was not corrupted
  preferences — it is code/native).
- The installed icon was the **default Flutter icon**, not the Crown +
  Bat-Ball logo.
- User has since **uninstalled** KingCric, so the next install is fresh.

## Root cause (proven, not guessed)
`JniPlugin` (from the `jni` package, pulled in by
`shared_preferences_android`) has a static initializer:

```java
static {
    System.loadLibrary("dartjni");
    setClassLoader(JniPlugin.class.getClassLoader());
}
```

The manual APK pipeline shipped only `libflutter.so` + `libapp.so` — **no
`libdartjni.so`**. On launch, `GeneratedPluginRegistrant` does
`new JniPlugin()` → the JVM runs the static initializer →
`UnsatisfiedLinkError` (an `Error`, **not** catchable by the registrant's
`catch (Exception e)`) → FlutterEngine init dies → Activity crashes →
Android restarts the app → crash loop → the "failed to start several
times" dialog.

Why web build + `flutter analyze` + `flutter test` all passed: web and
tests never load native `libdartjni.so`. Only Android launch hits it.

Contributing factors fixed at the same time:
- Unused `cached_network_image` pulled in `sqflite` / `jni_flutter`
  (more native surface, more risk) — removed (zero Dart usages).
- Startup had no `WidgetsFlutterBinding.ensureInitialized()`, no zone
  guard, and `AutoUpdateService.tick()` / prefs calls could throw
  unguarded. Now: `runZonedGuarded` + `FlutterError.onError`, guarded
  `tick()` (never throws), prefs with try/catch + in-memory fallback.
- Icon: the generated Crown + Bat-Ball logo was never copied into
  `android/app/src/main/res/mipmap-*/ic_launcher.png` — the APK still
  had the default Flutter icon. Fixed (all 5 densities, pixels verified).
- Manifest: manual pipeline now injects `package`, `versionCode="1"`,
  `versionName="1.0.0"` (Gradle normally does this; empty versionCode
  breaks upgrades).

## The fix in this build
- `libdartjni.so` built from the `jni` package's `src/CMakeLists.txt`
  with NDK 28.2 (per ABI: armeabi-v7a, arm64-v8a, x86_64), stripped,
  `Java_com_github_dart_1lang_jni_JniPlugin_setClassLoader` symbol
  verified present, 16 KB page-size flag (`-Wl,-z,max-page-size=16384`).
- `classes.dex` rebuilt: MainActivity + new registrant (JniPlugin +
  SharedPreferencesPlugin only) + JniPlugin.java + SharedPreferences
  Kotlin sources + DataStore `preferencesDataStore` polyfill.
  Verified: **0** Sqflite / JniFlutter classes in dex.
- `libapp.so` rebuilt from a fresh kernel (includes the startup
  hardening) with engine-matched `gen_snapshot` (Flutter 3.47.7,
  engine rev `deb287481e`).
- Reproducible builder: `tools/build_apk_manual.sh` (7 steps, all
  verified in-script). Do NOT use the old `~/apkbuild` one-off flow.
- `flutter analyze`: **No issues found!** `flutter test`: **3/3 passed**.

## New APKs (in build/app/outputs/flutter-apk/)
| File | Size (bytes) | sha256 |
|---|---|---|
| app-release-universal.apk | 54,094,126 | 38b9843f443fa7d725f576ae975acc1bd020250aadb652055fb06138a14a587b |
| app-arm64-v8a-release.apk | 19,851,139 | bd6a5a6b8fda99069d5382185f93fc181c5478a970269c006b367f340aa6c539 |
| app-armeabi-v7a-release.apk | 17,246,089 | f3e5b30a84e4f397f0519d1467c3c9596c218d06ec1891ec1a262670847dedfa |
| app-x86_64-release.apk | 21,325,690 | 7240dfc54b894a65e61d0cc8f22d872b6bb972573de82203170520bef5741174 |

All four verified: `apksigner verify` → Verifies, v1+v2+v3 true;
`zipalign -c -P 16 4` → OK; `aapt2 dump badging` → com.kingcric.app
v1.0.0 (versionCode 1), MainActivity, correct native-code per APK;
zip test clean; ELF `e_machine` matches each `lib/<abi>/` dir;
mipmap PNG pixels == new Crown + Bat-Ball logo at all 5 densities.
Old APKs (20.2 MB arm64-only, 54.3 MB universal without libdartjni)
are superseded — do NOT install them.

## Install (fresh, since the old app is uninstalled)
1. Download DIRECTLY from the remote-storage link (NOT WhatsApp
   forward, NOT sandbox preview link — both were observed to change
   the bytes / inflate the size). Links expire 2026-10-19.
2. Verify BEFORE installing: downloaded size must EXACTLY match the
   table above. Mismatch = corrupted download, delete + re-download.
3. Phone: Settings → Apps → Special app access → Install unknown
   apps → allow the app used to open the file (Files / Chrome).
4. Tap the verified APK → Install → "Install anyway" on the
   unknown-developer warning (debug signature; disappears in a Play
   Store build) → Open KingCric.
5. First launch shows demo data; live mode needs a free API key
   (see TEST_REPORT "What remains").

## If it still crashes
Report: exact Realme model + Android version + the point where it
crashes (splash / home / specific tab). The crash is no longer
explainable by a missing native lib — the next suspect would be a
device-specific engine / GPU issue, diagnosable from a logcat
(`adb logcat | grep -i -E "flutter|kingcric|FATAL"`).

## Caveats (unchanged)
- Debug-signed for sideloading, NOT for Play Store (needs a release
  keystore + Google's $25 one-time developer fee).
- No emulator / on-device install test in this VM (no KVM). The
  missing-`libdartjni.so` root cause was proven from the APK contents
  + the plugin source, not from running on a phone.
- Gradle remains blocked in this VM (sandbox TCP policy); the manual
  pipeline in `tools/build_apk_manual.sh` is the verified path.

---
## 2026-10-17 — "App isn't compatible" on Realme GT 6T — ADDENDUM

### What changed vs previous build
Previous APKs (54,094,126 / 19,851,139 bytes) had NO `<uses-sdk>` in the manifest. New APKs below fix that + keep the libdartjni + icon fixes.

### Why GT 6T said "incompatible" (both APKs)
1. Missing uses-sdk → PackageManager treated targetSdk as 1 → Android 14+ rejects install. Fixed: manifest now has minSdk 24 / targetSdk 36 + supports-screens all + anyDensity true. Verified via aapt2 badging + xmltree.
2. Installing from inside WhatsApp viewer (screenshot shows APKs inside "Voda phon" WhatsApp chat) — WhatsApp viewer install frequently fails with generic "incompatible" on Android 14. Correct method: Chrome direct download → Files → Downloads → tap APK. Do NOT tap APK inside WhatsApp, do NOT forward via WhatsApp.

### New APKs (supersede ALL older APKs)
- Universal: 54,093,963 bytes, sha256 4fac67de89a3e655ce206bc52339759acf8cbdbda1afb180a6c644e4daa531f7
  https://muse.ai/files/1400375103139657/2005276603469635/c9eqguqg3teaql1kf23yjz6r/app-release-universal.apk
- arm64 (GT 6T first choice): 19,855,072 bytes, sha256 7e1877f4b0e65a3a3cc33b340c83c21cdf4d97ad77a2610640cd4ba8478f4c6d
  https://muse.ai/files/1400375103139657/2296279547873468/k4x73s36vp25s5s4ydcj9yaa/app-arm64-v8a-release.apk
Links expire 2026-10-19. Verify size exactly before installing.

### Old phone crash
Old Realme still shows "failed to start" because it never got the libdartjni-fixed APK (previous builds failed to install). New APKs contain libdartjni.so per ABI. Install the NEW arm64 APK on old phone via Files method too — it should no longer crash. If it still crashes, report model + Android version + whether installed from Files.
