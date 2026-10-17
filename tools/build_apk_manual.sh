#!/bin/bash
# KingCric manual APK builder (Gradle-free).
# WHY THIS EXISTS: the VM sandbox intercepts Java-process loopback TCP,
# which breaks the Gradle daemon, so `flutter build apk` cannot run here.
# This script reproduces what `flutter build apk --release` does, using
# only the official Flutter toolchain + Android SDK build-tools:
#   flutter build bundle -> gen_snapshot (per ABI) -> javac/kotlinc + d8
#   -> aapt2 compile/link -> zip assemble -> zipalign -> apksigner.
#
# CRASH FIX (2026-10-17): the APK MUST bundle libdartjni.so per ABI.
# JniPlugin's static initializer calls System.loadLibrary("dartjni");
# without it the app dies on launch ("failed to start several times")
# because UnsatisfiedLinkError is an Error, not catchable by the
# registrant's catch(Exception). libdartjni.so is built from the jni
# package's src/CMakeLists.txt with the NDK (see tools/build_dartjni.sh
# equivalent inline below; prebuilt copies live in /tmp/dartjni/<abi>/).
#
# ICON FIX (2026-10-17): mipmap ic_launcher.png files are the generated
# Crown + Bat-Ball logo (converted from assets/media-generation-*.webp).
# aapt2 recompiles res/ fresh on every run, so the APK icon is correct.
#
# Usage: bash tools/build_apk_manual.sh
# Output: build/app/outputs/flutter-apk/{app-release-universal,
#   app-arm64-v8a-release, app-armeabi-v7a-release, app-x86_64-release}.apk
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT"

export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="${JAVA_HOME:-$HOME/jdk21}"
export PATH="$JAVA_HOME/bin:$HOME/Android/Sdk/build-tools/36.0.0:$HOME/Android/Sdk/platform-tools:$PATH"
SDK="$HOME/Android/Sdk"
BT="$SDK/build-tools/36.0.0"
NDK="$SDK/ndk/28.2.13676358"
ENGINE_REV="deb287481e"   # Flutter 3.47.7 engine revision (hash d8a2d6c7...)
FLUTTER_SDK="$HOME/flutter"
KEYSTORE="$HOME/apkbuild/debug.keystore"
KEY_ALIAS="androiddebugkey"
OUT="build/app/outputs/flutter-apk"
WORK="/tmp/kingcric-apkbuild"
rm -rf "$WORK"; mkdir -p "$WORK"/{dex-src,dex-classes,dex-out,res-compiled,apk-tmp,libs}
mkdir -p "$OUT"

echo "== [1/7] flutter build bundle (fresh kernel + flutter_assets) =="
flutter build bundle --release
# Kernel location in Flutter 3.47: .dart_tool/flutter_build/<hash>/app.dill
# (NOT build/app.dill). Take the newest one = the bundle just built.
KERNEL="$(ls -t .dart_tool/flutter_build/*/app.dill | head -n 1)"
echo "kernel: $KERNEL ($(stat -c%s "$KERNEL") bytes)"
cp -r build/flutter_assets "$WORK/flutter_assets"

echo "== [2/7] gen_snapshot libapp.so per ABI (engine-matched) =="
for SPEC in "arm64-v8a:android-arm64-release" "armeabi-v7a:android-arm-release" "x86_64:android-x64-release"; do
  ABI="${SPEC%%:*}"; ENG="${SPEC##*:}"
  mkdir -p "$WORK/libs/$ABI"
  "$FLUTTER_SDK/bin/cache/artifacts/engine/$ENG/linux-x64/gen_snapshot" \
    --snapshot_kind=app-aot-elf --elf="$WORK/libs/$ABI/libapp.so" --strip "$KERNEL"
  echo "libapp.so $ABI: $(stat -c%s "$WORK/libs/$ABI/libapp.so") bytes"
done

