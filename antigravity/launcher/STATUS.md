# Antigravity Status Report: ENSA Games Launcher Presentation Module (User-Selected Home Redesign Milestone)

**Project**: ENSA Fez Incident Response Training Game (`campus-game`)  
**Companion Backend Task**: `docs/CODEX-ENSA-GAMES-LAUNCHER.md`  
**Current Milestone**: User-Selected Home Design & White SVG Emblem Integration Complete  
**Contract Version**: 1 (Fully Compatible with Codex Launcher Core & Adapter)  
**Date**: 2026-11-02  

---

## 1. Executive Summary

Antigravity has implemented and verified the native launcher home screen redesign matching the user's latest selected visual direction (`docs/references/launcher-final-target.png`), incorporating the pure white vector emblem recreation of Université Sidi Mohamed Ben Abdellah (`docs/references/ensa-emblem-source.png` -> `res://assets/launcher/ensa-emblem-white.svg`), and eliminating the "AVAILABLE" badge entirely.

Key achievements in this milestone:

1. **Full-Screen Dusk Campus Presentation**:
   - Integrated `res://assets/launcher/campus-dusk-reference.png` as default menu artwork.
   - Refined `shaders/antigravity/launcher/background_grade.gdshader` to preserve warm interior window glow and wet courtyard reflections without crushing shadows, adding subtle left and bottom scrims for high UI contrast.
   - Preserved purely as still menu illustration without instantiating 3D campus geometry behind the home screen.
2. **Fixed Left Navigation Rail (~17% Viewport Width)**:
   - Centered white transparent vector SVG emblem (`res://assets/launcher/ensa-emblem-white.svg`) above `ENSA GAMES` and `Campus Operations & Simulation Hub`.
   - Distinctive teal highlight and left vertical accent line on selected `Play` navigation item with play icon `▶`.
   - Real icons loaded via `LauncherTheme.load_texture_safe()` across all nav buttons (`layout-grid.svg`, `settings.svg`, `book.svg`, `file-description.svg`, `power.svg`).
   - Dynamic `Continue` item shown only when `continue.available == true` with indented checkpoint summary subtitle.
   - Dynamic focus chain updating to ensure seamless keyboard arrow navigation across all nav items.
3. **Hero & CTA Section (Completely Removed "AVAILABLE" Badge)**:
   - Hero header: Large two-line `ENSA Incident\nResponse`.
   - Subtitle: `Investigate incidents. Find evidence.\nDefend the campus.`.
   - **Zero "AVAILABLE" badge**: Completely eliminated with no reserved row or layout gap.
   - Prominent 290px vibrant teal Play CTA with dark bold label and right chevron `›`.
   - Outlined `[Enter]` keycap and `Play` label row directly beneath CTA; both emit `play` intent.
4. **Lower Split Section (Active Case & Zombie Preview)**:
   - Separated from hero section by flexible breathing room and fine divider rule, sitting cleanly on dark courtyard pavement reflections.
   - Left: Active Case section featuring workstation thumbnail (`res://assets/launcher/case-workstation.png`), `ACTIVE CASE` eyebrow, code `IR-2026-001`, title `The borrowed session`, dynamic status dot/text (`Investigation pending` / `Response in progress`), subtle 7-segment progress bar display tolerating 0 through total steps, and objective with desktop monitor icon (`device-desktop.svg`).
   - Center: Fine 1px vertical divider rule.
   - Right: Zombie RPG Survival preview card with dusk campus thumbnail (110px height, proportional 16:9), centered crisp lock icon (`lock.svg`), amber `COMING SOON` badge, title, and description (`Explore. Survive. Protect your resources.`). Purely non-interactive preview with transparent card surface.
5. **Full-Width Bottom Status Strip (36px)**:
   - Left: Calm glowing ring indicator (20px) with `ENSA Simulation Hub`.
   - Fine vertical divider.
   - Center/Right: Sub-status label and calm teal indicator with **Menu ready** (no permanent loading copy on home).
   - Elevated dev build version label to top-right to prevent overlap with lower cards.
6. **Prior Visual QA Protections Preserved**:
   - Settings content height remains expanded (>400px at 720p).
   - Loading and Ready panels remain mathematically centered at viewport center `(0.0, 0.0)`.
   - Modal scrims and focus loops remain intact.

Zero core engine or loader files (`scripts/launcher/`, `scripts/main.gd`, `scripts/campus_runtime.gd`, `main.tscn`, `project.godot`) were modified.

---

## 2. Inventory of Changed Files

