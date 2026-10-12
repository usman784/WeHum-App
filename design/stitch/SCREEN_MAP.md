# Stitch → WeHum build map (Oct 12, 2026)

Source of truth for the redesign. Every screen of the Stitch project **"WeHum UI/UX Design System"** (project `6381078414574668523`, 31 screens, exported to `stitch-export/screens` + `stitch-export/screenshots`) is listed here with the sprint it ships in, the app route that implements it, the backend contract it needs and the CMS control that feeds it.

Order of work follows `roadmap/wehum-roadmap.html` (S1 → S7). Each sprint is built **backend → CMS → app**, tested, committed locally, then the next.

## Decisions taken (these supersede app spec §1.3 and backend spec §1.2 where they differ)

| # | Old rule (Oct 5 notes) | New rule (Stitch + roadmap) | Why |
|---|---|---|---|
| D1 | "meditate / meditating", never "sit" | **"sit / sitting / sat"** on every screen the Stitch design covers; "meditation" stays for content nouns | Every Stitch screen and the roadmap use "sit" |
| D2 | No streaks, no grace days | **Forgiving streak**: one grace day per ISO week, record streak, weekly goal. Missing a day uses the grace first; a second miss in the same week resets the run. "Rest" is shown, never "failed" | Stitch Today / You / Payoff / Challenge detail; roadmap S7 |
| D3 | No 30-second previews | **30 s preview** of a locked premium meditation for free users, then the paywall sheet | Stitch preview modal; roadmap S2 |
| D4 | Intent step skipped (`features.intent=false`) | Intent + first-sit screens (`onboarding-intent-focus`, `onboarding-first-sit`) are **not built** (client dropped the 3-minute first sit in the Sprint-1 proposition). The existing intro → name → time → reminder → start flow stays | User decision |
| D5 | Group meditation = MOTD at one daily time | Group sits can also run **hourly** (`group.cadence = "hourly"`), with an intention picker and per-region waiting counts. Daily mode still works | Stitch Next-sit countdown, Together, roadmap S3 |
| D6 | "Themes" | **"Disciplines"** in copy (API/DB name stays `theme`) | Stitch Library |
| D7 | No health data | **Heart-rate shift is optional and on-device**: shown only when the user connects Apple Health / Health Connect. Server stores one number per meditation (`hrDeltaBpm`, `hrAvgBpm`), never a waveform. Feature flag `features.heartRate` (default off) | Stitch Payoff / You / Story share |
| D8 | Intent step off | Same (D4) | |
| D9 | "Coming soon" flags for Challenges | **Challenges are live** behind `features.challenges` (cohort sprints with unlock times, grace day, graduation badge) | Stitch Challenge detail |
| D10 | No telemetry vocabulary | Copy keeps Stitch's tone but **no invented numbers**: sync latency, "harmonic cadence", "autonomic" metrics are not shown unless a real source exists. Counts, minutes, streak, regions and heart-rate shift are real | Honest presence rule (spec §13) stays |

## Screen matrix

Legend: **Sprint** from the roadmap · **API** = new or changed contract (backend spec §5.6) · **CMS** = admin control.