echo "== [3/7] libflutter.so per ABI (infra bucket, engine $ENGINE_REV) + libdartjni.so =="
# Reuse the previously verified engine-matched libflutter.so files.
cp ~/apkbuild/arm64/libflutter.so "$WORK/libs/arm64-v8a/libflutter.so"
cp ~/apkbuild/arm/libflutter.so   "$WORK/libs/armeabi-v7a/libflutter.so"
cp ~/apkbuild/x64/libflutter.so  "$WORK/libs/x86_64/libflutter.so"
# libdartjni.so built from jni-1.1.0 src/CMakeLists.txt with the NDK.
for ABI in armeabi-v7a arm64-v8a x86_64; do
  if [ ! -f /tmp/dartjni/$ABI/libdartjni.so ]; then
    echo "Building libdartjni.so for $ABI ..."
    rm -rf /tmp/dartjni/$ABI && mkdir -p /tmp/dartjni/$ABI
    cmake -S "$HOME/.pub-cache/hosted/pub.dev/jni-1.1.0/src" -B /tmp/dartjni/$ABI \
      -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-24 \
      -DCMAKE_BUILD_TYPE=Release > /tmp/dartjni/$ABI-configure.log 2>&1
    cmake --build /tmp/dartjni/$ABI --parallel > /tmp/dartjni/$ABI-build.log 2>&1
    "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" /tmp/dartjni/$ABI/libdartjni.so
  fi
  cp /tmp/dartjni/$ABI/libdartjni.so "$WORK/libs/$ABI/libdartjni.so"
  echo "libdartjni.so $ABI: $(stat -c%s "$WORK/libs/$ABI/libdartjni.so") bytes"
done

echo "== [4/7] classes.dex (MainActivity + NEW registrant + JniPlugin + SharedPreferences + polyfill) =="
JAVAC_SRC="$WORK/dex-src"
mkdir -p "$JAVAC_SRC/com/kingcric/app" "$JAVAC_SRC/io/flutter/plugins" \
  "$JAVAC_SRC/com/github/dart_lang/jni" "$JAVAC_SRC/io/flutter/plugins/sharedpreferences" \
  "$JAVAC_SRC/androidx/datastore/preferences"
