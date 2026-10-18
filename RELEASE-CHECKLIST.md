# KingCric — Release Go / No-Go Checklist

> **One rule: a single NO-GO blocks submission.** Do not submit to Play
> Console until all 20 items are GO. This checklist is the release gate;
> `PLAYSTORE-RELEASE.md` is the detail behind it.
>
> Current build state (2026-10-18, Squad H audit): version `1.0.0+2`
> (versionCode **2**), debug-signed sideload APKs only, **no AAB yet**,
> **no release keystore**, privacy-policy URL TODO, support email TODO,
> $25 Google developer fee not yet paid. Nothing below is GO until it is
> verified on the **exact build that ships**, not on an earlier APK.

## How to use this checklist

- Check each item against the **release-signed AAB-derived APK on a real
  phone (Realme GT 6T)** — never against a debug build, a web build, or
  a previous APK.
- Record the shipped commit SHA, versionCode, AAB sha256, and test date
  in the "Release record" section at the bottom.
- If any item is NO-GO, stop. Fix it, bump versionCode, rebuild, and
  re-run the full checklist — never patch the checklist to pass.

## The 20 gates

### Data truth (the app's core promise)

- [ ] **1. One status truth — GO / NO-GO.**
  Every match appears in exactly one tab: live matches in Live, not-started
  in Upcoming, finished in Finished. A match with scores on the board and
  no result is Live even if a provider's label says "scheduled". Verified
  with a live match open on the phone (the Austria Women "live-as-Upcoming"
  case from V3 must not regress).
- [ ] **2. Real data labels — GO / NO-GO.**
  Every match card shows its source (`Source: CricAPI / … / Demo`). Every
  player profile shows one honest source line (`Real • Cricsheet •
  N matches`, `Demo`, or `Partial`). No card, profile, or table presents
  demo/curated data as real, complete, or live-verified.
- [ ] **3. No fake data — GO / NO-GO.**
  No invented scores, stats, rankings, fantasy points, weather, pitch
  reports, or predictions. Anything a free provider does not supply shows
  an honest "Not available" message, never a plausible-looking fake
  number. No "Complete" badge on demo or partial data.
- [ ] **4. Scorecard is real and complete — GO / NO-GO.**
  Opening a live or finished match shows the full scorecard (batting,
  bowling, extras, fall of wickets, partnerships, yet-to-bat) fetched
  from the provider. An upcoming match honestly says "Scorecard not
  available yet" with Retry. No blank scorecard on a started match.
- [ ] **5. Live + Upcoming + Recent all populated — GO / NO-GO.**
  With the network on and quota available, Live shows live matches (or an
  honest empty state when none are live), Upcoming shows paginated
  fixtures beyond the first page, Recent shows finished matches. No tab
  is empty because of a fetch/pagination bug.

### App correctness

- [ ] **6. No crash, no freeze — GO / NO-GO.**
  Every screen opened on the real phone: Home (all 3 tabs + format chips),
  Match Detail (Live / Scorecard / Squad / Venue & H2H / Prediction),
  Player Profile, Compare, Stats, Leagues, Favourites. No crash, no
  infinite spinner, no blank screen. Airplane mode shows cached data +
  "Last updated", never a blank screen or crash.
- [ ] **7. No truncation, no garbled names — GO / NO-GO.**
  Full "KingCric" in the header (never "King..."). Tabs never wrap
  mid-word ("Upcomin g"). Team names Title Case, one team per row, never
  comma-joined ("TeamA,TeamB"), never "Inning 1" as a team name, never
  lowercase team names. Match titles wrap to at most 2 lines, never cut
  mid-word.
- [ ] **8. Hindi toggle works — GO / NO-GO.**
  Switching EN ↔ हिं switches the app's labels. (Full Hindi parity for
  deep content is a known gap — see `PLAYSTORE-RELEASE.md`; do not claim
  full parity in the listing until it is verified.)
- [ ] **9. Predictions stay honest — GO / NO-GO.**
  Prediction shows the model's inputs and the disclaimer "Prediction is
  a model, not a guarantee. For information & entertainment only. Not
  betting advice." No betting/gambling language anywhere ("bet", "odds",
  "tips to win money"). No fake ~50 score when there is no signal —
  "Not enough data to predict." instead.

### Build quality

- [ ] **10. `flutter analyze` clean — GO / NO-GO.**
  `flutter analyze` reports "No issues found!" on the exact commit that
  ships. Record the commit SHA.
- [ ] **11. `flutter test` passing — GO / NO-GO.**
  Full test suite passes on the exact commit that ships. No skipped
  tests hiding a known failure; any skip is documented with a reason.
