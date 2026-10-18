# KingCric — Play Store Release Pack

> Status: **DRAFT — NOT READY TO UPLOAD YET.**
> This document is the listing + release checklist for the future Play Store
> submission. Do NOT submit until every item in §9 is checked.
>
> Source of truth for app identity:
> - Package: `com.kingcric.app`
> - Current version: `1.0.0+2` (versionCode **2**, versionName `1.0.0`)
> - `minSdk 24` (Android 7.0+) / `targetSdk 36` / `compileSdk 36`
> - Permissions in manifest: **2 only** — `INTERNET`, `ACCESS_NETWORK_STATE`
> - Theme: dark navy `#0B1026` + gold `#D4AF37`, Crown + Bat-Ball logo
> - Tagline: **"Har Ball, Har Stat, King Jaisa."**
> - Data policy: **never** scrapes Cricbuzz / Cricinfo / Crex / Cricmetrics.
>   Live data only from documented free provider APIs; deep player stats
>   calculated from Cricsheet open ball-by-ball data. See `API-SETUP.md`
>   and `CRICSHEET-DATA.md`.

---

## 1. Listing — title, short description, category

| Field | Value | Limit / rule |
|---|---|---|
| App name (Play listing title) | `KingCric – Live Cricket Scores` | Play Store title limit is **30 chars** — this is exactly 30. Do not lengthen it. |
| Package | `com.kingcric.app` | Must never change after first release. |
| Category | **Sports** | |
| Tags (Play) | `Cricket`, `Live Scores`, `Cricket Stats` | Pick from Play's offered tags; do not invent new ones. |
| Content rating | **Everyone** (self-declared via Play rating questionnaire) | No violence, no gambling, no real-money betting. Prediction is a statistical model, not betting advice — see disclaimer in §3. |
| Price | **Free** | No in-app purchases in v1. No paywall. |
| Contains ads? | **Yes, when AdMob ships — No, in the current build.** | Current build has an `AdPlaceholder` that renders **nothing** when no AdMob unit ID is set. Do NOT tick "Contains ads" until a real AdMob unit ID is wired in, then flip it to Yes and update the privacy policy (§6). |

### Short description (≤ 80 chars — this draft is 73 chars)

```
Live cricket scores, deep player stats & predictions. Har Ball, Har Stat.
```

Verify before submitting: paste into Play Console and confirm the
character counter stays ≤ 80. Do not add emojis to the short description.

### Keywords (for Play search + description, NOT a keyword-stuffing block)

`live cricket score`, `cricket live score`, `cricket stats`, `player stats`,
`cricket prediction`, `IPL live score`, `T20 live score`, `cricket H2H`,
`venue stats`, `cricket compare`, `Hindi cricket app`

Do NOT put a keyword list inside the visible description — Play rejects
keyword-stuffed listings. Keywords belong in the description naturally
(see §2) and in Play's search-optimisation fields.

---

## 2. Full description (paste-ready draft — ≤ 4000 chars)