cp android/app/src/main/java/com/kingcric/app/MainActivity.java "$JAVAC_SRC/com/kingcric/app/"
cp android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java "$JAVAC_SRC/io/flutter/plugins/"
cp "$HOME/.pub-cache/hosted/pub.dev/jni-1.1.0/android/src/main/java/com/github/dart_lang/jni/JniPlugin.java" "$JAVAC_SRC/com/github/dart_lang/jni/"
# SharedPreferencesPlugin Kotlin sources (v2.5.0) + DataStore polyfill.
cp ~/apkbuild/src/io/flutter/plugins/sharedpreferences/*.kt "$JAVAC_SRC/io/flutter/plugins/sharedpreferences/"
cp ~/apkbuild/src/androidx/datastore/preferences/PreferenceDataStoreDelegatePolyfill.kt "$JAVAC_SRC/androidx/datastore/preferences/"
# NOTE: NO sqflite / JniFlutterPlugin sources anymore (cached_network_image removed;
# registrant no longer references them).
# Curated classpath from the previously verified build (~/apkbuild/classpath.txt).
# Do NOT glob ~/apkbuild/libs/*.jar: it contains corrupt 554-byte placeholder
# jars (e.g. annotation-1.8.1.jar, "zip END header not found") that break kotlinc.
CP="$(cat ~/apkbuild/classpath.txt)"
# Compile Kotlin first, then Java (registrant references Kotlin plugin class).
"$HOME/sdkdl/kotlin/kotlinc/bin/kotlinc" -jvm-target 17 -cp "$CP" \
  -d "$WORK/dex-classes" \
  "$JAVAC_SRC/io/flutter/plugins/sharedpreferences/"*.kt \
  "$JAVAC_SRC/androidx/datastore/preferences/PreferenceDataStoreDelegatePolyfill.kt" > "$WORK/kotlinc.log" 2>&1 || { cat "$WORK/kotlinc.log"; exit 1; }
javac -source 17 -target 17 -cp "$CP:$WORK/dex-classes" -d "$WORK/dex-classes" \
  "$JAVAC_SRC/com/kingcric/app/MainActivity.java" \
  "$JAVAC_SRC/io/flutter/plugins/GeneratedPluginRegistrant.java" \
  "$JAVAC_SRC/com/github/dart_lang/jni/JniPlugin.java" > "$WORK/javac.log" 2>&1 || { cat "$WORK/javac.log"; exit 1; }
# d8 cannot take a raw classes dir (kotlinc's META-INF/*.kotlin_module
# makes it fail with "Unsupported source file type"); jar it first.
(cd "$WORK/dex-classes" && jar cf "$WORK/app-classes.jar" .)
D8_INPUTS="$WORK/app-classes.jar"
for J in $(echo "$CP" | tr ':' ' '); do
  case "$J" in
    *android.jar) ;; # passed via --lib, not as input
    *) D8_INPUTS="$D8_INPUTS $J" ;;
  esac
done
# shellcheck disable=SC2086
"$BT/d8" --release --output "$WORK/dex-out" --lib "$SDK/platforms/android-36/android.jar" \
  $D8_INPUTS > "$WORK/d8.log" 2>&1 || { cat "$WORK/d8.log"; exit 1; }
cp "$WORK/dex-out/classes.dex" "$WORK/classes.dex"
echo "classes.dex: $(stat -c%s "$WORK/classes.dex") bytes"

echo "== [5/7] aapt2 compile/link resources (NEW Crown+Bat-Ball icons) =="
# Gradle normally injects package= + applicationName + versionCode/Name
# from build.gradle.kts (which reads pubspec 1.0.0+1); the manual
# pipeline must do all of them itself (aapt2 requires package=, and an
# empty versionCode breaks upgrades / Play Store checks).
# COMPAT FIX (2026-10-17): the source manifest now declares
# <uses-sdk minSdk 24 / targetSdk 36> + <supports-screens> explicitly.
# The previous manual build had NO uses-sdk, so aapt2 emitted an APK
# with no targetSdk (treated as 1) + supports-screens normal-only +
# anyDensity=false, and Android 14+ rejected it with "App isn't
# compatible with your phone". Belt-and-braces: also pass
# --min-sdk-version / --target-sdk-version to aapt2 link, and fail
# the build if the linked manifest lacks uses-sdk.
sed -e 's/\${applicationName}/android.app.Application/' \
    -e 's|<manifest |<manifest package="com.kingcric.app" android:versionCode="1" android:versionName="1.0.0" |' \
  android/app/src/main/AndroidManifest.xml > "$WORK/AndroidManifest.xml"
grep -q 'uses-sdk' "$WORK/AndroidManifest.xml" || { echo "FATAL: uses-sdk missing from manifest - aborting, would produce incompatible APK"; exit 1; }
grep -q 'supports-screens' "$WORK/AndroidManifest.xml" || { echo "FATAL: supports-screens missing from manifest - aborting"; exit 1; }
"$BT/aapt2" compile --dir android/app/src/main/res -o "$WORK/res-compiled/compiled.zip" > "$WORK/aapt2-compile.log" 2>&1 || { cat "$WORK/aapt2-compile.log"; exit 1; }
"$BT/aapt2" link -o "$WORK/base.apk" --manifest "$WORK/AndroidManifest.xml" \
  -I "$SDK/platforms/android-36/android.jar" -R "$WORK/res-compiled/compiled.zip" \
  --min-sdk-version 24 --target-sdk-version 36 \
  --auto-add-overlay --java "$WORK/gen" > "$WORK/aapt2-link.log" 2>&1 || { cat "$WORK/aapt2-link.log"; exit 1; }

echo "== [6/7] assemble + zipalign + sign (universal + 3 splits) =="
python3 - "$WORK" "$OUT" <<'PY'
import sys, zipfile, os, shutil
work, out = sys.argv[1], sys.argv[2]
base = zipfile.ZipFile(os.path.join(work, "base.apk"))
base_entries = {n: base.read(n) for n in base.namelist()}
dex = open(os.path.join(work, "classes.dex"), "rb").read()
assets_root = os.path.join(work, "flutter_assets")
asset_files = []
for root, _, files in os.walk(assets_root):
    for f in files:
        full = os.path.join(root, f)
        rel = os.path.relpath(full, work)
        asset_files.append((rel, full))
def build(apk_name, abis):
    tmp = os.path.join(work, "apk-tmp", apk_name)
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    with zipfile.ZipFile(tmp, "w") as z:
        for n, data in base_entries.items():
            z.writestr(n, data, compress_type=zipfile.ZIP_DEFLATED)
        z.writestr("classes.dex", dex, compress_type=zipfile.ZIP_DEFLATED)
        for rel, full in sorted(asset_files):
            z.write(full, rel, compress_type=zipfile.ZIP_DEFLATED)
        for abi in abis:
            for lib in ("libflutter.so", "libapp.so", "libdartjni.so"):
                p = os.path.join(work, "libs", abi, lib)
                z.write(p, f"lib/{abi}/{lib}", compress_type=zipfile.ZIP_STORED)
    return tmp
combos = {
    "app-release-universal.apk": ["armeabi-v7a", "arm64-v8a", "x86_64"],
    "app-arm64-v8a-release.apk": ["arm64-v8a"],
    "app-armeabi-v7a-release.apk": ["armeabi-v7a"],
    "app-x86_64-release.apk": ["x86_64"],
}
for name, abis in combos.items():
    print("assembled", name, abis, "->", build(name, abis))
PY
for APK in app-release-universal app-arm64-v8a-release app-armeabi-v7a-release app-x86_64-release; do
  "$BT/zipalign" -f -P 16 4 "$WORK/apk-tmp/$APK.apk" "$OUT/$APK.apk"
  "$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android \
    --key-pass pass:android --ks-key-alias "$KEY_ALIAS" \
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
    --out "$OUT/$APK-signed.apk" "$OUT/$APK.apk" 2>&1 | tail -n 3
  mv "$OUT/$APK-signed.apk" "$OUT/$APK.apk"
  rm -f "$OUT/$APK.apk.idsig"
  echo "$APK: $(stat -c%s "$OUT/$APK.apk") bytes sha256=$(sha256sum "$OUT/$APK.apk" | cut -d' ' -f1)"
done

echo "== [7/7] verify =="
for APK in app-release-universal app-arm64-v8a-release app-armeabi-v7a-release app-x86_64-release; do
  echo "--- $APK ---"
  "$BT/apksigner" verify --verbose "$OUT/$APK.apk" 2>&1 | grep -E "Verifies|Verified using"
  "$BT/zipalign" -c -P 16 4 "$OUT/$APK.apk" && echo "zipalign OK"
  "$BT/aapt2" dump badging "$OUT/$APK.apk" 2>&1 | tee "$WORK/$APK-badging.txt" | grep -E "package:|minSdkVersion|targetSdkVersion|native-code|launchable-activity|application-label|supports-screens|supports-any-density"
  # COMPAT gate: fail if minSdk/targetSdk missing (would be incompatible on Android 14+)
  grep -q "minSdkVersion:'24'" "$WORK/$APK-badging.txt" || { echo "FATAL: $APK missing minSdk 24"; exit 1; }
  grep -q "targetSdkVersion:'36'" "$WORK/$APK-badging.txt" || { echo "FATAL: $APK missing targetSdk 36"; exit 1; }
  grep -q "supports-any-density: 'true'" "$WORK/$APK-badging.txt" || { echo "FATAL: $APK supports-any-density not true"; exit 1; }
  python3 -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); print('zip test:', z.testzip()); print('mipmap:', sorted(n for n in z.namelist() if 'mipmap' in n)); print('libs:', sorted(n for n in z.namelist() if n.startswith('lib/')))" "$OUT/$APK.apk"
done
echo "BUILD DONE"
