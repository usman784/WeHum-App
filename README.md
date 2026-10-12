# WeHum App (Flutter · GetX)
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