> **KingCric — Har Ball, Har Stat, King Jaisa.** 👑🏏
>
> Live cricket scores, full scorecards, and deep player analytics — in one
> clean app, in Hindi and English.
>
> **LIVE SCORES & FULL SCORECARD**
> • Live, upcoming, and recent matches — international, IPL, PSL, Big Bash,
>   T10, and domestic cricket.
> • Full scorecard: batting (runs, balls, 4s, 6s, strike rate, how out),
>   bowling (overs, maidens, runs, wickets, economy, wides, no-balls),
>   extras, fall of wickets, partnerships, yet-to-bat.
> • Target & equation for chases ("need X runs in Y balls"), toss, venue,
>   pitch report, and umpires.
>
> **DEEP PLAYER ANALYTICS**
> • Player profiles: career stats, format-wise (Test / ODI / T20 / T10),
>   vs-opponent, venue records, league splits, recent form.
> • Bowler-vs-batter matchups and dismissal history — who got whom out,
>   how many times, and who has never dismissed whom.
> • Team head-to-head and player head-to-head.
>
> **COMPARE & PREDICTION**
> • Compare two players side-by-side — batting + bowling, same formats.
> • Match prediction with a clear reason in Hindi / English. Prediction is
>   a statistical model (recent form, vs-opponent, venue, matchup, pitch),
>   not a guarantee. KingCric does not offer betting or gambling.
>
> **FAVOURITES & LANGUAGE**
> • Follow your favourite teams and players.
> • Switch the whole app between Hindi and English.
>
> **HONEST DATA**
> • Live scores come from documented free cricket APIs (CricAPI /
>   CricketData.org and backstops). Live data is cached and refreshed on
>   a quota-safe schedule — see "Last updated" in the app.
> • Deep player stats are calculated from Cricsheet open ball-by-ball
>   data and labelled with the dataset size. Demo / partial data is
>   always labelled "Demo" — never presented as complete.
> • KingCric never scrapes Cricbuzz, Cricinfo, Crex, or Cricmetrics.
>
> **FREE, LIGHT, PRIVATE**
> • Free to use — full version for every user, no paywall.
> • Only 2 permissions: Internet + Network State. No contacts, no
>   location, no storage access.
> • No account required.
>
> Made for cricket fans who want every ball and every stat — King style.

**What this description deliberately does NOT claim** (do not add these
claims — they would be false for the current build):

- ❌ "Ball-by-ball every second / faster than TV" — free-tier live data is
  **10-minute cached**, not sub-second. The honest claim is "fast, honest
  live scores" + "Last updated" in-app.
- ❌ "Full career stats for every player" — bundled Cricsheet sample is
  **4 matches**; numbers are real-over-the-sample, labelled with dataset
  size, not full careers. Full-career numbers need the full-dataset
  refresh (see `CRICSHEET-DATA.md` §7).
- ❌ "Push notifications" / "background updates when closed" — FCM +
  WorkManager are **planned, not in this build**. Favourites stores
  local reminder preferences only.
- ❌ "Real ads" — AdMob is a placeholder until a real unit ID is set.

---

## 3. Disclaimers to include (listing + in-app)

1. **No betting / gambling:** "KingCric is for information and
   entertainment only. Predictions are statistical models, not betting
   advice. KingCric does not provide, facilitate, or promote betting,
   gambling, or wagering."
2. **Data freshness:** "Live scores are refreshed on a quota-safe
   schedule. Check 'Last updated' in the app for freshness."
3. **Source labels:** in-app labels (`Real • Cricsheet open data`,
   `Demo`, `Partial`) are the source of truth; the listing must not
   contradict them.

---

## 4. Graphics — screenshots + feature graphic + icon

### App icon (already in repo)

- Crown + Bat-Ball logo, navy + gold.
- Must match `android/app/src/main/res/mipmap-*/ic_launcher.png`
  (48 / 72 / 96 / 144 / 192 px). Verify on a real device that the
  installed icon is the Crown + Bat-Ball, not the default Flutter icon
  (the wrong-icon bug from 2026-10-17 must not regress).

### Feature graphic — 1024 × 500 px (required)

- Background: dark navy `#0B1026` gradient (same as app hero).
- Left: Crown + Bat-Ball logo (gold `#D4AF37`) + `KingCric` wordmark.
- Centre/right: tagline **"Har Ball, Har Stat, King Jaisa."** in white/gold.
- Optional small strip: "Live Scores • Full Scorecard • Player Stats".
- **Do NOT** put: screenshots inside the feature graphic, fake scores,
  betting references, other apps' logos, or a phone frame that clips text.
- Export as PNG or JPG, exactly 1024 × 500. Keep a source file
  (Figma / SVG) in the repo under `assets/store/` when created.

### Screenshots (Play requires ≥ 2, recommend 5 — phone, portrait)

