# Privacy Policy — KingCric

> **Paste-ready policy for the Play Store listing.**
> Hosting is still TODO: publish this file at a stable public URL and paste
> that URL into Play Console → Policy → Privacy policy. The listing
> **cannot** be submitted without a live policy URL.
>
> Placeholders to fill before submission: `[TODO: support email]`,
> `[TODO: policy URL]`, `[TODO: last updated date]`.
> This policy is a plain-language draft written for this app's actual
> behaviour. It is not legal advice — have it reviewed before submission
> if the app ever adds accounts, analytics, ads, or payments.

**App:** KingCric — Live Cricket Scores
**Package:** `com.kingcric.app`
**Developer contact:** `[TODO: support email]` (must be a real, monitored inbox)
**Policy URL:** `[TODO: policy URL]`
**Last updated:** `[TODO: date, e.g. 2026-10-18]`

---

## 1. Summary

KingCric is a cricket scores and statistics app. It **collects no personal
data**. It requires no account, no sign-in, and no name, email, phone
number, contacts, location, or files from you. Your favourites and app
preferences live **only on your device**. Uninstalling the app deletes
them.

## 2. What we collect

**Nothing personal. Specifically, KingCric does NOT collect, store, or
share any of the following:**

- Your name, email address, phone number, or any account identifier.
- Your contacts, call history, messages, photos, or files.
- Your precise or approximate location.
- Your device advertising identifier (no ads SDK is in the current build).
- Your browsing history or activity in other apps.

KingCric has no user accounts and no server-side user database. There is
no account to create, and therefore no account data to leak, sell, or
delete.

## 3. What stays on your device

The following are stored **only on your device** (via the app's local
preferences storage) and are never sent to us or to any third party:

- **Favourites:** the teams and players you follow.
- **Preferences:** your language choice (Hindi / English) and any
  notification preferences you set in the app.
- **Cache:** recently fetched match/score data, kept so the app can show
  you the last verified data when you are offline. The cache is
  temporary and is cleared when you clear the app's data or uninstall.

Because this data never leaves your device, we cannot see it, back it
up, or restore it for you.

## 4. Permissions the app requests — and why

KingCric requests **exactly two** Android permissions:

| Permission | Why it is needed | What it does NOT do |
|---|---|---|
| `INTERNET` | Fetch live scores, scorecards, series, and player data from the cricket data providers listed in §5. | Does not upload personal data — there is none to upload. |
| `ACCESS_NETWORK_STATE` | Check whether the device is online before fetching, so the app can show cached data gracefully when offline. | Does not read Wi-Fi names, network content, or location. |

KingCric does **not** request location, contacts, camera, microphone,
storage, or notification permissions in the current build. If a future
version adds push notifications, it will request the notification
permission at that time, only after you opt into notifications, and this
policy will be updated first.

## 5. Data sources and third-party services

### Cricket data providers

Live scores, scorecards, series, and fixtures come from documented
**free cricket data provider APIs** — primarily **CricAPI /
CricketData.org**, with free backstop providers (see `API-SETUP.md`).
Deep player statistics are **calculated by KingCric from Cricsheet
open ball-by-ball data** and labelled in the app with the dataset size
(e.g. "Real • Cricsheet • 420 matches").

When the app fetches data, it sends the provider only what the provider
needs to answer — a match ID, a player ID, or a search term. It sends
**no personal data**. As with any internet request, the provider's
server necessarily sees the connecting device's IP address when it
receives the request; KingCric does not add any identifier to that
request. Each provider's own privacy policy governs its handling of
such requests.

KingCric **never scrapes** Cricbuzz, Cricinfo, Crex, Cricmetrics, or
any other app or website. It uses only documented APIs and open data.

### What KingCric does NOT use

- **No analytics SDK.** KingCric does not measure or report your usage.
- **No crash-reporting SDK.** Crash reports are not collected.
- **No push-notification service (FCM).** There is no background
  messaging in the current build.
- **No AdMob / no ads SDK in the current build.** The current build
  shows **no advertisements** — its ad placeholder renders nothing.

### If ads are ever added (AdMob)

If a future version enables Google AdMob, that version will:

- Declare **"Contains ads: Yes"** in the Play Store listing before release.
- Update this policy to state that Google AdMob may collect device and
  advertising identifiers as described in Google's own policies.
- Keep all other statements in this policy unchanged (still no account,
  still no personal data collected by KingCric itself).

Until such an update is published here, treat this policy's statement
as authoritative: **no ads, no AdMob, no advertising identifiers.**

## 6. Predictions, betting, and gambling

KingCric's match predictions are **statistical models** (recent form,
vs-opponent record, venue, matchup, pitch) shown for information and
entertainment only. They are not betting advice, not a guarantee, and
not a promise of any outcome.

**KingCric does not offer, facilitate, or promote betting, gambling,
or wagering of any kind.** It contains no betting features, no odds,
and no links to betting services.

## 7. Children

KingCric is a general-audience sports-scores app. Because it collects
no personal data from anyone — including children — there is no
children's data to protect, retain, or delete. The app's content is
sports scores and statistics; it contains no gambling, no chat, and no
user-generated content.

## 8. Data retention and deletion

- **Server-side:** nothing is retained, because nothing is collected.
- **On-device:** favourites, preferences, and cached match data remain
  on your device until you clear the app's data or **uninstall the app**,
  which removes them.
- **No deletion request is needed** — there is no account and no
  server-side personal data to delete. If you contact us about data,
  we will confirm the above and close the request.

## 9. Data safety (Play Store data-safety form)

Consistent with this policy, KingCric's Play Store data-safety
declaration is:

- **Personal data collected:** none.
- **Data shared with third parties:** none (provider API calls carry no
  personal data — see §5).
- **Advertising ID:** not collected (no ads SDK in the current build).
- **Data encrypted in transit:** all provider API calls use HTTPS.
- **Account / data deletion:** not applicable — no account, no
  server-side data; uninstall removes on-device data.

If AdMob, analytics, crash reporting, or push notifications are ever
added, the data-safety form and this policy will be updated **before**
that version is released.

## 10. Security

KingCric sends no personal data over the network, so there is no
personal data in transit to intercept. Provider API calls use HTTPS.
API keys used for provider calls are build-time configuration, never
user data, and are never shown in the app.

## 11. Changes to this policy

If this policy changes, the current version will always be at the
policy URL on the Play Store listing. Material changes (for example,
adding ads, analytics, or notifications) will be reflected here
**before** the version that introduces them is released. The "Last
updated" date at the top records the latest change.

## 12. Contact

Questions about this policy: `[TODO: support email]`.

---

*End of policy. Keep the placeholders filled and the URL live before
submitting the Play Store listing. Do not ship a build whose behaviour
contradicts this policy (e.g. do not enable AdMob without updating
§5/§9 and the "Contains ads" declaration first).*