- [ ] **12. ONE verified Gradle AAB — GO / NO-GO.**
  The shipped artifact is an **AAB** (not an APK) built by the official
  Gradle path in GitHub Actions, **release-signed** with the release
  keystore (never debug-signed). `bundletool` + `aapt2 dump badging`
  confirm package `com.kingcric.app`, the bumped versionCode, minSdk 24,
  targetSdk 36, and 2 permissions only. The AAB's sha256 is recorded.
- [ ] **13. versionCode bumped — GO / NO-GO.**
  versionCode is **greater than every previously submitted versionCode**
  (current: 2). Play rejects a re-upload with the same versionCode.
  `pubspec.yaml` version and `aapt2 dump badging` agree.
- [ ] **14. Installed icon + launch — GO / NO-GO.**
  The release-signed build installed on the real phone shows the
  Crown + Bat-Ball icon (not the Flutter default) and launches to Home
  with no startup crash loop.

### Listing + policy (Play Console)

- [ ] **15. Privacy-policy URL live — GO / NO-GO.**
  `PRIVACY-POLICY.md` is published at a stable public URL, and that URL
  is pasted into Play Console → Policy → Privacy policy. The URL loads
  in a browser with no sign-in. Support email in the policy is a real,
  monitored inbox.
- [ ] **16. Screenshots from the release build — GO / NO-GO.**
  At least 5 phone screenshots (Home–Live, Scorecard, Player Profile,
  Compare, Stats/Leagues) captured from the **release-signed** build on
  the real phone, with real/labelled data. No ad placeholder, no fake
  "Complete", no truncation, no other app's branding, no betting imagery.
  Feature graphic 1024 × 500 exported per `PLAYSTORE-RELEASE.md` §4.
- [ ] **17. Listing text honest — GO / NO-GO.**
  Title (30 chars), short description (≤ 80 chars), and full description
  match `PLAYSTORE-RELEASE.md` §§1–2. No "faster than TV", no "full
  careers for every player", no push-notification claims, no real-ads
  claims — unless that feature is actually in the shipped build.
- [ ] **18. Declarations match reality — GO / NO-GO.**
  Data safety form: no personal data collected. "Contains ads": **No**
  until a real AdMob unit ID ships, then **Yes** with the policy updated
  first. Content rating: Everyone. Category: Sports. Price: Free, no
  in-app purchases. Target audience: general audience, not "Designed
  for families".

### Account + rollout

- [ ] **19. Developer account ready — GO / NO-GO.**
  Google Developer account exists, $25 one-time fee paid, identity
  verification complete. Release keystore + passwords are in the Secure
  Vault (never in git, never in chat); SHA-1/SHA-256 fingerprints
  recorded. `key.properties` is gitignored and present in CI secrets.
- [ ] **20. Staged rollout plan — GO / NO-GO.**
  First submission goes to the **closed (internal) testing track**,
  then open testing, then production — never straight to production on
  v1. Production rollout is staged (10% → 50% → 100%) with crash
  monitoring, and the sideload APK link stays available as a fallback
  for the first week.

## Release record (fill in at ship time)

| Field | Value |
|---|---|
| Commit SHA shipped | `[TODO]` |
| versionCode / versionName | `[TODO]` (must be > 2) |
| AAB sha256 | `[TODO]` |
| AAB size (bytes) | `[TODO]` |
| Tested on | Realme GT 6T, Android 14, `[TODO: date]` |
| Privacy-policy URL | `[TODO]` |
| Support email | `[TODO]` |
| Play Console track | closed → open → production |
| "What's new" text | See `PLAYSTORE-RELEASE.md` §10 |

## Known gaps that block a GO (do not hide these)

- Release keystore: **not created** (see `PLAYSTORE-RELEASE.md` §9a).
- AAB build job: **not implemented** — current workflow builds APK only
  (see Workflow audit in `PLAYSTORE-RELEASE.md` §12).
- Privacy-policy URL: **TODO** — policy text exists (`PRIVACY-POLICY.md`),
  hosting does not.
- Support email: **TODO** — must be a real monitored inbox.
- $25 Google developer fee: **not yet paid** (unavoidable, charged by Google).
- Full Hindi parity for deep content: **not verified** — do not claim it
  in the listing until verified.
- Background updates when the app is closed (WorkManager/FCM) and real
  push notifications: **not in the build** — do not claim them.
- Real AdMob ads: **not in the build** — placeholder renders nothing;
  "Contains ads" stays No until a real unit ID ships.
