---
name: Nocturnal Athleticism
colors:
  surface: '#121415'
  surface-dim: '#121415'
  surface-bright: '#38393a'
  surface-container-lowest: '#0c0e0f'
  surface-container-low: '#1a1c1d'
  surface-container: '#1e2021'
  surface-container-high: '#282a2b'
  surface-container-highest: '#333536'
  on-surface: '#e2e2e3'
  on-surface-variant: '#dfc0b5'
  inverse-surface: '#e2e2e3'
  inverse-on-surface: '#2f3132'
  outline: '#a78b81'
  outline-variant: '#58423a'
  surface-tint: '#ffb59a'
  primary: '#ffb59a'
  on-primary: '#5b1b00'
  primary-container: '#ff7a45'
  on-primary-container: '#672000'
  inverse-primary: '#a73a05'
  secondary: '#a5cecb'
  on-secondary: '#0a3634'
  secondary-container: '#254d4b'
  on-secondary-container: '#94bdba'
  tertiary: '#4de082'
  on-tertiary: '#003919'
  tertiary-container: '#0ab960'
  on-tertiary-container: '#00411d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbcf'
  primary-fixed-dim: '#ffb59a'
  on-primary-fixed: '#380d00'
  on-primary-fixed-variant: '#802900'
  secondary-fixed: '#c0ebe7'
  secondary-fixed-dim: '#a5cecb'
  on-secondary-fixed: '#00201f'
  on-secondary-fixed-variant: '#254d4b'
  tertiary-fixed: '#6dfe9c'
  tertiary-fixed-dim: '#4de082'
  on-tertiary-fixed: '#00210c'
  on-tertiary-fixed-variant: '#005227'
  background: '#121415'
  on-background: '#e2e2e3'
  surface-variant: '#333536'
typography:
  display-hero:
    fontFamily: Inter
    fontSize: 56px
    fontWeight: '700'
    lineHeight: 60px
    letterSpacing: -0.03em
  display-hero-mobile:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.025em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-numeric:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-caps:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system approaches meditation not as mystical escapism or wellness indulgence, but as mental conditioning—tactile, rigorous, and communal. Drawing from the utilitarian precision of Strava and the fluid, nocturnal immersion of Spotify, the interface treats mindfulness with athletic seriousness: metrics matter, shared effort builds momentum, and visual clarity takes precedence over ornamentation.

There are no lotus flowers, singing bowls, pastel gradients, or faux-enlightened euphemisms. The tone of voice is plain, disciplined English: "Begin Practice," "Sit Complete," "Active Now," and "Keep the Streak."

The visual style blends hyper-focused dark minimalism with structural micro-borders and deliberate pops of vital kinetic color. Primary surfaces sit deep in near-black charcoal, receding so that live signals, breathing cadences, and session timers act as ambient light sources. Interactions are crisp, weighted, and direct, cultivating quiet resolve and sustained focus.

## Colors

The palette operates under a strict dark-mode-first hierarchy engineered for OLED panels, nighttime utility, and reduced ocular strain during low-light sessions.

- **Background Base (`#0B0D0E`)**: The ground plane across all mobile screens.
- **Sunken Surface (`#050607`)**: Used strictly during active sessions, focused breathing states, and time-in-flight audio views to recede peripheral awareness.
- **Raised Surface (`#16191B`)**: Used for cards, sheets, player trays, and list item containers.
- **Primary Color (`#FF7A45` / Ember)**: Reserved for primary conversion vectors, active record states, timer fills, and habit streaks. It supplies kinetic, athletic warmth without triggering emergency alarms.
- **Secondary Color (`#123C3A` / Deep Spruce)**: Used for specialized tags, category headers, subtle tinted backdrops, and active toggle track fills.
- **Live Signal (`#4ADE80` / Neon Green)**: Exclusively communicates real-time synchronization, peer presence, active room participants, and operational health.
- **Text & Accents**:
  - High-Emphasis Content: `#F5F7F7`
  - Medium-Emphasis / Metadata: `#9AA3A6`
  - Structural Borders: `#22272B` (or `rgba(255, 255, 255, 0.07)`)
  - Destructive / Critical Alert: `#E5484D`

## Typography

Typography relies entirely on Inter to ensure clean screen rendering and native platform harmony across iOS and Android.

- **Tabular Figures**: All timer numbers, metrics, participant counts, and duration displays must enforce OpenType tabular figures (`font-feature-settings: "tnum" 1`) to eliminate jitter during active real-time updates.
- **Micro-Labels**: Category tags, live state tags, and telemetry headers leverage uppercase tracking (`label-caps`) with 0.08em letter spacing for rapid glanceability.
- **Rhythm**: Body copy enforces generous line-heights (1.5x–1.6x) to preserve spaciousness and prevent visual fatigue in high-contrast dark environments.