### 2.1 Presentation & Script Enhancements
- `scripts/antigravity/launcher/launcher_theme.gd`:
  - Added `load_texture_safe(res_path: String) -> Texture2D` static loader. Solves the Godot engine limitation where unimported SVGs/PNGs fail `ResourceLoader.exists()` check; safely falls back to direct Image loading with path retention.
- `shaders/antigravity/launcher/background_grade.gdshader`:
  - Adjusted grading parameters (`image_brightness = 0.88`, `vignette_strength = 0.60`, `shadow_navy_mix = 0.22`).
  - Added gentle left and bottom scrims (`smoothstep`) guaranteeing text legibility over dusk courtyard lighting.
- `scripts/antigravity/launcher/boot_page.gd`:
  - Replaced legacy code-drawn shield polyline with white vector SVG `TextureRect` loading `res://assets/launcher/ensa-emblem-white.svg` via `load_texture_safe()`.
  - Added support for `brand_assets.logo_path`.
- `scripts/antigravity/launcher/launcher_view.gd`:
  - Updated default background texture path to `res://assets/launcher/campus-dusk-reference.png` using `load_texture_safe()`.
  - Added dynamic background update support for `brand_assets.background_path`.
  - Re-anchored dev build version label to `PRESET_TOP_RIGHT` with top-right offset, completely clearing lower cards and status strip.
- `scripts/antigravity/launcher/home_page.gd`:
  - Re-architected into clean root `VBoxContainer` hierarchy containing upper body HBox and 36px bottom status strip.
  - Implemented left rail with white SVG emblem, title/subtitle, selected Play teal accent, real licensed icons for all navigation items (`player-play.svg`, `layout-grid.svg`, `settings.svg`, `book.svg`, `file-description.svg`, `power.svg`), and conditional Continue item with indented checkpoint summary.
  - Added dynamic keyboard focus neighbor linkage (`_update_nav_focus_chain`) accommodating `Continue` toggles and horizontal jumps to Play CTA.
  - Implemented hero block with two-line title, supporting copy, zero "AVAILABLE" badge, 290px teal CTA, and `[Enter]` keycap row.
  - Implemented lower split section with workstation thumbnail, active case tracker, clamped 7-segment progress display, objective with desktop monitor icon (`device-desktop.svg`), and proportional Zombie RPG preview card (110px height thumbnail with centered `lock.svg`).
  - Added responsive scaling in `_update_responsive_layout` ensuring typography, thumbnails, and buttons scale smoothly across 720p, 1080p, and compact resolutions.
  - Implemented full-width 36px bottom strip with calm ring and "• Menu ready".
  - Connected `update_from_model` to consume optional `case_summary` and `brand_assets`.

### 2.2 Test Harness & Captures
- `tools/antigravity/launcher/preview_launcher.gd`:
  - Updated fixture models `02_home_no_continue` and `03_home_with_continue` with `case_summary` and `brand_assets`.
  - Added assertions in QA Case 6 verifying every navigation button icon (`_play_btn.icon`, `_modes_btn.icon`, `_settings_btn.icon`, `_how_to_play_btn.icon`, `_credits_btn.icon`, `_quit_btn.icon`, `_continue_btn.icon`), the monitor objective icon, and the Zombie preview lock icon.
  - Re-generated settled home captures at 1280×720 and 1920×1080 for both no-save and continue-ready states.
- `tools/antigravity/launcher/preview_launcher_report.json`: Updated test execution report (0 failures across 17 suites, 41 captures).
- `tools/antigravity/launcher/captures/`:
  - `02_home_no_continue.png` & `1280x720_home_no_continue.png`: Settled 720p capture without saved game.
  - `03_home_with_continue.png` & `1280x720_home_with_continue.png`: Settled 720p capture with active continue checkpoint.
  - `1080p_home_no_continue.png`: Settled 1080p FHD capture without saved game.
  - `1080p_home_with_continue.png`: Settled 1080p FHD capture with active continue checkpoint.

---

## 3. Empirical Verification Record

### 3.1 Standalone Presentation QA Suite (`tools/antigravity/launcher/preview_launcher.gd`)
Executed on **Intel Iris Plus Graphics (GL Compatibility)**:

- **Overall Status**: `PASS (0 Failures across 17 Automated Test Suites)`
- **Duration**: `33,868 ms` (Native GPU, Settled + Multi-Res Captures)
- **Captures Generated**: 41 files in `tools/antigravity/launcher/captures/`
- **Video Memory**: `34.40 MB` (Est.)