| # | Stitch screen | Sprint | App route (file) | API | CMS |
|---|---|---|---|---|---|
| 01 | `today` | S1 | `/today` (`today_pages.dart`) | `GET /v1/today` + `streak`, `presence.regions`, `note` (daily message teaser), `continueLast`, `silenceNow` | Today screen: weekly goal default, show note; Settings: streaks flag |
| 02 | `account-creation` | S1 | `/account/save` (`account_pages.dart`) | existing `/v1/auth/*` | – |
| 03 | `sit-time-reminder` | S1 | `/setup/time` (`setup_pages.dart`) | `GET /v1/community/members-at?time=` → `{count}` (members who sit in that block) | Settings → Sit-time blocks (suggested blocks) |
| 04 | `onboarding-first-sit` | – | **not built** (D4) | | |
| 05 | `onboarding-intent-focus` | – | **not built** (D4) | | |
| 06 | `library-a` | S2 | `/library` (`library_pages.dart`) | `GET /v1/library/summary`; catalog `themes[].tracks`, `sessions[].completedToday` | Disciplines: blurb, range; Sessions: "free back-catalogue" tag |
| 07 | `library-b` | S2 | `/library` (merged with 06: B layout, A filter sheet + 30 s pass banner) | same | same |
| 08 | `session-player` | S2 | `/player` (`player_pages.dart`) | catalog `sessions[].phases[]`; `POST /v1/media/play-url` unchanged | Session editor: Phases (chapters) list |
| 09 | `preview-modal-30s` | S2 | `/preview/:id` (sheet) | `POST /v1/media/preview-url` | Session editor: "Preview clip" status |
| 10 | `offline-downloads-manager` | S2 | `/downloads` (`you_pages.dart`) | catalog `sessions[].sizeMb`; bootstrap `downloads.quotaMb` | Settings → Downloads quota |
| 11 | `silence-room` | S3 | `/silence` (`silence_pages.dart`) | `GET /v1/silence` → live count, regions, durations, bells | Sounds: bell kind `opening` / `interval` / `closing`; Settings → Silence room durations |
| 12 | `silence-room-active-sit-dimmed` | S3 | `/silence/run` | socket `silence:live` (count) | – |
| 13 | `scheduled-sit-lobby` | S3 | `/lobby` (`together_pages.dart`) | `GET /v1/group/next` + `focus`, `quote`; socket `lobby:*` | Group sits: focus line, quote |
| 14 | `next-sync-sit-countdown` | S3 | `/sit/next` | `GET /v1/group/next` + `waitingByRegion`, `intentions[]`; `PUT /v1/group/intention` | Group sits: cadence, hourly window, intention options |
| 15 | `low-traffic-room-state` | S3 | `/silence` quiet variant | `GET /v1/silence` → `quiet`, `todayTotal`, `todayZones` | Settings → Today: empty-room threshold (exists) |
| 16 | `daily-message` | S3 | `/message/:date` (`messages_pages.dart`) | `GET /v1/daily-messages/{date}` + `access`, `tag`; archive items `locked` | Daily messages: access (free/premium) |
| 17 | `daily-message-transcript` | S3 | `/message/:date` (transcript section) | `daily_messages.transcript[]`, `videoMediaId`; `PUT/DELETE /v1/daily-messages/{date}/save` | Daily messages: transcript editor (timed lines), video media |
| 18 | `end-of-session-payoff-a` | S3 | `/complete` quiet/solo variant | `POST /v1/meditations` → `streak`, `finishers`, `regions` | – |
| 19 | `end-of-session-payoff-b` | S3 | `/complete` busy variant | same + `POST /v1/sessions/{id}/kudos` | – |
| 20 | `world-map-global-gauge` | S4 | `/world` | `GET /v1/live/world` | Settings → Today (gauge on/off) |
| 21 | `data-sovereignty-privacy` | S4 | `/privacy` | `POST /v1/me/export`, `POST /v1/me/dedications/anonymize`, `DELETE /v1/me` | Settings → Legal |
| 22 | `crisis-support-directory` | S4 | `/sos/directory` | `GET /v1/sos/directory?country=` | SoS → Crisis directory (regions, lines) |
| 23 | `sos-immediate-support` | S4 | `/sos` (`sos_page.dart`) | `GET /v1/sos` + tile `durationMin`, `soundBeds[]` | SoS tiles: duration, sound beds |
| 24 | `conversion-paywall` | S4 | `/membership` | RevenueCat; `bootstrap.founding` | Subscriptions (exists) |
| 25 | `build-your-own` | S5 | `/byo` (`byo_pages.dart`) | recipes unchanged; blueprint is client-side | Sounds (exists) |
| 26 | `together-dedications` | S5 | `/together` (`together_pages.dart`) | `GET /v1/community/feed` (recent, cursor), post `location` | Moderation (exists) |
| 27 | `dedication-composer` | S5 | `/dedications/compose` (sheet) | `POST /v1/dedications` + `locationMode: city|worldwide` | – |
| 28 | `you-personal-stats` | S7 | `/you` (`you_pages.dart`) | `GET /v1/me/progress` + `streak`, `lifetime`, `weekly[]` with rest flag | Users → detail: streak |
| 29 | `challenge-detail` | S7 | `/challenge/:id` | `GET /v1/challenges/{id}`, `POST /v1/challenges/{id}/join` | Challenges (cohort, days, unlock times, badge) |
| 30 | `story-share-payoff-9x16` | S7 | `/share` | payoff data; `includeHeartRate` is client-only | – |
| 31 | `lock-screen-live-activity` | S7 | native (audio session + Live Activity) | – | – |

Non-screen assets from Stitch: logo (`logo_baf46cd5.svg`), Raphael headshot, four app-icon explorations (`stitch-export/assets`).

## Shared design tokens
`stitch-export/DESIGN.md` ("Nocturnal Athleticism"): near-black `#0B0D0E` base, `#050607` sunken (active sits), `#16191B` raised, Ember `#FF7A45` actions/streak, Deep Spruce `#123C3A` tags, Live green `#4ADE80` presence only, Inter with tabular figures on every timer/count. The app theme already matches these values (`app_colors.dart`).