## Layout & Spacing

The layout is built around mobile-first utility, using an 8pt-based step scale anchored by 4pt micro-increments.

- **Mobile Canvas**: 4-column fluid grid on mobile devices (<600px) with `16px` outer margins and `16px` gutters.
- **Tablet / Large Handhelds**: 8-column layout with `24px` outer margins and `16px` gutters, centering active playback components at a maximum width constraint of `480px`.
- **Vertical Hierarchy**:
  - `space-xs` (4px): Spacing between icon labels and badges.
  - `space-sm` (8px): Gaps between chips, metadata tags, and metric items.
  - `space-md` (16px): Internal padding inside cards, standard stack spacing between related controls.
  - `space-lg` (24px): Padding between visual sections, cards in vertical feeds, and player control groups.
  - `space-xl` (32px): Structural spacing around hero numbers, timer countdown rings, and payoff card summaries.

## Elevation & Depth

This system discards diffuse drop shadows in favor of surface tonal tiers paired with razor-sharp structural boundaries.

- **Tier 0 (Sunken Ground - `#050607`)**: The active meditation space, immersive audio screen, and sheet backing. Has no borders or ornamentation.
- **Tier 1 (Base Viewport - `#0B0D0E`)**: Primary app canvas for standard navigation tabs (Today, Library, Together, You).
- **Tier 2 (Raised Blocks - `#16191B`)**: Content cards, sheet surfaces, bottom nav bar, and sticky headers. Boundaries are enforced with a crisp 1px perimeter border set to `#22272B` (or `rgba(255, 255, 255, 0.07)`).
- **Tier 3 (Floating Controls & Overlays - `#1C2023`)**: Draggable audio mix pills, popovers, and sticky playback trays. These use a 1px border at `rgba(255, 255, 255, 0.12)` accompanied by an ambient dark contact shadow: `0 8px 24px rgba(0, 0, 0, 0.6)`.

## Shapes

The geometry balances structural stability with ergonomic thumb interactions:

- **Large Surfaces (16px - `rounded-lg`)**: Content cards, session workout summaries, breathing module viewports, and modal bottom sheets.
- **Controls & Form Inputs (12px - `rounded-md`)**: Interactive items, secondary buttons, volume/mix slider hit-boxes, and segmented controls.
- **Pills (9999px - `rounded-full`)**: Interactive presence badges, status chips, primary action buttons (CTA), quick-activation SoS buttons, and scrubber thumb targets.

## Components

### Buttons & Interactive Controls
- **Primary CTA**: Full pill shape (`rounded-full`), `#FF7A45` Ember fill with `#0B0D0E` bold text. On press, scales to `0.98` with an inner brightness dip.
- **Secondary Action**: `#16191B` surface with 1px border (`#22272B`), pill or `12px` radius, `#F5F7F7` text.
- **Persistent Header SoS Chip**: Positioned in the top app bar across all primary tabs. Compact pill container (`height: 32px`) filled with `#16191B`, outlined with `rgba(255, 255, 255, 0.1)`. Features a muted `#E5484D` dot and "Reset" or "SoS" in `label-caps` for immediate panic/grounding access.

### Badges & Presence Indicators
- **Live Presence Indicator**: A pill wrapper (`#16191B`, border `#22272B`) framing a 6px circular dot in `#4ADE80`. The dot contains a non-intrusive CSS radar pulse (1.8s loop). Accompanied by tabular count: `"1,420 sitting now"`.

### Navigation Architecture
- **Bottom Navigation Dock**: Fixed 4-tab bar (Today, Library, Together, You). Background: `#16191B` at 92% opacity with `backdrop-filter: blur(16px)`. Border top: 1px `#22272B`. Active tab uses `#FF7A45`; inactive tabs rest at `#9AA3A6`.

### Active Session & Player Experience
- **Breathing Ring Container**: Positioned centrally over `#050607`. Built with clean SVG concentric strokes. The base track is `1.5px` at `rgba(255, 255, 255, 0.08)`. The animated active pacing stroke uses `#FF7A45` or `#4ADE80` depending on the session intent (Power vs. Recovery).
- **Audio Mix Sliders**: Dual or triple vertical/horizontal slider tracks (`#16191B` background, 12px radius) allowing independent balancing of Voice, Ambient Drone, and White Noise. Active filled run uses `#F5F7F7`.

### Strava-Inspired Payoff Cards
- **End-of-Session Summary**: High-contrast `#16191B` card with `16px` radius and crisp outline. Features a bold numerical telemetry stack: Total Minutes, Heart Rate Delta (if paired), Streak Count (`#FF7A45`), and Avatars of participants who completed the sit simultaneously. Clean shareable export option formatted for device capture without decorative clutter.