Capture on a **real phone (Realme GT 6T)** at the device's native
resolution, with the **release-signed** build (not a debug build), in
English, with **real / labelled data** (no "Ad placeholder", no fake
"Complete" on demo data, no truncated "King..."):

| # | Screen | What must be visible | What must NOT be visible |
|---|---|---|---|
| 1 | Home — Live | Live match card, LIVE pill, score + overs + equation, Live/Upcoming/Recent tabs | No "No matches" when a live match exists; no Upcoming pill on a live match |
| 2 | Match Detail — Scorecard | Full batting + bowling + extras + FOW + partnerships + yet-to-bat, hero score | No clipped columns; no comma-joined team names; no lowercase team names |
| 3 | Player Profile | Header + key strip + format table + vs-opponent + venue + source label ("Real • Cricsheet open data • N matches" or "Demo") | No "Complete" on demo/curated data |
| 4 | Compare | Two players side-by-side, batting + bowling, winner highlight | No stale dropdown value; no NaN |
| 5 | Stats / Leagues | Format chips, leaders table, series points table (or honest "Table not available") | No fake table; no paywall prompt |

Additional (optional but recommended): Hindi-language screenshot (same
Home screen with हिं toggle), and a 7-inch + 10-inch tablet screenshot
set if claiming tablet support.

**Screenshot rules:** no device frame that hides content, no marketing
text that contradicts the app (no "faster than TV", no "full careers"),
no other app's branding, no betting imagery.

### Promo video (optional, skip for v1)

Do not ship a promo video for v1 — screenshots are sufficient and a
video risks showing stale UI. Add one only after the listing is stable.

---

## 5. Privacy policy (outline — must be a live URL before submission)

Play requires a **public privacy-policy URL** on the listing. This
outline is the content; hosting is still TODO (see §9).

**Privacy Policy — KingCric (draft outline)**

1. **Who we are:** KingCric (`com.kingcric.app`). Contact: `[TODO: support
   email]` (must be a real monitored inbox before submission).
2. **What we collect:** **Nothing personal.** KingCric requires no
   account, no sign-in, no name, email, phone, contacts, location, or
   files. Favourites (teams/players) and language + notification
   preferences are stored **only on the device** (SharedPreferences).
3. **Permissions:** `INTERNET` (fetch live scores / scorecards) and
   `ACCESS_NETWORK_STATE` (check connectivity). No other permissions
   are requested.
4. **Data sources:** Live scores / scorecards from documented free
   cricket provider APIs (CricAPI / CricketData.org and backstops);
   deep player stats calculated from **Cricsheet open ball-by-ball
   data**. KingCric does **not** scrape Cricbuzz, Cricinfo, Crex, or
   Cricmetrics. API keys are never shipped in the app binary as
   readable secrets beyond the build-time `--dart-define` mechanism;
   keys are stored as GitHub repo secrets for CI builds.
5. **Third-party services:**
   - Cricket data providers listed in §4 above (their own privacy
     policies apply to their API calls; KingCric sends them no
     personal data — only match/player IDs).
   - **AdMob (only when enabled):** if/when a real AdMob unit ID is
     added, Google AdMob may collect device / advertising identifiers
     per Google's policies. Current build has **no AdMob SDK and no
     ads** — the placeholder renders nothing. Update this policy the
     day AdMob ships.
   - **No analytics SDK, no crash-reporting SDK, no FCM** in the
     current build. Add a section here if/when any is added.
6. **Children:** KingCric is a general-audience sports-scores app. It
   collects no personal data from anyone, including children.
7. **Data deletion:** Nothing to delete — no account, no server-side
   personal data. Uninstalling the app removes on-device favourites /
   preferences. (Do NOT claim "data can't be deleted" — the CricketLineX
   listing does, and it is a trust liability.)
8. **Changes:** This policy may change; the current version will always
   be at the listing URL. Last updated: `[TODO: date]`.

