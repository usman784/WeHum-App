# WeHum App (Flutter · GetX)

## Versions

The version lives in `pubspec.yaml` (`version: <name>+<build>`, now `1.0.2+7`). Every release gets a git tag `v<name>+<build>` and a section here. Patch = fixes and small changes, minor = new screens or features, major = a breaking change to the API contract. The CMS and backend carry the same tag on the commit that was current on the release day; see the **Needs** line to know which of them a build expects.

### Unreleased (after 1.0.2+5)
- Meditation summary: swipeable share preview with four looks; Share and Done are pinned in view.
- **Needs:** nothing new from the backend or CMS. Bump `pubspec.yaml` when this ships.

### 1.0.2+5 (29 Oct 2026) · tag `v1.0.2+5`
- Guests see no progress or metrics, and no Sign out on You and Settings (there is nothing to sign out of); the You tab no longer jumps while progress loads.
- Edit profile: accounts only, any photo uploads, one username per account.
- Splash: stays at least 2.4 s, the logo stays where the iOS launch screen draws it, no double logo or blink at hand-over.
- **Needs:** backend `v1.0.2+5` (guest rules, profile and username rules), CMS `v1.0.2+5` for the Online now views.

### 1.0.1+4 (27 Oct 2026) · tag `v1.0.1+4`
- Library as in TestFlight: square theme tiles, Silence Room and Build your own (premium), Challenges and Breathwork "coming soon", My Meditations shows PREMIUM for free people.
- Together: World vibration is back, live from `live:agg`; tap opens the world map.
- Silence Room: 3-second quiet gap after the opening bell; live map of where people meditate.
- Heart rate, Settings button, "Free for you" filter, sign-out fix; buttons keep one height and one line of label everywhere.
- **Needs:** backend and CMS `v1.0.1+4` (`silence:live`, `GET /v1/silence`, `dashboard:kpis` by country).

### 1.0.1+3 (15 Oct 2026) · tag `v1.0.1+3`
- The Stitch redesign: Today, Library, player, Silence Room, lobby, daily message, payoff and share card, dedications, SoS, You tab, Build your own, paywall. Real data instead of static labels.
- New logo and app icon, usernames, profile edit with photo, branding and app name from the CMS.
- Client tickets: swipeable intro carousel, onboarding Back, free YouTube player with description, password show/hide.
- CI for the app: `flutter analyze` and `flutter test` on push and PR.
- **Needs:** backend and CMS `v1.0.1+3` (Stitch endpoints, branding config, usernames).

### 1.0.0+2 (9 Oct 2026) · tag `v1.0.0+2`
- First TestFlight build: onboarding, account flows (Google, Apple, email, merge), membership, Today, Together, group lobby, daily message, inbox, SoS, player (audio, video, free), library and search, downloads, You and progress, Silence Room, Build your own, "coming soon" screens behind flags, accessibility at 200% text, iOS policy files.
- In-app update prompt and push taps that wait for the first screen; Android push channel and icon.
- **Needs:** backend and CMS `v1.0.0+2` (bootstrap carries `latestVersion` and `storeUrls`).

### 1.0.0+1 (7 Oct 2026)
- Project foundation (P0): flavors dev, staging, prod, API client with retry and ETag, realtime services, design system. Never shipped.
1. Read `WeHum_App_Spec.md`: §0 and §0.1 first, then build phase by phase (§14).
2. Every screen has a screenshot in `design/screens/` and its exact source in `design/source/` (see the §0.1 table).
3. Copy `starter/` into a new Flutter project (`flutter create --org app.wehum --project-name meditation`). It contains:
   - `pubspec.yaml`;
   - the theme tokens;
   - the API client;
   - the socket service;
   - the routes.
4. Backend contract: `../backend/starter/openapi/openapi.yaml` and backend spec §7 (sockets).

## Oct 12 — Stitch redesign
- What changed: `WeHum_App_Spec.md` §0.2, screen list §12b, phases §14b. Map to backend and CMS: `../stitch-export/SCREEN_MAP.md`.
- Design files: `design/stitch/screens/` (PNG) and `design/stitch/source/` (HTML) for the 29 built screens; `design/screens/` + `design/source/` are the earlier 74-screen canvas, kept for screens Stitch does not redraw.

## Android production bundle

Production release signing reads `android/key.properties`, which points to `android/wehum-prod.jks`. The credentials are also saved in `android/keystore-credentials.txt`. All three files are ignored by Git; keep a secure backup for future releases. Dev and staging releases keep debug signing.

From `app/`, run:

```sh
flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
```

The signed bundle is written to `build/app/outputs/bundle/prodRelease/app-prod-release.aab`. Its package ID is `app.wehum.meditation`; its version comes from `pubspec.yaml`.
