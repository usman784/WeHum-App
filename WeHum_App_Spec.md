# WeHum — Mobile App Build Spec (Flutter · GetX · Node.js REST API · Socket.IO)

> Single source of truth for building the WeHum iOS/Android app. Bundle id `app.wehum.meditation` (staging `app.wehum.meditation.staging`, dev `app.wehum.meditation.dev`).
> **Backend:** Node.js + PostgreSQL + Redis + Socket.IO, specified in `../backend/WeHum_Backend_Spec.md`. **No Firebase database, auth or functions.** FCM is used **only** as push transport.
> **Design reference:** `app/design/`, which holds a screenshot and the exact HTML source for each of the 74 screens (§0.1). Screen numbers in this file are the file-name prefixes.
> **Contracts the app builds against:**
> - REST: `../backend/starter/openapi/openapi.yaml` (generate the Dart client from it).
> - Sockets: backend spec §7 and `../backend/starter/src/realtime/socket-events.ts`.
>
> **Starter code:** `app/starter/` (theme tokens, API client with token refresh, socket service, routes).

---

## 0. How to use this file (instructions for the builder / AI agent)

1. Work **phase by phase** (§14). Do not start a phase before the previous one is green.
2. At the end of every phase:
   1. Run the phase's test checklist (unit, widget, golden, integration, manual device matrix).
   2. Fix every failure. Re-run until green.
   3. Update **§16 Phase reports** in this file: what was built, the tests run (with commands and counts), bugs found and fixed, open issues, and the path to screenshots or recordings.
   4. Only then move to the next phase.
3. Never hard-code any of these inside widgets; use the source in brackets:
   - colors and text styles (tokens §3, `AppText` §4);
   - prices (RevenueCat §9);
   - durations, thresholds and copy (`/v1/bootstrap` config §7).
4. Every screen must implement **all states**: loading (skeleton), content, empty, error (retry), offline. No screen may be missing a state.
5. When the spec and the design disagree, the **latest client notes (§1.3)** win; log the decision in §16.
6. The backend is built in parallel. Until an endpoint exists, use the **mock implementations** in `core/data/mock/`, which return the payloads from backend spec §5.4. Switching to real data is a binding change only.

---

## 0.1 Design reference files (READ BEFORE BUILDING ANY SCREEN)

The visual design ships in this folder (`app/design/`). You cannot see the design canvas, so use these files as the source of truth for how every screen looks:

```
app/
  WeHum_App_Spec.md                 ← this file
  design/screens/NN_Name.png        ← rendered screenshot of every screen (what it must look like)
  design/source/Name.dc.html        ← exact design source: every color (hex), size (px), radius, gap, font size/weight and all copy, as inline CSS
  design/source/img/*.jpg           ← placeholder images used in the design
  design/source/canvas.json         ← screen order, titles and frame sizes
  starter/                          ← starter code (theme tokens, API client, socket service, routes, pubspec)
```

