# KingCric — Final Release: exact submission steps

> **Status (2026-10-24, Final R):** version `1.0.0+3` (versionCode **3**).
> The Play Store artifact job exists (`.github/workflows/build-aab.yml`):
> official Gradle AAB, release-signed via secrets, bundletool-verified,
> with a release-signer guard. The job has **not yet run green on a
> runner** — that run is required before anything below is GO.
> The release gate is `RELEASE-CHECKLIST.md` (20 gates, one NO-GO blocks
> submission). This file is the step-by-step path to that gate.

## What is already done (no user action needed)

- **AAB workflow** (`.github/workflows/build-aab.yml`): same Flutter 3.47.7
  / Java 17 / SDK 36 / NDK 28.2 setup as the APK job; `flutter analyze`
  + `flutter test` must pass; `flutter build appbundle --release` with
  the same `--dart-define` provider keys as the APK job.
- **Release signing, fail-fast:** the job checks all 4 secrets are set
  before building, decodes the keystore on the ephemeral runner only,
  and refuses to produce an artifact if any secret is missing.
- **CI-time signing patch:** the repo's `android/app/build.gradle.kts`
  still wires release to the debug signing config. The workflow patches
  the runner's copy only (key.properties-based `release` signingConfig);
  if the repo file is ever wired properly, the patch skips itself. The
  repo file was deliberately NOT edited by Final R.
- **Verification:** bundletool (pinned 1.18.1) builds a universal APK set
  from the AAB; aapt2 badging must show `com.kingcric.app`, minSdk 24,
  targetSdk 36, INTERNET + ACCESS_NETWORK_STATE; and the universal APK's
  signer certificate must match the release keystore's certificate —
  this guard is what stops a debug-signed AAB from slipping through.
- **Privacy-policy page:** `docs/privacy-policy.html` is a standalone,
  self-contained rendering of `PRIVACY-POLICY.md` — same claims, no new
  claims. It is ready to host; hosting itself is user-side item 3.
- **Version bumped:** `pubspec.yaml` `1.0.0+2` → `1.0.0+3`
  (versionCode 3, greater than every previously shipped build).

## The ONLY 3 user-side items remaining

Nothing else needs the user. In particular: no code, no keystore file,
and no money is handled by the assistant — these three are the user's
because they involve the user's money, the user's secret material, and
the user's public contact/hosting.

### 1. $25 Google developer fee (charged by Google, unavoidable)

- Create a Google Developer (Play Console) account and pay the **$25
  one-time fee**. This is Google's charge, not the app's — there is no
  free route to a Play Store listing, and the assistant cannot pay it
  for you.
- Complete Play's identity verification after payment. Until this is
  done, nothing can be submitted, however ready the build is.

### 2. Release keystore + its 4 GitHub secrets (passwords NEVER in chat/git)

- On your own machine, create ONE upload keystore (keep the file and
  the passwords safe — **losing them means the app can never be updated
  under package `com.kingcric.app` again**):
  `keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kingcric`
- Back up `upload-keystore.jks` somewhere safe and private (NOT in the
  repo, NOT in chat).
- In the repo: Settings → Secrets → Actions, add exactly these 4
  secrets (values only, never printed anywhere):
  `RELEASE_KEYSTORE_BASE64` (base64 of the `.jks` file),
  `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.
- Passwords must go to the Secure Vault / GitHub secrets only. If a
  password ever appears in chat, git, or a log, rotate it and re-issue
  the secrets.

### 3. Support email + enabling Pages for the policy URL

- **Support email:** a real, monitored inbox. Replace
  `[TODO: support email]` in BOTH `PRIVACY-POLICY.md` and
  `docs/privacy-policy.html`, and use the same address in Play Console.
- **Policy URL:** enable GitHub Pages for the KingCric repo with source
  `/docs` (Settings → Pages → Deploy from a branch → `main` → `/docs`),
  then confirm `https://monsterbhaiya09-design.github.io/KingCric/privacy-policy.html`
  loads in a browser with no sign-in. Replace `[TODO: policy URL]` in
  both policy files with that URL, and fill `[TODO: date]`.
- Until the URL is live, Play Console will not accept the listing —
  the policy URL is a hard requirement, not a nice-to-have.

## Exact submission steps (after the 3 items above)

1. **Push + watch the AAB job.** Push the Final R files; the AAB
   workflow runs on `main`. Wait for a green run (the APK job also runs;
   both must be green). If the AAB job fails fast on secrets, fix the
   secrets — do not bypass the check.
2. **Download + record the AAB.** From the green run, download artifact
   `kingcric-app-release-aab`. Record its sha256 + size + the commit
   SHA in `RELEASE-CHECKLIST.md` → Release record.
3. **Sanity-install the AAB-derived build on the real phone.**
   (Play's internal testing track installs it; alternatively generate a
   universal APK from the AAB with bundletool locally and install that
   for a smoke check.) Confirm: Crown + Bat-Ball icon, Home loads, one
   live/finished match opens with a full scorecard, Squad + Venue &amp;
   H2H show real data, no crash, no truncation.
4. **Play Console → Create app.** Package `com.kingcric.app`, title,
   category Sports, Free, no in-app purchases, content rating Everyone,
   target audience general (not "Designed for families").
5. **Upload the AAB to the closed (internal) testing track first**
   — never straight to production on v1.
6. **Fill the listing honestly:** title/short/full description per
   `PLAYSTORE-RELEASE.md` §§1–2 (no "faster than TV", no "full careers
   for every player", no push-notification claims, no ads claims);
   paste the live policy URL; data-safety form = no personal data
   collected, "Contains ads": **No**; upload ≥ 5 screenshots from the
   release-signed build + the 1024 × 500 feature graphic.
7. **Run the 20-gate checklist** (`RELEASE-CHECKLIST.md`) against the
   exact shipped build. One NO-GO = stop, fix, bump versionCode,
   rebuild, re-run — never patch the checklist to pass.
8. **Roll out staged:** closed testing → open testing → production at
   10% → 50% → 100%, watching for crashes. Keep the sideload APK link
   available as a fallback for the first week.

## What must NEVER happen

- Never submit a debug-signed build (the AAB job's signer guard exists
  for exactly this).
- Never put the keystore, its base64, or any password in git, chat, a
  log, or an issue.
- Never claim in the listing what the build does not do: no push
  notifications, no background updates, no real ads, no full Hindi
  parity for deep content — until those are actually in the shipped
  build and the policy/listing are updated first.
- Never reuse a versionCode. Every submission bumps it.