#### Test Suite Breakdown:
1. `01_settled_fixtures_rendering`: PASS (13/13 fixtures rendered with correct typography and styles)
2. `02_settings_4_tabs_geometry_and_reachability`: PASS (`content_panel` height 408px > 250px; all 4 tab scroll heights 376px; options visible with non-zero bounds)
3. `03_loading_and_ready_viewport_centering`: PASS (Loading and Ready panels centered with Diff (0.0, 0.0) at 1280×720)
4. `04_rapid_interrupted_page_transitions`: PASS (Rapid page swap mid-tween settles target page to modulate.a >= 0.99 with all prior pages hidden)
5. `05_multi_resolution_scaling_and_compact`: PASS (1080p, Compact 960×540, and Wider 1600×900 verified with perfect centering and zero clipping)
6. `06_standard_intents_contract`: PASS (All 8 standard intents captured cleanly with valid payloads)
7. `07_settings_model_sync_no_signals`: PASS (Widgets reflect draft; 0 spurious edit intents emitted; validation error displayed honestly without false success)
8. `08_key_rebinding_lifecycle`: PASS (Capture button displays "Press a key… (Esc cancels)"; completion updates to "F"; Apply enabled when dirty)
9. `09_keyboard_traversal_and_scrolling`: PASS (Keyboard navigation traverses down to bottom keybindings; `follow_focus` verified; scrolled capture saved)
10. `10_capabilities_and_honest_copy`: PASS (Single-language capability verified; unsupported languages disabled; honest copy preserved)
11. `11_modals_scrim_focus_containment`: PASS (Discard modal scrim blocks mouse clicks; 360-degree focus loop contained between Apply, Discard, Stay)
12. `12_display_confirmation_scrim_and_centering`: PASS (Display confirm overlay centered, scrim blocks mouse clicks, dismiss hides cleanly)
13. `13_loading_cancel_focus_stability`: PASS (Cancel button retains focus across rapid progress polling ticks)
14. `14_continue_and_mode_availability`: PASS (Continue hidden when unavailable; visible with summary when available; Zombie RPG is non-launchable PanelContainer; AVAILABLE badge absent; white SVG emblem verified; active case progress verified)
15. `15_indeterminate_vs_measured_progress`: PASS (Null progress shows no fake bar; measured progress displays progress bar and work units)
16. `16_reduced_motion_accessibility`: PASS (Reduced motion stops spinner rotation, sets transition duration to 0.0)
17. `17_codex_adapter_coexistence`: PASS (Codex `launcher_view_adapter.gd` coexists idempotently without conflicts or errors)

### 3.2 Geometry & Home Assertion Telemetry

| Component / Assertion | Target Scale / Expected | Measured Value | Status |
|---|---|---|---|
| **AVAILABLE Badge on Home** | Fully removed (not in tree) | `find_child("AvailablePill", ...)` == null | **PASS** |
| **Emblem Texture** | `res://assets/launcher/ensa-emblem-white.svg` | SVG resource path verified | **PASS** |
| **Play CTA Button** | ~275–305 px wide, visible | `custom_minimum_size.x == 290 px`, visible | **PASS** |
| **Enter Keycap Row** | Visible below Play CTA | `is_visible_in_tree() == true`, emits `play` | **PASS** |
| **Active Case Segments** | Tolerates 0 to total (7) | Verified 0/7 and 3/7 illuminated | **PASS** |
| **Bottom Status Strip** | Full width, height 36 px, "Menu ready" | `_bottom_strip.custom_minimum_size.y == 36 px` | **PASS** |
| **Settings `content_panel`** | Height ≥ 250 px at 720p | `Pos: (300, 196), Size: (948, 408)` | **PASS** |
| **Loading Panel Center** | Center Diff `(0.0, 0.0)` at 720p / 1080p | Measured Diff: `(0.0, 0.0)` | **PASS** |
| **Ready Panel Center** | Center Diff `(0.0, 0.0)` at 720p / 1080p | Measured Diff: `(0.0, 0.0)` | **PASS** |

### 3.3 Core Backend Integration Regression Test (`tools/launcher/integration_test.gd`)
Executed Codex's core integration harness:
- **Result**: `LAUNCHER_TEST_RESULT {"captures":[],"checks":72,"failures":[],"passed":true}`
- **Status**: 72/72 checks passing (100% pass rate).

---

## 4. Deliverable Native Screenshots

- `tools/antigravity/launcher/captures/02_home_no_continue.png` (1280×720, no save)
- `tools/antigravity/launcher/captures/03_home_with_continue.png` (1280×720, with continue save)
- `tools/antigravity/launcher/captures/1080p_home_no_continue.png` (1920×1080, no save)
- `tools/antigravity/launcher/captures/1080p_home_with_continue.png` (1920×1080, with continue save)