**How to use them for each screen:**
1. Open the **PNG** to see layout, hierarchy and look.
2. Open the matching **`.dc.html`** and copy exact values from its inline `style="…"`: px values are Flutter logical pixels 1:1 (frames are 390 pt wide = iPhone 14/15). Text inside the markup is the final copy (except obvious demo data like names and numbers, which come from the backend).
3. `{{ hole }}` values and lists (`<sc-for>`) are filled by the `<script>` block at the bottom of each file — read it to see the demo data and the different states (e.g. `room: busy|quiet`, `viewer: free|member`, `program: started|none`). Each `data-props` enum is a **state the real screen must support**.
4. `<a href="X.dc.html">` = navigation target (the route of screen X in §12/§9).
5. The screenshots use a fallback system font because the render machine had no internet; the real font is **Inter** (bundle it). Screenshots show the **dark** theme (designed); build light from the tokens in §3.
6. Where the PNG and this spec disagree, **this spec wins** (it holds the client's latest decisions); log it in the phase report.

Live design canvas (for humans): https://claude.ai/artifact/Mi8J64dz7p2jkbi28wvbYL

| # | Screen | Screenshot | Source |
|---|---|---|---|
| 01 | Splash | `design/screens/01_Main.png` | `design/source/Main.dc.html` |
| 02 | Intro 1 · Welcome | `design/screens/02_Intro1.png` | `design/source/Intro1.dc.html` |
| 03 | Intro 2 · Never alone | `design/screens/03_Intro2.png` | `design/source/Intro2.dc.html` |
| 04 | Intro 3 · Every day | `design/screens/04_Intro3.png` | `design/source/Intro3.dc.html` |
| 05 | Intro 4 · Training, not therapy | `design/screens/05_Intro4.png` | `design/source/Intro4.dc.html` |
| 06 | Setup 1 · Your name | `design/screens/06_NameStep.png` | `design/source/NameStep.dc.html` |
| 07 | Setup 2 · Meditation reminder | `design/screens/07_SitTime.png` | `design/source/SitTime.dc.html` |
| 08 | Setup 3 · Reminder | `design/screens/08_Reminder.png` | `design/source/Reminder.dc.html` |
| 09 | How do you want to start | `design/screens/09_Intro5.png` | `design/source/Intro5.dc.html` |
| 10 | App Store sheet (no login) | `design/screens/10_StoreSheet.png` | `design/source/StoreSheet.dc.html` |
| 11 | Purchase states | `design/screens/11_PurchaseStatus.png` | `design/source/PurchaseStatus.dc.html` |
| 12 | Trial started | `design/screens/12_WelcomeMember.png` | `design/source/WelcomeMember.dc.html` |
| 13 | Save your progress (optional) | `design/screens/13_CreateAccount.png` | `design/source/CreateAccount.dc.html` |
| 14 | Membership paywall | `design/screens/14_Membership.png` | `design/source/Membership.dc.html` |
| 15 | Restore purchase | `design/screens/15_RestoreSheet.png` | `design/source/RestoreSheet.dc.html` |
| 16 | Save your progress (free user) | `design/screens/16_CreateAccountFree.png` | `design/source/CreateAccountFree.dc.html` |
| 17 | Sign up with email | `design/screens/17_EmailSignUp.png` | `design/source/EmailSignUp.dc.html` |
| 18 | Log in | `design/screens/18_Login.png` | `design/source/Login.dc.html` |
| 19 | Forgot password | `design/screens/19_ForgotPassword.png` | `design/source/ForgotPassword.dc.html` |
| 20 | Check your email | `design/screens/20_CheckEmail.png` | `design/source/CheckEmail.dc.html` |
| 21 | Account needed to post | `design/screens/21_AccountGate.png` | `design/source/AccountGate.dc.html` |
| 22 | Today · Meditation of the Day | `design/screens/22_Today.png` | `design/source/Today.dc.html` |
| 23 | Meditation of the Day room | `design/screens/23_MotdRoom.png` | `design/source/MotdRoom.dc.html` |
| 24 | Today (free) | `design/screens/24_TodayFree.png` | `design/source/TodayFree.dc.html` |
| 25 | World map & World Vibration | `design/screens/25_GlobalPresence.png` | `design/source/GlobalPresence.dc.html` |
| 26 | Daily message | `design/screens/26_DailyMessage.png` | `design/source/DailyMessage.dc.html` |
| 27 | Explore archive | `design/screens/27_MessageArchive.png` | `design/source/MessageArchive.dc.html` |
| 28 | Notifications | `design/screens/28_Notifications.png` | `design/source/Notifications.dc.html` |
| 29 | Push notifications | `design/screens/29_PushPreview.png` | `design/source/PushPreview.dc.html` |
| 30 | SoS · How can I help? | `design/screens/30_SOS.png` | `design/source/SOS.dc.html` |
| 31 | Library | `design/screens/31_Library.png` | `design/source/Library.dc.html` |
| 32 | Theme page | `design/screens/32_Discipline.png` | `design/source/Discipline.dc.html` |
| 33 | Library filters | `design/screens/33_LibraryFilters.png` | `design/source/LibraryFilters.dc.html` |
| 34 | Search | `design/screens/34_Search.png` | `design/source/Search.dc.html` |
| 35 | All programs | `design/screens/35_Programs.png` | `design/source/Programs.dc.html` |
| 36 | Program detail | `design/screens/36_ProgramDetail.png` | `design/source/ProgramDetail.dc.html` |
| 37 | Teacher bio | `design/screens/37_TeacherBio.png` | `design/source/TeacherBio.dc.html` |
| 38 | My Meditations | `design/screens/38_MySits.png` | `design/source/MySits.dc.html` |
| 39 | Build your own | `design/screens/39_BuildYourOwn.png` | `design/source/BuildYourOwn.dc.html` |
| 40 | Build your own · advanced | `design/screens/40_BuildAdvanced.png` | `design/source/BuildAdvanced.dc.html` |
| 41 | Session detail | `design/screens/41_SessionDetail.png` | `design/source/SessionDetail.dc.html` |
| 42 | Player · presence ring | `design/screens/42_Player.png` | `design/source/Player.dc.html` |
| 43 | Video player | `design/screens/43_VideoPlayer.png` | `design/source/VideoPlayer.dc.html` |
| 44 | Free YouTube player | `design/screens/44_YouTubePlayer.png` | `design/source/YouTubePlayer.dc.html` |
| 45 | Meditation complete · payoff | `design/screens/45_SessionComplete.png` | `design/source/SessionComplete.dc.html` |
| 46 | Share your meditation | `design/screens/46_ShareCard.png` | `design/source/ShareCard.dc.html` |
| 47 | Write a dedication | `design/screens/47_DedicationSheet.png` | `design/source/DedicationSheet.dc.html` |
| 48 | Session dedications | `design/screens/48_Dedications.png` | `design/source/Dedications.dc.html` |
| 49 | Report a post | `design/screens/49_ReportSheet.png` | `design/source/ReportSheet.dc.html` |
| 50 | Silence Room setup | `design/screens/50_SilenceSetup.png` | `design/source/SilenceSetup.dc.html` |
| 51 | Silence Room meditating | `design/screens/51_SilenceSession.png` | `design/source/SilenceSession.dc.html` |
| 52 | Together · group meditation | `design/screens/52_Together.png` | `design/source/Together.dc.html` |
| 53 | Group meditation lobby | `design/screens/53_GroupLobby.png` | `design/source/GroupLobby.dc.html` |
| 54 | You | `design/screens/54_You.png` | `design/source/You.dc.html` |
| 55 | Your progress | `design/screens/55_Stats.png` | `design/source/Stats.dc.html` |
| 56 | Edit profile | `design/screens/56_EditProfile.png` | `design/source/EditProfile.dc.html` |
| 57 | Reminders & sounds | `design/screens/57_Reminders.png` | `design/source/Reminders.dc.html` |
| 58 | Downloads | `design/screens/58_Downloads.png` | `design/source/Downloads.dc.html` |
| 59 | Privacy & data | `design/screens/59_Privacy.png` | `design/source/Privacy.dc.html` |
| 60 | Help & about | `design/screens/60_Help.png` | `design/source/Help.dc.html` |
| 61 | Manage membership | `design/screens/61_ManageMembership.png` | `design/source/ManageMembership.dc.html` |
| 62 | Trial ends in 2 days | `design/screens/62_TrialEnding.png` | `design/source/TrialEnding.dc.html` |
| 63 | Payment problem | `design/screens/63_BillingIssue.png` | `design/source/BillingIssue.dc.html` |
| 64 | Membership ended | `design/screens/64_MembershipEnded.png` | `design/source/MembershipEnded.dc.html` |
| 65 | Offline | `design/screens/65_Offline.png` | `design/source/Offline.dc.html` |
| 66 | Empty state | `design/screens/66_EmptyState.png` | `design/source/EmptyState.dc.html` |
| 67 | Error state | `design/screens/67_ErrorState.png` | `design/source/ErrorState.dc.html` |
| 68 | Update required | `design/screens/68_UpdateRequired.png` | `design/source/UpdateRequired.dc.html` |
| 69 | Challenges (coming soon) | `design/screens/69_Challenges.png` | `design/source/Challenges.dc.html` |
| 70 | Gratitude feed (coming soon) | `design/screens/70_Gratitude.png` | `design/source/Gratitude.dc.html` |
| 71 | Breathwork (coming soon) | `design/screens/71_Breathwork.png` | `design/source/Breathwork.dc.html` |
| 72 | Breath pattern designer (coming soon) | `design/screens/72_BreathPattern.png` | `design/source/BreathPattern.dc.html` |
| 73 | Milestones (coming soon) | `design/screens/73_Milestones.png` | `design/source/Milestones.dc.html` |
| 74 | Intent (skipped for now) | `design/screens/74_Intent.png` | `design/source/Intent.dc.html` |

---

## 1. Product summary

**WeHum** is a meditation app by Raphael Reiter (YouTube meditation teacher). Core promise: *you never meditate alone*. Each day there is one **Meditation of the Day (MOTD)** in three lengths (10 / 30 / 45 min). People can meditate it right away on their own, or wait and start together with everyone (**group meditation**). Live presence (how many people are meditating, from which countries) is shown honestly — never faked.

### 1.1 User types
| Type | Account | Access |
|---|---|---|
| Guest (free) | Guest token (install id → `POST /v1/auth/guest`) | "Free for you" meditations (Raphael's online library, YouTube-hosted), read dedications, world map |
| Guest (member) | Guest + RevenueCat purchase | Everything in membership. Can later "Save your progress" (link Apple/Google/email) |
| Free with account | Linked account, no entitlement | Same as free guest; progress synced across devices |
| Member | Entitlement `premium` active (trial or paid) | Full app |

App Store rule (Guideline 5.1.1): **no login before purchase**. Account is optional; required only to post dedications (first name shown).

### 1.2 Membership & pricing (from RevenueCat, never hard-coded)
| Product | Price | Trial | Notes |
|---|---|---|---|
| `wehum_annual_founding` | $59 / year | 7 days | Founding 1,000 (hard cap). Pre-selected while available |
| `wehum_annual` | $79 / year | 7 days | Shown after the cap is reached |
| `wehum_monthly` | $9.99 / month | 7 days | |

Membership unlocks: extended meditation library, MOTD in 10/30/45 min, group meditations, daily message, customizable meditations (Build your own), SoS sessions for hard times, Silence Room, offline downloads, posting dedications.

### 1.3 Latest client decisions (Oct 5) — must be respected
- Wording: "meditate / meditating / meditations" everywhere. Never "sit / sitting / sits".
- No streaks, no grace days, no rest days. Show **progress** (minutes, meditations, days this week).
- No 30-second previews.
- Silence Room is **paid** and appears on **every** home page (locked + "Premium" for free users).
- Free users' home: **paywalled MOTD on top**, then **"Free for you"** (random free meditation of the day + list). Paid users see those same free items **without** a "free" label. Premium items labelled **"Premium"**.
- No "from YouTube channel" text anywhere.
- Group meditation = the MOTD starting for everyone at the same moment (one configured start time; no separate schedule).
- SoS title "How can I help?" + card "Need more help? You can contact us and book a personal session with Raphael."
- Intent onboarding step skipped for now (keep code behind a flag `features.intent = false`).
- "For life" / "as long as you stay" wording removed from pricing.
- Disciplines are called **Themes**. "Deep Sits" → "Deep Meditation". Filter "Raphael's voice" → "Teachers".
- Coming soon (built behind flags, hidden or shown as "Coming soon"): Challenges, Gratitude feed, Breathwork, Breath pattern designer, Milestones.
- Out of V1: profiles, friends, private chat, image/video posts.

---

## 2. Tech stack

| Area | Choice | Why |
|---|---|---|
| Framework | Flutter (latest stable), Dart 3, null-safety | iOS + Android |
| State / DI / routing | **GetX** (`get`): `GetMaterialApp`, `GetPage`, `Bindings`, `GetxController`, `GetxService`, `Rx` | Requested |
| HTTP | **`dio`** + interceptors: auth (attach token), refresh (single-flight), retry (idempotent GET, 3× exponential backoff), ETag cache, logging (debug only), Sentry breadcrumbs | Fast, cancellable |
| API client | `openapi-generator` (`dart-dio`) from `backend/starter/openapi/openapi.yaml`, wrapped by repositories; or hand-written models with `freezed` + `json_serializable` | Typed, in sync with backend |
| Realtime | **`socket_io_client`** (websocket transport only), wrapped in `SocketService` | Live counts, lobby, group start, entitlement, config |
| Token storage | `flutter_secure_storage` (Keychain / Keystore) for the refresh token; access token in memory | Security |
| Guest identity | install id = UUID v4 stored in secure storage (survives app updates) | Guest-first, no login before purchase |
| Sign in | `sign_in_with_apple`, `google_sign_in` (send id tokens to backend) | Account linking |
| Local DB / cache | **`drift`** (SQLite): catalog snapshot, meditation outbox queue, downloads index, dedication drafts, inbox cache. `get_storage` for small prefs (theme, onboarding flags) | Offline-first, fast queries for library search/filters |
| Payments | `purchases_flutter` (RevenueCat), `appUserID` = backend user id | Receipts never hand-rolled |
| Audio | `just_audio` + `audio_service` + `audio_session` | Gapless, background, lock-screen controls, interruptions |
| Video | `video_player` (+ `chewie` controls) | Premium video meditations |
| Free videos | `youtube_player_iframe` | "Free for you" items (never show the word YouTube) |
| Push | `firebase_messaging` **(token + receive only; no other Firebase product)** + `flutter_local_notifications` (Silence Room end bell, foreground display) + `timezone` + `flutter_timezone` | FCM is the push transport |
| Crash / errors / performance | **`sentry_flutter`** (crashes, ANR/app hang, performance traces, breadcrumbs), `sentry_dio` | One tool across app, backend and CMS |
| Product analytics | `AnalyticsService` → batched `POST /v1/analytics/events` (own pipeline, §11.2); optional PostHog later behind the same interface | No Firebase |
| Feature flags / config | `/v1/bootstrap` (`features`, `today`, `group`, `minVersion`, `maintenance`) + socket `config:changed` | Live kill-switches |
| Attestation | `app_device_integrity` (or similar): App Attest / Play Integrity token sent on guest creation (P10) | Abuse protection |
| Downloads | `background_downloader` | Resumable, background |
| Connectivity | `connectivity_plus` + real reachability (`GET /healthz` 3 s timeout) | §10 |
| Images | `cached_network_image`, `flutter_blurhash`, `flutter_svg` | |
| Sharing | `share_plus` + `RepaintBoundary` → PNG (9:16, 1:1) | Payoff card |
| Misc | `url_launcher`, `package_info_plus`, `device_info_plus`, `screen_brightness`, `wakelock_plus`, `intl`, `uuid` (v4 install id, **v7** meditation ids), `add_2_calendar` | |
| Tests | `flutter_test`, `mocktail`, `integration_test`, `golden_toolkit`, `http_mock_adapter` (dio), local backend via docker-compose for e2e | |

Pin exact versions in `pubspec.yaml` at project start (see `starter/pubspec.yaml`) and record them in §16.

---

## 3. Design tokens — colors

All colors live in `lib/core/theme/app_colors.dart` as a `ThemeExtension<AppColors>` with `dark` and `light` instances. Widgets read `context.colors.xxx` (extension). **Dark is the default and the designed theme.** Light theme is derived (not yet drawn in the canvas) — verify contrast ≥ 4.5:1 for text before release.

### 3.1 Core palette
| Token | Dark (designed) | Light (derived) | Use |
|---|---|---|---|
| `bg` | `#0B0D0E` | `#F7F5F2` | Screen background |
| `bgDeep` | `#050607` | `#ECE8E3` | Behind bottom sheets, payoff screen |
| `surface` | `#17191B` | `#FFFFFF` | Cards |
| `surfaceAlt` | `#1E2124` | `#F1EEEA` | Secondary buttons, pills |
| `surfaceInput` | `#0F1112` | `#F4F1ED` | Inputs, segmented control track, nav bar |
| `border` | `#23262A` | `#E4E0DA` | Card borders, dividers |
| `borderStrong` | `#2A2D30` | `#D6D1CA` | Inputs, chips |
| `borderOutline` | `#3A3E42` | `#BDB6AE` | Outline buttons, dashed "coming soon" |
| `track` | `#2A2D30` | `#E2DDD6` | Progress tracks, switch off |
| `textPrimary` | `#F2F2F2` | `#141618` | Titles, body |
| `textBody` | `#D9DBDD` | `#2B2F33` | Long text on cards |
| `textSoft` | `#C9CCCF` | `#3E4348` | Secondary labels |
| `textSecondary` | `#A0A4A8` | `#5C6166` | Meta, captions |
| `textTertiary` | `#6E7378` | `#8A8F94` | Hints, footers |
| `ember` (primary) | `#FF7A45` | `#E8622C` | Primary buttons, active chips, progress |
| `emberText` | `#FF9B70` | `#C2471A` | Links, overline, premium label text |
| `emberSoft` | `#FFB99A` | `#D9693A` | Hover/pressed, soft accents |
| `onEmber` | `#2A0E02` | `#FFFFFF` | Text on ember buttons |
| `emberTint` | `rgba(255,122,69,0.14)` | `rgba(232,98,44,0.10)` | Premium badge bg, selected tile bg |
| `emberDeep` | `#3A1D12` | `#FBE3D8` | Image fallback, warm cards |
| `teal` | `#123C3A` | `#DDF3EF` | Calm cards, avatar bg |
| `tealText` | `#9FE3D6` | `#0F5E55` | Text on teal |
| `tealSoft` | `#CFEDE6` | `#2F7A70` | Secondary text on images/teal |
| `success` / `live` | `#4ADE80` | `#16A34A` | Live dot, checks |
| `onSuccess` | `#062B14` | `#FFFFFF` | |
| `info` bg/text | `#1E2A3A` / `#A9C4E8` | `#E3ECF7` / `#2C5282` | Video tag |
| `lilac` bg/text | `#2A1F33` / `#CDB6E6` | `#EEE6F5` / `#5B3E7A` | Loops, outros |
| `danger` | `#D9483B` | `#C53030` | Destructive confirm |
| `dangerText` | `#FF8A75` | `#C53030` | Delete text |
| `dangerTint` | `rgba(220,70,50,0.10)` + border `#7A2E22` | `#FDECEA` + `#F5B5AE` | Delete card |
| `overlayScrim` | `rgba(11,13,14,0.60)` | `rgba(20,22,24,0.45)` | Pills on images, sheets |
| `imageGradient` | `linear(180°, rgba(11,13,14,0) 25% → rgba(11,13,14,0.94) 100%)` | same (always dark on photos) | Hero image legibility |

### 3.2 Special gradients
| Name | Value | Use |
|---|---|---|
| `worldVibration` | `90°: #3A2A22 0% → #FF7A45 35% → #E5D96B 62% → #4ADE80 100%` | World Vibration bar (moves toward green) |
| `groupCard` | `160°: #2A1810 0% → #17191B 70%`, border `#3A2A22` | Next group meditation card |
| `presenceRing` | radial `rgba(159,227,214,0.28)` → `rgba(18,60,58,0.55)` → transparent | Player breathing ring |

### 3.3 Logo
Ring logo (provided by client): orange arc `#FF7A45`, stroke 3.5/30 viewBox, `stroke-dasharray 52 18` (gap top-right), round caps; inner green disc `#4ADE80` r=6; centre dot `#0B0D0E` r=2.4. Ship as SVG (`assets/brand/logo.svg`) + app icons generated from it (flutter_launcher_icons), splash via `flutter_native_splash` (bg `#0B0D0E`).

---

## 4. Typography

Font: **Inter** (bundle the variable font in `assets/fonts`, don't rely on Google Fonts at runtime). Weights 400/500/600/700. Tabular figures (`FontFeature.tabularFigures()`) for timers and counters.

| Style | Size / line | Weight | Letter spacing | Use |
|---|---|---|---|---|
| `display` | 40 / 44 | 700 | −0.8 | Countdowns, big counters (World map, Together) |
| `heroTitle` | 28–30 / 34 | 700 | −0.4…−0.5 | Screen H1, MOTD title |
| `title` | 22–24 / 28 | 700 | −0.3 | Card titles, sheet titles |
| `navTitle` | 17 / 22 | 600 | 0 | Centered header titles |
| `bodyLarge` | 16 / 24 | 400–600 | 0 | Dedication text, buttons |
| `body` | 15 / 22 | 400–600 | 0 | Default text |
| `bodySmall` | 14 / 21 | 400–600 | 0 | Meta lines |
| `caption` | 13 / 19 | 400–600 | 0 | Captions, helper text |
| `micro` | 12 / 17 | 400–600 | 0 | Footers, legends |
| `overline` | 11 / 14 | 700 | 1.2, UPPERCASE | "MEDITATION OF THE DAY", section labels |
| `badge` | 10–11 / 13 | 700 | 0.8, UPPERCASE | PREMIUM, COMING SOON |

Rules: support Dynamic Type up to 200% with no clipping (wrap, never ellipsize primary titles); minimum text 12pt; respect `MediaQuery.textScaler`.

---

## 5. Shape, spacing, motion

| Token | Value |
|---|---|
| Screen gutter | 20 (24 on onboarding) |
| Header top padding | safe-area + 8 (design: 52 from top incl. status bar) |
| Gaps | 4, 6, 8, 10, 12, 14, 16, 18, 20, 24 |
| Radius | pill 999 · sheet/hero 28 · large card 24 · card 20 · tile 16–18 · input 12–14 · small 10 |
| Touch targets | ≥ 44×44 (icon buttons 44 circle) |
| Primary button | height 54–56, radius 999, ember fill |
| Secondary button | height 52, `surfaceAlt` fill + `borderStrong` |
| Bottom nav | 4 tabs: Today · Library · Together · You; height 52 + safe area; bg `surfaceInput`, top border `border` |
| Header | left: logo + "WeHum" (tabs) or back circle (sub screens); right: **SoS pill** (on every tab), notifications, avatar |
| Shadows | only on payoff card / player art: `0 20 60 rgba(0,0,0,0.5)` |
| Motion | 200 ms ease-out for state changes; breathing ring 4 s in / 6 s out loop; respect Reduce Motion (static) |

---

## 6. Architecture (GetX, feature-first, API-driven)

```
lib/
  main.dart                      // bootstrap(): SentryFlutter.init → zones → DI → runApp
  app/
    app.dart                     // GetMaterialApp, themes, locale, initialBinding
    routes/app_pages.dart        // GetPage list
    routes/app_routes.dart       // route name constants (starter/)
    bindings/initial_binding.dart
  core/
    config/ (env.dart: apiBaseUrl, socketUrl, sentryDsn, revenueCatKeys per flavor)
    theme/ (app_colors.dart, app_text.dart, app_theme.dart, tokens.dart)      // starter/
    widgets/ (design-system components §8)
    network/
      api_client.dart            // dio + interceptors (starter/)
      auth_interceptor.dart  refresh_lock.dart  etag_cache_interceptor.dart  retry_interceptor.dart
      api_error.dart             // maps { error: { code } } → Failure
    realtime/
      socket_service.dart        // connect/auth/reconnect/rooms (starter/)
      socket_events.dart         // event names + payload models (mirror backend socket-events.ts)
    services/ (GetxService singletons)
      auth_service.dart  session_store.dart  connectivity_service.dart  analytics_service.dart
      crash_service.dart (Sentry)  config_service.dart  purchase_service.dart  audio_service.dart
      presence_service.dart  live_service.dart  time_service.dart (server offset)
      notification_service.dart  download_service.dart  sync_service.dart (outbox)  logger.dart
    data/
      models/        // pure Dart models (freezed) — mirror API DTOs
      contracts/     // abstract repositories (interfaces)
      api/           // REST + socket implementations
      mock/          // mock implementations returning spec payloads (used until backend is ready + in tests)
      local/         // drift database, DAOs, get_storage
    errors/ (AppException, Failure, ErrorCode enum = backend §5.3)
    utils/ (formatters, durations, validators, debouncer, uuid7)
  features/
    onboarding/ (splash, intro, setup, start)       each feature:
    membership/                                       bindings/ controllers/ views/ widgets/
    account/
    today/ (today, motd_room, world_map, daily_message, archive, notifications)
    library/ (library, theme, filters, search, programs, teacher)
    player/ (session_detail, audio, video, youtube, complete, share)
    dedications/
    silence/
    build_your_own/
    together/ (together, lobby)
    you/ (you, progress, profile, reminders, downloads, privacy, help, manage_membership)
    sos/
    system/ (offline, empty, error, update_required, maintenance)
    coming_soon/ (challenges, gratitude, breathwork, milestones)
test/  integration_test/
```

### 6.1 Rules
**Data access**
- **Controllers never call `dio` or the socket directly.** They call repository interfaces in `core/data/contracts`.
- `InitialBinding` binds the `api/` implementations, or the `mock/` ones in dev or tests.
- Models are plain Dart (freezed), with `DateTime` in UTC, `String` IDs and enums. JSON (de)serialization happens only in the data layer.

**Reads, streams and state**
- **Reads:** `Future<T> getX()` (REST, with a local cache first where noted). **Live:** `Stream<T> watchX()` comes from `SocketService` plus an initial REST snapshot.
- Controllers bind streams to `Rx` with `bindStream`, and cancel them and leave socket rooms in `onClose`.
- Each screen controller exposes `Rx<ViewState>` = `loading | content | empty | error(Failure) | offline`. The view switches on it with the shared `StateSwitcher` widget.

**Navigation and lifecycles**
- Navigation goes only through `Get.toNamed(AppRoutes.x, arguments: TypedArgs)`. Deep links (`wehum.app/r/{slug}`, `wehum://session/{id}`, push `deepLink`) are mapped in `app_pages.dart`.
- Use `Get.lazyPut(fenix: true)` for feature controllers and `Get.put(permanent: true)` for services.

**Widgets and safety**
- No business logic in widgets. No `setState` except in tiny self-contained UI widgets.
- Never log tokens, email or dedication text. A Sentry `beforeSend` scrubs them.

### 6.2 Networking, auth & speed

**Auth flow**
1. On first launch, `AuthService.ensureSession()`:
   - reads `installId` and the refresh token from secure storage;
   - if there is no session, calls `POST /v1/auth/guest`;
   - keeps the access token in memory and the refresh token in secure storage.
2. Purchases are attached to the guest: `Purchases.logIn(userId)`.

**Refresh**
- The `AuthInterceptor` attaches `Authorization`, `X-App-Version`, `X-Platform`, `X-Install-Id` and `X-Timezone`.
- A `401 TOKEN_EXPIRED` triggers a **single-flight refresh**: concurrent requests wait on one `Completer`, then retry once.
- A `TOKEN_REUSED` or `TOKEN_INVALID` on refresh → clean sign-out to a new guest session. Local downloads are kept.

**Version and maintenance gates**
- A `426 UPDATE_REQUIRED` → route to 68.
- A `503 MAINTENANCE` → maintenance screen.

**Making it fast**
- **Bootstrap:** `GET /v1/bootstrap` and `GET /v1/today` run **in parallel** on splash. Show cached data immediately, then refresh.
- **Catalog:** stored in drift, refreshed only when `bootstrap.catalogVersion` changes or on socket `catalog:changed`.
  - Library, theme pages, filters and search run **locally** (no network per keystroke).
  - The catalog is about 150 KB gz with ETag, so most launches get a 304.
- **Caching and requests:**
  - ETag cache interceptor for `bootstrap`, `today`, `catalog`, `sos` (sends `If-None-Match`).
  - `dio` uses HTTP/2 when available, gzip/br, a 10 s connect timeout and a 15 s receive timeout.
  - Requests from screens that are popped are cancelled with `CancelToken`.
- **Images and audio:**
  - Images use CDN sizes (300/600/1200) chosen by widget size, with blurhash placeholders.
  - Audio: get the signed URL (`POST /v1/media/play-url`) **when Session detail opens** (prefetch), so Play starts instantly. `just_audio` with a `LockCachingAudioSource` covers MOTD replays.
- **Writes:**
  - Meditations are written to the local **outbox** first and sent in the background (`POST /v1/meditations`, batch when there are several).
  - The UI never waits on the network for the payoff screen; the `together` numbers come from the socket ack, or the last `live:agg`.
- **Performance targets:**
  - cold start to first content < 2.0 s on a mid Android;
  - Today first content < 300 ms from cache;
  - player ready < 1 s on 4G (prefetched URL);
  - 60 fps scroll.

### 6.3 Realtime (Socket.IO) in the app

**Connection**
- `SocketService` connects to `{socketUrl}/live`:
  - `transports: ['websocket']`;
  - `auth: { token, installId, appVersion }`;
  - reconnection with exponential backoff (1 s → 30 s, jitter).
- On `connect_error` with `TOKEN_EXPIRED`: refresh the token, then reconnect.
- On `auth:expiring`: refresh, then emit `auth:refresh`.

**Lifecycle**
- Connect when the app is in the foreground **or** a meditation is playing (audio background mode).
- Disconnect 30 s after going to the background if no meditation is playing.
- Rejoin the remembered rooms after every reconnect.

**Rooms per screen** (join on view, leave on pop or background; max 4)
| Screen | Room | Events used |
|---|---|---|
| Today (22/24), Intro 2 (03) | `today` | `live:agg` |
| MOTD room (23) | `motd:{date}`, `today` | `motd:stats`, `live:agg` |
| World map (25), Together (52) | `world` | `live:agg` (top countries, vibration) |
| Player (42), Session detail (41), Dedications (48) | `session:{id}` | `session:live`, `dedication:new/holding/removed` |
| Lobby (53) | `lobby:{date}` | `lobby:state`, `group:start` |
| Always (auto) | `user:{id}`, `config` | `entitlement:changed`, `inbox:new`, `config:changed`, `catalog:changed`, `force:logout` |

**Presence**
- On player start: `presence:start` (ack returns `together`). Then `presence:beat` every 30 s while playing, including in the background.
- `presence:stop` is sent on end or abandon. If the app is killed, the server drops the entry after 90 s.

**Group start**
- `group:start` arrives at T0. Every device also schedules a local timer from the **server-synced clock** (`TimeService.offset` via `time:sync` and `bootstrap.serverTime`), so the start works even if the event is late.
- Late joiners seek to `now − startsAt`.

**When live data stops**
- When the socket is disconnected for > 10 s, live widgets show **"Live counts paused"**. Numbers that are not live are never shown as live.
- The REST `GET /v1/live` is used once as a fallback snapshot.

---

## 7. Data contract (what the app reads and writes)

The backend owns the data model: PostgreSQL schema in `../backend/starter/prisma/schema.prisma`, endpoints in backend spec §5. The tables below are the **app's view**.

### 7.1 Endpoints used by the app (full list: backend spec §5.4)
| Feature | Endpoint(s) | Cache / live |
|---|---|---|
| Session start | `POST /v1/auth/guest`, `POST /v1/auth/refresh` | secure storage |
| Launch | `GET /v1/bootstrap` (me, entitlement, features, today rules, group config, founding offer, catalogVersion, serverTime, sos header) | ETag; `config:changed` |
| Catalog (themes, teachers, sessions, programs, sound blocks, SoS) | `GET /v1/catalog?version=` | drift; `catalog:changed` |
| Today / MOTD | `GET /v1/today?date=` , `GET /v1/motd/{date}`, `GET /v1/group/next` | memory 30 s + drift; `live:agg`, `motd:stats` |
| Live snapshot | socket `live:agg` (fallback `GET /v1/live`) | — |
| Play | `POST /v1/media/play-url` (signed URL, 6 h; downloads 7 d) | prefetch |
| Meditations | `POST /v1/meditations`, `POST /v1/meditations/batch` (offline outbox) | outbox |
| Progress | `GET /v1/me/progress?period=` | drift |
| Profile & settings | `GET/PATCH /v1/me`, `POST /v1/me/devices` | — |
| Account | `/v1/auth/apple|google|email/*`, `/v1/auth/link/*`, `/v1/auth/merge` | — |
| Entitlement | RevenueCat SDK (UI) + `POST /v1/me/entitlement/sync` + socket `entitlement:changed` | — |
| Daily message | `GET /v1/daily-messages/{date}`, `GET /v1/daily-messages?q=&theme=&cursor=` | drift |
| Dedications | `GET /v1/sessions/{id}/dedications`, `POST /v1/dedications`, `PUT/DELETE /v1/dedications/{id}/hold`, `POST /v1/dedications/{id}/report`, `POST/DELETE /v1/blocks` | socket `dedication:*` |
| Recipes (Build your own) | `/v1/recipes*` | drift |
| Programs | `GET /v1/programs/{id}`, `POST …/start`, `POST …/days/{day}/complete` | — |
| SoS | `GET /v1/sos` (also inside catalog) | drift |
| Inbox | `GET /v1/me/inbox`, `POST /v1/me/inbox/read` | socket `inbox:new` |
| Privacy | `POST /v1/me/export`, `DELETE /v1/me` | — |
| Analytics | `POST /v1/analytics/events` (batched) | queue |

### 7.2 Local database (drift)
| Table | Purpose |
|---|---|
| `catalog_meta` | version, etag, fetchedAt |
| `themes`, `teachers`, `sessions`, `programs`, `program_days`, `sound_blocks`, `sos_tiles` | catalog snapshot (indexed: `sessions(theme_id)`, `sessions(access)`, FTS5 on `title, tags, description` for search) |
| `today_cache` | last `/v1/today` JSON per date |
| `outbox_meditations` | id (uuid v7), payload, attempts, lastError — sent FIFO by `SyncService` |
| `downloads` | sessionId, variant, filePath, bytes, expiresAt (signed URL refresh), status |
| `recipes` | mirror of `/v1/recipes` |
| `progress_cache` | last progress per period |
| `inbox` | cached inbox items |
| `pending_actions` | dedication post / report / hold toggles queued while offline (dedication post only if still eligible) |

### 7.3 Client rules (server is the source of truth)
- Premium gating in the UI uses the RevenueCat `CustomerInfo` plus the backend entitlement. Signed media URLs are **only** issued by the server for members. A free user tapping premium content goes to the paywall (14).
- Dedication posting:
  - Requirements: account plus member, and only from Meditation complete (45) with the finished `meditationId`. The UI shows "N of 3 left today" from the response.
  - Server errors map to UI states: `ACCOUNT_REQUIRED` → 21, `PREMIUM_REQUIRED` → 14, `DEDICATION_LIMIT` / `DEDICATION_LINKS` → inline message.
- Text limits: first name 1–30 characters, dedication ≤ 200 characters. Links are blocked client-side too.

---

## 8. Design-system components (build in Phase 1, used everywhere)

| Component | Variants / props |
|---|---|
| `AppScaffold` | tab header (logo + SoS + bell + avatar) / sub header (back, centered title, optional right action) / no header; bottom nav on tab screens |
| `SosPill` | always visible on Today, Library, Together, You, MOTD room, World map |
| `PrimaryButton`, `SecondaryButton`, `OutlineButton`, `TextLink`, `DangerButton` | loading, disabled, icon leading |
| `ChoiceChip` / `PillGroup` | single/multi select (lengths, filters) |
| `SegmentedControl` | 2–4 options (lengths 10/30/45, Simple/Rich, 9:16/1:1, period tabs) |
| `Toggle` | track/knob per design (52×32) |
| `Card`, `HeroImageCard` (image + gradient + overline + title + actions) | |
| `ListRow` | icon tile, title, subtitle, trailing chevron/badge/play |
| `Badge` | PREMIUM (ember tint), COMING SOON (neutral), LIVE, FREE FOR YOU (free users only), VIDEO |
| `LivePill` | dot + text; busy (green) / quiet (grey) per empty-room rule |
| `ThumbImage` | cached network image, blurhash placeholder, fallback color by theme |
| `BottomSheet` | grabber, title, content; scrim `bgDeep` |
| `ProgressBar`, `WeekDots` | progress (no streak semantics) |
| `CountdownText` | server-time synced, tabular nums |
| `PresenceRing` | breathing ring + dot clusters; decorative (excluded from semantics); static when Reduce Motion |
| `WorldDotMap` | dotted map from country aggregates, hot spots |
| `VibrationBar` | gradient bar + marker + info sheet |
| `Skeleton` | shimmer blocks per layout |
| `StateSwitcher` | loading / empty / error / offline / content |
| `EmptyState`, `ErrorState`, `OfflineBanner` | copy from §12 |
| `AppSnack` | success/error toasts |

Golden tests for every component in dark and light, at text scale 1.0 and 2.0.

---

## 9. Payments (RevenueCat)

**Setup and identity**
- Configure the SDK on app start **after** `ensureSession()`, with `appUserID = backend user id` (the guest id at first). On linking an account the id stays the same, so purchases stay attached.
- On merge (409 `ACCOUNT_EXISTS` → login → `POST /v1/auth/merge`), call `Purchases.logIn(newUserId)`. RevenueCat transfers per project settings. Then refresh the bootstrap.

**Offerings and paywall**
- Offerings: `default` (founding annual $59 + monthly) and `regular` (annual $79 + monthly). The backend switches the current offering when the Founding cap is reached.
- The app always renders prices from `StoreProduct.priceString`, never from constants. The founding banner ("N SPOTS LEFT") comes from `bootstrap.founding` and updates live (`config:changed`).
- The paywall (14) and Start screen (09) show: price, period, trial length, auto-renew text, Terms (EULA), Privacy and **Restore**. Annual is pre-selected.

**Entitlement**
- `premium` maps to `PurchaseService.isPremium` (`RxBool`), from `CustomerInfo.entitlements.active`.
- After a successful purchase, call `POST /v1/me/entitlement/sync`. The server confirms through the RevenueCat REST API, and the socket `entitlement:changed` also arrives from the webhook.
- If the SDK and the server disagree for more than 60 s, trust the SDK for UI unlocking and retry the sync. Server-only features (signed URLs, dedications) wait for the server.

**States to handle** (screen 11 Purchase states, and 61–64)
- success;
- cancelled (no error);
- pending or deferred (Ask to Buy);
- failed (network or store);
- already subscribed;
- product unavailable;
- trial ending (push "Trial ends in 2 days");
- billing issue / grace period;
- expired;
- refunded;
- restored on a new device;
- upgrade from monthly to annual.

Never unlock from client receipt parsing.

---

## 10. Offline, connectivity & resilience

| Situation | Behaviour |
|---|---|
| No internet on launch | Session from secure storage (no network needed); show cached Today (MOTD if downloaded), Library from drift catalog, downloads playable; `OfflineBanner` "You're offline. Downloads still work." |
| Backend unreachable but internet OK (5xx / timeout) | Same as offline for reads (cache), writes queued; ErrorState with Retry only where no cache exists |
| Goes offline mid-meditation (streamed) | Keep playing buffered audio; if buffer ends, pause with sheet "Connection lost — continue when you're back" and auto-resume on reconnect |
| Live counts offline / socket down > 10 s | "Live counts paused" (never stale numbers presented as live) |
| Dedications offline | "Dedications will load when you're back"; holds/reports queued in `pending_actions`; posting allowed only online (eligibility check) |
| Meditations completed offline | Saved to `outbox_meditations` (uuid v7), synced on reconnect via `/v1/meditations/batch` (idempotent) |
| Purchase offline | Disable buy buttons with reason; RevenueCat retries |
| Slow network | Skeletons after 300 ms; timeouts 10 s connect / 15 s receive; GET retry 3× with backoff |
| Access token expired | Single-flight refresh, transparent retry |
| Refresh token reused/invalid | Clean sign-out → new guest; keep downloads; message "Please log in again" if user had an account |
| `force:logout` socket event | Same as above |
| 401/403 unexpected | Map to `Failure.permission` → ErrorState + Sentry non-fatal |
| App update required | `426` or `bootstrap.updateRequired` → screen 68 (blocking) |
| Maintenance | `503 MAINTENANCE` / `bootstrap.maintenance` → maintenance screen; downloads + Silence Room keep working offline |
| Server time | `TimeService` offset from `time:sync` (median of 3) + `bootstrap.serverTime`; never device clock for group countdown |
| Time zone / DST change | `PATCH /v1/me {timezone}` on resume when changed (server schedules pushes by tz) |
| Audio interruptions | Phone call, Siri, other app audio → pause; resume only if user was playing; Bluetooth/headphones unplug → pause |
| Background / lock screen | audio_service media notification with play/pause/±15 s; Silence Room timer computed from start timestamp; end bell scheduled as local notification fallback |
| Low storage | Before download check free space; show "Not enough space" with size |
| Signed URL expired during download/play | Re-request `play-url` and resume from byte offset |
| Media missing / YouTube removed | Item shows "Not available right now"; analytics `media_unavailable` |
| Founding cap reached during checkout | RevenueCat returns current offering; if product unavailable show refreshed paywall |
| Account deletion with active subscription | Warn: "Deleting doesn't cancel your App Store subscription" + link to manage |
| Push permission denied | Reminders screen shows "Notifications are off" + Open Settings |
| Socket reconnect storm (server deploy) | Jittered backoff, rooms rejoined, UI shows paused state only after 10 s |

---

## 11. Monitoring: crashes, events, performance

### 11.1 Crashes & errors (Sentry)
**Setup**
- `SentryFlutter.init` wraps `runApp` (`appRunner`) with:
  - `FlutterError.onError` and `PlatformDispatcher.instance.onError`, both captured;
  - ANR (Android) and App Hang (iOS) detection enabled.
- `sentry_dio` traces HTTP. Every API error carries the backend `traceId` as a tag, so app and backend events correlate.

**Context**
- Tags: `plan` (guest_free/guest_member/free/member/trial), `screen`, `flavor`, `connectivity`, `socket_state`, `length`.
- User: id hash only, no email.
- Breadcrumbs: route changes, socket connect/disconnect, purchase steps, player state changes.
- Non-fatals: every caught `AppException` with its code.

**Privacy and builds**
- No PII: the `beforeSend` scrubber removes email, tokens and dedication text.
- Upload dSYMs and obfuscation maps in CI (`--obfuscate --split-debug-info`).
- Disabled in debug; enabled in staging and prod.

### 11.2 Analytics events (own pipeline → `POST /v1/analytics/events`, snake_case)
- `AnalyticsService.track(name, props)` enqueues events in memory and drift.
- Flush: every 30 s, at 20 events, or when the app is backgrounded. Max 50 per batch.
- Each event carries:
  - `installId`;
  - `userId`;
  - a timestamp, using the server-offset clock;
  - `appVersion`;
  - `platform`.
- The CMS funnels and retention (CMS spec) are computed from these events.

| Event | Params |
|---|---|
| `app_open` | `source` (cold/warm/push/deeplink) |
| `onboarding_step_view` / `onboarding_complete` | `step` |
| `reminder_set` | `time`, `enabled` |
| `notification_permission` | `result` |
| `paywall_view` | `source` (start/today_free/lock/settings), `offering` |
| `plan_selected` | `product_id` |
| `purchase_start` / `purchase_success` / `purchase_cancel` / `purchase_fail` | `product_id`, `error_code?` |
| `trial_start`, `restore_success`, `restore_fail` | |
| `motd_view` | `date`, `room` (busy/quiet) |
| `motd_length_selected` | `length` (10/30/45) |
| `meditation_start` | `kind`, `session_id`, `length`, `offline` |
| `meditation_complete` | `kind`, `session_id`, `duration_sec` |
| `meditation_abandon` | `kind`, `pct` |
| `lobby_join`, `group_start` | `date`, `waiting` |
| `world_map_view`, `vibration_info_open` | |
| `dedication_open`, `dedication_post`, `dedication_report`, `user_block` | `session_id` |
| `share_open`, `share_format`, `share_complete` | `format` (9x16/1x1), `include_dedication` |
| `download_start` / `download_complete` / `download_fail` / `download_delete` | `session_id`, `bytes` |
| `library_filter_apply`, `search` | `filters`, `query_len`, `results` |
| `sos_open`, `sos_tile_tap`, `sos_book_tap` | `feeling` |
| `silence_start`, `silence_end` | `length`, `bells` |
| `byo_build`, `byo_save`, `byo_play`, `byo_share` | `length`, `blocks` |
| `account_link` | `provider` |
| `account_delete` | |
| `offline_banner_shown`, `error_shown` | `code`, `screen` |
| `coming_soon_tap` | `feature` |
| `push_open` | `key`, `notification_id` |
| `socket_state` | `state` (connected/paused/reconnected), `down_sec` |
| `media_unavailable` | `session_id` |

User properties are sent once per session as the `user_props` event: `plan`, `is_guest`, `country`, `theme`, `flavor`.
Beta focus metrics (closed beta): onboarding drop-off per step, first-meditation completion.

### 11.3 Performance (Sentry Performance)
**Custom transactions/spans:** `cold_start`, `today_first_content`, `player_ready` (tap → audio playing), `download_duration`, `paywall_ready`, `socket_connect`.

**Targets**
- Cold start < 2.0 s (mid Android).
- Player ready < 1 s on 4G.
- 60 fps scroll.
- Memory < 250 MB during playback.

### 11.4 Alerts
- Sentry alerts go to Slack/email: new issue, regression, crash-free sessions < 99.5 %, ANR rate > 0.3 %.
- A backend p95 regression seen from the app (`sentry_dio` spans) also alerts.

---

## 12. Screen catalogue (all 74 artboards)

Legend — **States:** L loading · E empty · Er error · O offline. **Gate:** F free / M member / A account required.

### Row 1 · First launch (no account)
| # | Screen | Route | Content & behaviour | States / edge cases | Events |
|---|---|---|---|---|---|
| 01 | Splash | `/` | Ring logo + "WeHum by Raphael Reiter", tap/auto → next. Decides: first run → Intro1; returning → Today/TodayFree; update required → 68 | Bootstrap/API failure → ErrorState with retry; maintenance | `app_open` |
| 02 | Intro 1 · Welcome | `/intro/1` | Raphael photo (asset), Skip → 09 | — | `onboarding_step_view` |
| 03 | Intro 2 · Never alone | `/intro/2` | Ring illustration + live pill (socket `live:agg`, hidden offline), "You're never meditating alone." | offline: hide pill | |
| 04 | Intro 3 · Every day | `/intro/3` | MOTD mock card, "One meditation a day…" | | |
| 05 | Intro 4 · Training, not therapy | `/intro/4` | Disclaimer text | | |
| 06 | Setup 1 · Your name | `/setup/name` | First name input (1–30 chars, letters/spaces), live preview chip, Continue → 07 | validation messages; keyboard safe area | |
| 07 | Setup 2 · Meditation reminder | `/setup/time` | Title "Meditation reminder", sub "We will remind you to meditate daily, as consistency is important." 24-h wheel, local time | DST note | `reminder_set` |
| 08 | Setup 3 · Reminder | `/setup/permission` | "We will invite you to meditate at 7:00." (uses chosen time) + OS permission dialog; Not now allowed | denied → still continue; store choice | `notification_permission` |
| 09 | How do you want to start | `/start` | Founding banner "FOUNDING 1,000 · $59/YEAR · N SPOTS LEFT" (from `bootstrap.founding`, live), annual trial CTA, monthly option, **Continue for free** ("Access Raphael's existing online library of guided meditations."), Log in, Restore, Terms, Privacy | prices from RevenueCat; offering unavailable → retry; cap reached → regular offering | `paywall_view{source:start}` |

### Row 2 · Membership
| # | Screen | Route | Content & behaviour | States / edge cases | Events |
|---|---|---|---|---|---|
| 10 | App Store sheet | native | RevenueCat `purchasePackage` → native sheet, no WeHum login | cancel → back to 09 with offer intact | `purchase_*` |
| 11 | Purchase states | `/purchase/status` | loading, failed (retry), pending (Ask to Buy), already subscribed | | |
| 12 | Trial started | `/welcome` | "Welcome to WeHum, {name}", trial end date, day-5 reminder note, Continue → 13 | | `trial_start` |
| 13 | Save your progress (optional) | `/account/save` | Apple / Google / Email, Not now → Today. Benefits: keep progress on new phone, use on iPhone & Android, post dedications | link conflicts (§9) | `account_link` |
| 14 | Membership paywall | `/membership` | Perks list (§1.2), Annual (pre-selected, founding/regular via offering), Monthly $9.99, "Start 7-day free trial", fine print, Restore, EULA, Privacy | — | `paywall_view` |
| 15 | Restore purchase | `/restore` | Restore via RevenueCat; result states found/not found/error | | `restore_*` |

### Row 3 · Optional account & log in
| # | Screen | Route | Notes |
|---|---|---|---|
| 16 | Save your progress (free user) | `/account/save-free` | Same as 13 for free users; Back/Not now → TodayFree |
| 17 | Sign up with email | `/account/email` | Email + password (≥ 8) or email link; errors: in use, weak, invalid |
| 18 | Log in | `/login` | Apple, Google, email; on login merge guest local history (§9) |
| 19 | Forgot password | `/login/forgot` | Send reset email; generic success message (no account enumeration) |
| 20 | Check your email | `/login/check` | "We sent a link to {email}. Tap the link in that email to finish." Open mail app, resend (60 s cooldown) |
| 21 | Account needed to post | sheet | Shown when guest member taps Dedicate; links to 13 |

### Row 4 · Today, MOTD, SoS
| # | Screen | Route | Content & behaviour | States / edge cases |
|---|---|---|---|---|
| 22 | Today (member) | `/today` | Greeting (time-of-day + name), date. **Hero MOTD**: image, live pill (busy ≥ threshold "412 meditating now · 37 countries" / quiet "1,280 meditated this today"), overline, title, "with Raphael", "1,280 people practiced this meditation today", **SegmentedControl 10/30/45**, two buttons **Meditate now** (→ Player with chosen variant) and **Wait for the group** (16:00 · countdown → Lobby 53). Card tap → Room 23. Program card (started: "YOUR PROGRAM · DAY 4 OF 7" + bar → 36; none: "Start a program" → 35). **Silence Room** row → 50. **Progress** card (minutes this week, meditations) → 55. Optional daily message line (config) | L skeleton; no MOTD for date → fallback to most-played session (backend fills); O → cached MOTD if downloaded else offline state; quiet room rule |
| 23 | MOTD room | `/motd` | Hero image, "1,280 people practiced this meditation today"; card "412 people are meditating right now" + "Start now and meditate with other souls around the world…" + lengths + **Meditate now**; card "NEXT GROUP MEDITATION · 16:00 YOUR TIME" + countdown + Wait in the lobby + Remind me; today's dedications preview; helper line | lobby closed / group already started (late joiners start at group position); group time not set → hide group card |
| 24 | Today (free) | `/today-free` | Locked premium MOTD on top ("10, 30 or 45 min · N meditating now", **Try 7 days free** → 14). **Free for you** section: explainer, hero free item (random/newest per config), list → 44; **Silence Room** with PREMIUM + lock → 14 | E: no free items → hide section; O |
| 25 | World map & World Vibration | `/world` | Live/quiet kicker, big number, dotted map (country aggregates, no GPS), **World Vibration** gradient bar → green + info button (sheet: "rises when more people meditate on the same day and when group meditations gather many people at once"), country list, Meditate with them → 23 | O → "Live counts paused" |
| 26 | Daily message | `/message/:date` | Type audio/video/text (+ optional image), theme tag, no meditation link, **Explore archive** | E: no message today → previous one with date; media failure |
| 27 | Explore archive | `/message/archive` | Search by word/date, theme chips, month groups, paginated | E search no results |
| 28 | Notifications | `/notifications` | In-app inbox (group starts, daily message, Raphael announcements, trial ending) | E "You're all caught up" |
| 29 | Push notifications (lock screen) | system | Daily nudge at chosen time ("Time to meditate, {name}. Today's meditation with Raphael is ready."), group warning 10 min before (opt-in) | permission denied; DST; travel |
| 30 | SoS · How can I help? | `/sos` | Feeling tiles (8, from `/v1/sos`), start immediately (no intro); card "Need more help? You can contact us and book a personal session with Raphael." → booking URL / contact; no medical claims | O → downloaded SoS only; locked for free (Premium) |

### Row 5 · Library
| # | Screen | Route | Notes |
|---|---|---|---|
| 31 | Library | `/library` | Search + filter; tiles Silence Room (PREMIUM for free users), Build your own, Challenges (COMING SOON), Breathwork (COMING SOON); Programs (in-progress or start); **Themes** grid (icon, name, "N meditations · range"); SoS row; "From Raphael's online library" (members, no free label) / "Free for you" (free users); My Meditations, Downloads; teacher card |
| 32 | Theme page | `/theme/:id` | Theme header icon, filters All/Premium/Online library/Video, list with PREMIUM badges; free items no badge for members |
| 33 | Library filters | sheet | Length, **Teachers** (Raphael only for now), Type (All/Audio/Video/Free), Downloaded only; "Show N meditations" live count from the local catalog |
| 34 | Search | `/search` | Debounced 300 ms, local FTS5 index over the drift catalog (no request per keystroke), recent searches |
| 35 | All programs | `/programs` | In progress / available |
| 36 | Program detail | `/program/:id` | Day list (done/today/locked), progress bar (no rest days), Start day N |
| 37 | Teacher bio | `/teacher/:id` | Photo, bio, links (YouTube/Instagram/website), sessions |
| 38 | My Meditations | `/recipes` | Saved recipes, one-tap play, delete (swipe + confirm) |
| 39 | Build your own | `/byo` | 4 choices: length (5–60), opening, sound (+ level slider, Simple/Rich), bells; sticky summary + timeline; **Build it** → Player; Save → name dialog | sound blocks missing → disable option |
| 40 | Build your own · advanced | `/byo/advanced` | Multi-block, reorder, OM/mantra loop counts, share link `wehum.app/r/{slug}` (deep link opens recipe) |

### Row 6 · Meditating
| # | Screen | Route | Notes |
|---|---|---|---|
| 41 | Session detail | `/session/:id` | Cover, PREMIUM/AUDIO tags, lengths (MOTD), description, Play, Download toggle, "1,280 people meditated this today", dedications preview |
| 42 | Player · presence ring | `/player` | Breathing ring + dot clusters (count from socket `session:live`, numbers small), title, "Meditating with N people · M countries" (quiet rule), progress, ±15 s, play/pause, End meditation, "Dedications open when your meditation ends." Reduce motion → static ring. Keeps screen awake optional |
| 43 | Video player | `/player/video` | Premium video, fullscreen, PiP (Android) |
| 44 | Free player | `/player/free` | YouTube embed; **free users**: "Free for you" title + label + upsell; **members**: "Raphael's online library", no label, no upsell; "Dedications are for members" (free users only) | video unavailable/region-blocked |
| 45 | Meditation complete · payoff | `/complete` | Mini world map, "You meditated N minutes.", "You meditated with 412 people in 37 countries.", this week stats, **Dedicate your meditation** (member) / locked (free), Read dedications, Done, Share |
| 46 | Share your meditation | `/share` | 9:16 Story / 1:1 Post toggle, show dedication toggle, render PNG via RepaintBoundary (3× pixel ratio), share sheet / save to Photos (permission) |
| 47 | Write a dedication | sheet | ≤ 200 chars counter, suggestions, no links (client + server), "2 of 3 left today", Post → 48; guest → 21; free → 14 |
| 48 | Session dedications | `/dedications/:sessionId` | Everyone can read; "Holding this · N" (tap toggles, debounced); report/block menu; composer only after finished meditation |
| 49 | Report a post | sheet | Reasons, **Block this person** toggle |
| 50 | Silence Room setup | `/silence` | Presets 5–60 + open-ended, bells start/end (+ interval later), live line (quiet rule), Enter; "Part of membership…" |
| 51 | Silence Room meditating | `/silence/run` | Remaining time (timestamp-based), dims after 5 s (screen_brightness), tap to wake, pause/resume, End, bells via audio session |

### Row 7 · Together
| # | Screen | Route | Notes |
|---|---|---|---|
| 52 | Together | `/together` | Explainer "Group meditations are the Meditation of the Day, started by everyone at the same moment.", live pill → 25, next group card (countdown, lobby count, Go to the lobby, or begin now on your own), World Vibration mini, today's dedications, Gratitude feed (COMING SOON) |
| 53 | Group meditation lobby | `/lobby` | Countdown ring (server time), "N in the lobby · M countries", region counts, MOTD info, Remind me 10 min before toggle, Wait in the lobby, Add to calendar; at T0 auto-start player for everyone in lobby; late joiners seek to `now − T0` |

### Row 8 · You
| # | Screen | Route | Notes |
|---|---|---|---|
| 54 | You | `/you` | Profile, guest card (Save progress / Log in), stats tiles (this week, minutes, meditations, dedications), week chart → 55, rows: Challenges (Coming soon), Milestones (Coming soon), Breathwork (Coming soon), Reminders, Membership, Downloads, My Meditations, Notifications, Privacy & data, Help, Sign out |
| 55 | Your progress | `/progress` | Days meditated this week (dots), Week/Month/Year/Lifetime tabs: minutes, meditations, together, average, bar chart. **No streaks / grace** |
| 56 | Edit profile | `/profile/edit` | First name, email (linked), country visibility, theme (Dark/Light/System) |
| 57 | Reminders | `/reminders` | Daily reminder toggle + time, group meditation warning (10 min), daily message toggle, Wi-Fi-only downloads, notification preview → 29. **No default sounds section** |
| 58 | Downloads | `/downloads` | List with size, delete, clear all, storage used; auto-remove 7 days after membership ends |
| 59 | Privacy & data | `/privacy` | Data we collect list, presence country toggle, export data (`POST /v1/me/export` → email link), **delete account** (confirm, re-auth, warns about store subscription) |
| 60 | Help & about | `/help` | Intro again, Restore purchase, Q&A, Contact, Terms, Privacy, version |

### Row 9 · Membership states
| # | Screen | Notes |
|---|---|---|
| 61 | Manage membership | Plan, status, renew date, Change plan → 14, Manage in App Store/Play (deep link), Restore, how to cancel |
| 62 | Trial ends in 2 days | Push day 5 + in-app sheet; price from RevenueCat |
| 63 | Payment problem | Billing issue / grace period banner, Update payment (store link) |
| 64 | Membership ended | Still free: "Free meditations from Raphael's online library"; now locked: MOTD, extended library, group meditations, Silence Room, daily message, downloads; Rejoin / Continue free |

### Row 10 · System states
| # | Screen | Notes |
|---|---|---|
| 65 | Offline | Downloads list, Silence Room timer (offline), live counts paused, dedications later, sync note |
| 66 | Empty state | Reusable component (icon, title, body, CTA) |
| 67 | Error state | Reusable (code shown small, Retry, Contact) |
| 68 | Update required | Blocking, store link |

### Row 11 · Coming soon (feature flags)
| # | Screen | Flag |
|---|---|---|
| 69 | Challenges | `features.challenges` (7 / 21-day, any meditation counts, no grace) |
| 70 | Gratitude feed | `features.gratitude` |
| 71 | Breathwork | `features.breathwork` |
| 72 | Breath pattern designer | `features.breathwork` |
| 73 | Milestones | `features.milestones` |
| 74 | Intent (setup) | `features.intent` (off) |

Also required but not drawn: **Maintenance** screen, **Permission denied** helpers (notifications, photos), **Deep link not found**, **Session unavailable** sheet, **Force sign-out** (token revoked).

---

## 13. Feature logic details

- **Empty-room rule:** if the live total is below `today.emptyRoomThreshold` (10), the server sets `quiet: true`. The app then shows "N meditated today" with a grey dot; otherwise "N meditating now" with a green dot. Never fake, never round up.
- **Meditation counting** (decided by the server, mirrored locally for instant UI): a meditation counts when ≥ 3 min was listened (or ≥ 50 % of a shorter session). Write to the outbox, then `POST /v1/meditations`; the server updates stats.
- **Progress week:** ISO week in the user's timezone. Days meditated = distinct local dates with a counted meditation (`/v1/me/progress`).
- **MOTD variants:** the player requests `play-url` for `{date, lengthMin}`. Downloads are per variant.
- **Group start:** `GET /v1/group/next` → `startsAt` (UTC).
  - The lobby opens `group.lobbyOpenMin` before (15).
  - "Remind me" is a server push 10 min before (the user opts in via `PATCH /v1/me {groupWarning}` or by joining the lobby reminder), plus a local notification fallback.
  - At T0 the socket sends `group:start`, and the local timer also fires.
- **Audio assembly (Build your own):**
  - Main track: `ConcatenatingAudioSource(useLazyPreparation:false)` of opening → core (looped/clipped) → silence padding (silent asset, `ClippingAudioSource`) → closing.
  - Background sound: a second `AudioPlayer` with volume = level.
  - Bells are scheduled from the position stream.
  - Total length must be accurate to ±1 s. Block URLs come from `play-url` (batch).
- **Presence:** see §6.3. Presence is never sent for free YouTube playback of non-catalog items. Free catalog items do count.
- **Dedication posting:** only from Meditation complete (45) for that meditation. The server checks eligibility and the limit (3/day).
- **Theme:** Dark (default) / Light / System, saved in `get_storage` and via `PATCH /v1/me {theme}`.
- **Accessibility:**
  - Semantics labels on all icon buttons; decorative visuals excluded; logical focus order.
  - 200 % text with no clipping; Reduce Motion respected.
  - Captions for video when provided.
- **Localization:** English at launch. All strings live in `lib/l10n/app_en.arb` (gen-l10n); German comes later.

---

## 14. Phase plan (each phase: build → self-test → fix → report)

| Phase | Scope | Exit tests (must pass) |
|---|---|---|
| **P0 Foundation** | Flavors dev/staging/prod (bundle ids), `bootstrap()` with Sentry, GetX shell, routes (starter), bindings, services skeleton, theme tokens dark+light (starter), Inter font, logo/icons/splash, env config, `ApiClient` + interceptors (starter), mock repositories, CI (format, analyze, test, build) | `flutter analyze` 0 issues; boots iOS + Android all flavors; Sentry test crash received; theme switch works; interceptor unit tests (refresh single-flight, retry, ETag) |
| **P1 Design system** | All components §8, `StateSwitcher`, skeletons, empty/error/offline widgets, golden tests | Goldens dark/light × text scale 1.0/2.0; a11y semantics test |
| **P2 Session, onboarding & guest** | Guest auth (`/auth/guest`), secure storage, screens 01–09, name/reminder (`PATCH /v1/me`), notification permission + device token (`POST /v1/me/devices`), drift DB, catalog sync | Integration: full onboarding against local backend (docker-compose) and mocks; reinstall keeps install id behaviour documented |
| **P3 Membership & accounts** | RevenueCat with backend user id, 09–16, entitlement sync + socket, restore, Apple/Google/email link, merge flow, 17–21, 61–64 | Sandbox purchase/cancel/restore on both stores; `ACCOUNT_EXISTS` → merge test; gating unit tests |
| **P4 Realtime core** | `SocketService` (auth, reconnect, rooms), `TimeService` sync, `LiveService` (`live:agg`), presence start/beat/stop, "Live counts paused" | Socket integration test vs local backend: reconnect after kill, token expiry refresh, rooms rejoined; presence visible in backend within 6 s |
| **P5 Today & playback** | 22, 23, 24, 41, 42, 43, 44, 45, 46, `play-url` prefetch, audio_service, 3 lengths, meditation outbox, payoff numbers, share PNG | Player integration (start, background, lock screen, interruption); outbox offline → sync idempotent; share sizes 1080×1920 / 1080×1080 |
| **P6 Library & offline** | 31–38, local search (FTS5), filters, downloads (+ signed URL refresh), offline matrix §10, 65 | Airplane-mode integration test; download resume/kill test; storage-full test |
| **P7 Together & world** | 25, 52, 53, lobby (`lobby:join`, `lobby:state`), `group:start` + local timer, late join seek, world map, vibration info | Two-device test: start within ±1 s; late join position correct; tz display test |
| **P8 Community & messages** | 26, 27, 28, 29, 47, 48, 49, 21, inbox, push handling + deep links, dedications live events, report/block | Guest/free cannot post (server codes mapped); limit 3/day; link blocked; live new dedication appears < 2 s |
| **P9 You & settings** | 54–60, progress periods, export/delete account, theme, privacy toggles | Delete account end-to-end (server job done, local wiped, RC warning shown) |
| **P10 Silence, BYO, SoS** | 30, 39, 40, 50, 51, recipes API, share slug deep link | Timer accuracy (background 30 min ±1 s); BYO length ±1 s |
| **P11 Hardening & release** | Attestation on guest create, accessibility pass, performance budgets, edge-case suite §10, analytics validation (events reach backend), store assets, privacy labels, release builds | Crash-free ≥ 99.5 % in beta; perf within targets; all §10 cases checked |
| **P12 Coming soon** (after V1) | 69–74 behind flags | Flag on/off via `config:changed` live |

Device matrix each phase: iPhone SE (small), iPhone 15, iPad (compat), Pixel 7, low-end Android (3 GB RAM, Android 10).

---

## 15. Definition of done (every screen)
- Matches design tokens and copy; dark + light.
- All 5 states implemented and reachable in tests.
- Analytics events fired with correct params; Sentry tags set.
- Works at 200% text, VoiceOver/TalkBack labels present.
- No `dio`/socket calls in controllers; rooms left and streams cancelled on close.
- Unit tests for controller logic; widget test for view states; works against mocks **and** the real local backend.

---

## 16. Phase reports (update after every phase)

```
### Phase Px — <name>
Date:
Built:
Tests run: (commands, pass/fail counts)
Bugs found → fixed:
Decisions / deviations from spec:
Open issues / risks:
Evidence: (screenshots, recordings, Sentry links, backend event counts)
Status: ✅ done / ⚠️ blocked
```

_(No phases completed yet.)_