**Hosting TODO:** publish this policy at a stable public URL (e.g.
GitHub Pages on the KingCric repo, or the developer's own site) and
paste that URL into Play Console → Policy → Privacy policy. The listing
**cannot** be submitted without it.

---

## 6. Store settings checklist

- [ ] App name: `KingCric – Live Cricket Scores` (30 chars)
- [ ] Short description (73 chars, §1)
- [ ] Full description (§2) — no false claims
- [ ] Category: Sports; Tags: Cricket / Live Scores / Cricket Stats
- [ ] Content rating questionnaire completed → **Everyone**
- [ ] Privacy policy URL live (§5)
- [ ] Support email + (optional) website URL — real, monitored
- [ ] Data safety form: **No personal data collected**; data types:
      none. If AdMob ships later, declare Advertising ID + device
      identifiers per AdMob's data-safety guidance and re-submit.
- [ ] "Contains ads": **No** until real AdMob ID ships, then **Yes**.
- [ ] Target audience: general audience, **not** primarily children
      (do not tick "Designed for families" for v1).
- [ ] Countries: all (default), unless a data provider restricts a
      territory — none currently do.
- [ ] Free, no in-app purchases, no subscriptions in v1.

---

## 7. Permissions justification (for Play review + listing)

| Permission | Why KingCric needs it | What it does NOT do |
|---|---|---|
| `INTERNET` | Fetch live scores, scorecards, series, player data from provider APIs. | Does not upload personal data; no personal data exists to upload. |
| `ACCESS_NETWORK_STATE` | Check connectivity before fetching; show offline / cached data gracefully. | Does not read Wi-Fi SSIDs, location, or network content. |

No other permissions. In particular: **no** `ACCESS_FINE_LOCATION`,
**no** `READ_EXTERNAL_STORAGE` / `READ_MEDIA_*`, **no** `POST_NOTIFICATIONS`
until FCM ships (when FCM ships, add `POST_NOTIFICATIONS` for Android 13+
with runtime prompt + justification: "deliver match notifications you
opted into").

---

## 8. What Play will reject — do NOT ship these

- Scraped data / copied content from Cricbuzz / Cricinfo / Crex /
  Cricmetrics (code, text, images, data).
- Fake "Complete" on demo / partial data; fake "faster than TV" claims.
- "Ad placeholder" / developer text in release screenshots or in-app.
- Betting / gambling features or language ("bet", "odds", "tips to win
  money"). Prediction must stay a statistical model with the §3
  disclaimer.
- Debug-signed APK / AAB. Play requires a **release-signed AAB**
  (see §9).
- Missing privacy-policy URL.
- Targeting / content-rating mismatch (e.g. claiming Everyone while
  showing gambling content).

---

## 9. Release checklist (all must be ✅ before submission)

### 9a. Build — release signing + AAB (BLOCKING)

- [ ] **Release keystore exists** (NOT the debug keystore). Current APKs
      are **debug-signed for sideloading only** — Play rejects debug
      signatures. Generate once with `keytool -genkeypair`, store the
      keystore + passwords in the Secure Vault (never in git, never in
      chat). Record the SHA-1 / SHA-256 fingerprints.
- [ ] `android/key.properties` (keystore path, alias, passwords) present
      locally / in CI secrets — **never committed**.
- [ ] `android/app/build.gradle.kts` `signingConfig` points at the
      release keystore for `release` builds.
- [ ] Build **AAB, not APK**, for Play:
      `flutter build appbundle --release [--dart-define=...]`
      (Play requires AAB; the sideload APK is a separate artifact.)
- [ ] `versionCode` bumped for **every** Play submission (current: 2).
      Play rejects a re-upload with the same versionCode. Bump
      `version` in `pubspec.yaml` (`1.0.0+2` → `1.0.0+3` or `1.0.1+3`)
      and verify `aapt2 dump badging` shows the new code.
- [ ] Verify the AAB locally: `bundletool build-apks` + install on a
      real device, or at minimum `aapt2 dump badging` on the extracted
      APK + `apksigner verify` + `zipalign -c -P 16`.
- [ ] Confirm the installed icon is Crown + Bat-Ball on the device.

### 9b. Developer account + money (BLOCKING, outside the code)

- [ ] **Google Developer account** exists — Google charges a **$25
      one-time fee (~₹2,100)**. This is charged by Google and is
      unavoidable for Play Store listing. The app itself stays 100%
      free (no paid keys, no paid SDKs); the $25 is the Play listing
      fee, not an app cost.
- [ ] Developer identity verification + (if needed) organisation
      verification completed in Play Console — Google may take days.

### 9c. Testing — real device (BLOCKING)

- [ ] Install the **release-signed AAB-derived APK** on **Realme GT 6T**
      (Snapdragon 7+ Gen 3, arm64, Android 14) via Files → Downloads
      (not WhatsApp viewer), after uninstall + restart.
- [ ] Open every screen: Home (Live / Upcoming / Recent), Match Detail
      (Live / Scorecard / Squad / Prediction), Player Profile, Compare,
      Stats, Leagues, Favourites. Confirm: no crash, no truncation
      ("King...", "Upcomin g"), no comma-joined team names, no lowercase
      team names, no "No matches" when matches exist, no ad placeholder,
      no fake "Complete".
- [ ] Confirm Live tab shows the live match (Austria W case from V3 must
      not regress), and the 20-point checklist in `REFERENCE-SPEC.md` §8
      passes.
- [ ] Confirm offline behaviour: airplane mode → cached data + "Last
      updated", no blank screen, no crash.
- [ ] Confirm Hindi toggle switches **all** labels.
- [ ] `flutter analyze` clean + `flutter test` passing on the exact
      commit that ships (record commit SHA in the release notes).

### 9d. Listing + policy (BLOCKING)

- [ ] All §6 store settings complete; privacy-policy URL live (§5);
      screenshots captured from the release build per §4; feature
      graphic 1024 × 500 exported.
- [ ] Data safety form matches reality (no personal data; ads = No until
      AdMob ships).
- [ ] Content rating = Everyone; no gambling content anywhere.

### 9e. Rollout

- [ ] First Play submission: **closed testing** (internal track) with
      1–2 testers on real devices, then **open testing**, then
      **production** — do not go straight to production on v1.
- [ ] Rollout: staged (e.g. 10% → 50% → 100%) with crash monitoring;
      keep the sideload APK link available as a fallback during the
      first week.
- [ ] After approval: verify the Play listing (title, description,
      screenshots, privacy URL, rating) matches this document; fix any
      Play review feedback in a new versionCode, never by re-uploading
      the same versionCode.

---

## 10. Release notes template (Play "What's new" — ≤ 500 chars)

```
KingCric 1.0.0 — first Play release.
Live scores, full scorecards, deep player stats, compare & prediction,
in Hindi + English. Honest source labels: Real / Demo / Partial.
Free, no paywall, 2 permissions only.
```

Keep "What's new" short, factual, and consistent with §2. Never promise
features that are not in the shipped build.

---

## 11. File map

- This file: `PLAYSTORE-RELEASE.md` (listing + release checklist)
- Data sources: `API-SETUP.md`, `MULTI-API.md`, `CRICSHEET-DATA.md`
- Reference patterns: `REFERENCE-SPEC.md`, `REFERENCE-APPS-DEEP-DIVE.md`,
  `CRICKETLINEX-REFERENCE.md`, `REQUIREMENTS-MAPPING.md`
- Premium / smoothness: `PREMIUM-SMOOTH.md`, `PLAYER-DATA-EXTRACTION.md`
- Build: `.github/workflows/build-apk.yml` (currently builds APK;
  a Play release needs an **AAB** job — add `flutter build appbundle`
  + release signing before submission; see §9a)
- Install testing: `INSTALL-GT6T.md`
