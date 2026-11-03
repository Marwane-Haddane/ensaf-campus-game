# Antigravity Acceptance Report: Combined ENSA Games Launcher

**Date:** 2026-11-02  
**Target:** Windows PC (Intel Iris Plus class hardware / Godot 4.3 GL Compatibility)  
**Deliverable:** `antigravity/launcher/FINAL-ACCEPTANCE.md`  
**Companion Documents:** `docs/ANTIGRAVITY-FINAL-INTEGRATED-ACCEPTANCE.md`, `docs/CODEX-ENSA-GAMES-LAUNCHER.md`, `docs/LAUNCHER-STATUS.md`

---

## 1. Acceptance Verification Matrix

| Check / Verification Item | Resolution / Input Mode | Actual Result | Evidence Path | Remaining Issues |
|---|---|---|---|---|
| **First-Frame Boot & Menu Readiness** | 1280×720 Native | Boots in 13.5ms; menu interactive in ~837ms. Still dusk artwork loaded without 3D campus instantiation or CPU stalls. | `tools/launcher/reference-home-1280x720.png` | None |
| **Reference Home Geometry & Scaling** | 1280×720, 1920×1080, 960×540, 1280×1024, 1920×720 | 39 / 39 geometry assertions passed. Proportional layout scales cleanly from 0.75× to 1.5× without text truncation or clipping. | `tools/launcher/home-visual-final.log` | None |
| **Emblem Visual Compliance** | All display resolutions | Vector SVG USMBA seal (`ensa-emblem-white.svg`) rendered in pure white monochrome with transparent background. No blue/red pixels, no embedded rasters. | `res://assets/launcher/ensa-emblem-white.svg` | None |
| **Absence of AVAILABLE Badge** | All display resolutions | Green `AVAILABLE` badge and empty row removed above `ENSA Incident Response`. Hero block aligns cleanly. | `scripts/antigravity/launcher/home_page.gd#L271` | None |
| **Left Rail Navigation Chain** | Keyboard (Arrows/Tab/Enter/Space) & Mouse | Seamless focus transfer across `Play`, `Game Modes`, `Continue`, `Settings`, `How to Play`, `Credits`, `Quit`. High-contrast teal selection bar. | `tools/launcher/reference-home-continue-1920x1080.png` | None |
| **Honest Continue Restoration** | 1280×720 & 1920×1080 | Absent when save missing; dynamically displays checkpoint summary when valid. Quit remains visible and never pushed off-screen. | `tools/launcher/reference-home-test.json` | None |
| **Settings Panel Layout & Tabs** | 1280×720 & 1920×1080 | All 4 tabs (Graphics, Display, Audio, Input) expand to fill parent (>400px scroll container). Apply, Defaults, Cancel stay visible. | `tools/launcher/settings_test.gd` | None |
| **Modal Scrims & Focus Isolation** | 1280×720 & 1920×1080 | Display confirmation and unsaved changes modals center mathematically. Scrim blocks clicks to underlying buttons. Focus trapped within modal. | `scenes/antigravity/launcher/settings_view.gd` | None |
| **Full Core Launcher Integration** | Headless & Windowed (1280×720) | 72 / 72 checks passed. Staged resource loading, error recovery, settings persistence, checkpoint save/restore verified. | `tools/launcher/integration_test.gd` | None |
| **Multi-Mode Shared Pipeline** | Headless & Windowed | 29 / 29 checks passed. Mode selection, brief branding, ready freeze, Esc pause/resume toggle, safe session restore verified. | `tools/launcher/zombie_launcher_test.gd` | None |
| **Zombie RPG Systems & Melee** | Headless Unit Suite | 110 / 110 checks passed. Inventory, bat melee swing (<kbd>V</kbd>), weapon swap, checkpoint integrity, mode adapter verified. | `tools/antigravity/zombie/test_systems.gd` | None |
| **Zombie RPG Full Integration** | Headless Full Simulation | 94 / 94 checks passed. Unfrozen session, uncaptured mouse behind Loading/Ready, brute encounter, power restoration, extraction win state. | `tools/antigravity/zombie/test_integration.gd` | None |
| **Campus Playthrough Verification** | Headless Playthrough | 12 / 12 checks passed across 7 mission checkpoints (`cp_start` to `cp_extraction`). | `tools/antigravity/zombie/test_playthrough.gd` | None |
| **Cybersecurity Mode Regressions** | Headless | Passed (8 checks, 100 points, zero regressions against workstation puzzles or training state). | `tests/training_state_test.gd` | None |

---

## 2. Photographic & Visual Artifact Evidence

1. **Combined Home Screen (1280×720 Baseline)**:
   - File: `tools/launcher/reference-home-1280x720.png`
   - Verified: Dusk campus background, white vector crest, navigation rail, Play CTA, active case summary, Zombie RPG preview card (COMING SOON), and calm bottom status strip ("Menu ready").
2. **Combined Home Screen (1920×1080 Proportional Scale)**:
   - File: `tools/launcher/reference-home-1920x1080.png`
   - Verified: Proportional typography scaling (`1.5×` factor) without text blurring, overlapping cards, or clipping.
3. **Combined Home Screen with Valid Continue Saved Session**:
   - File: `tools/launcher/reference-home-continue-1920x1080.png`
   - Verified: Indented checkpoint summary beneath Continue button; Quit button remains fully on-screen and functional.
4. **Interactive Character, Enemy & Weapons Gallery**:
   - File: `character_gallery.md` & `zombie_showcase.html`
   - Verified: 12 concept archetypes, 5 in-engine animated zombie models, first-person tactical hands with illuminated watch, 4 weapons (including Barbed Bat), and 3 friendly NPCs (Matt, Lis, Shaun).

---

## 3. Test Suites & Pass Counts

| Suite | Script Path | Checks | Result | Failures |
|---|---|---|---|---|
| Launcher Core Integration | `tools/launcher/integration_test.gd` | 72 | **Passed** | 0 |
| Launcher Visual Geometry | `tools/launcher/home_visual_test.gd` | 39 | **Passed** | 0 |
| Multi-Mode Launcher Pipeline | `tools/launcher/zombie_launcher_test.gd` | 29 | **Passed** | 0 |
| Zombie RPG Core Systems | `tools/antigravity/zombie/test_systems.gd` | 110 | **Passed** | 0 |
| Zombie RPG Integration | `tools/antigravity/zombie/test_integration.gd` | 94 | **Passed** | 0 |
| Zombie 7-Checkpoint Playthrough | `tools/antigravity/zombie/test_playthrough.gd` | 12 | **Passed** | 0 |
| Training State Regression | `tests/training_state_test.gd` | 8 | **Passed** | 0 |
| **Total Automated Coverage** | — | **364** | **100% Passed** | **0** |

---

## 4. Coordination & Adapter Seam

- **Current Status of `launcher_view_adapter.gd`**:
  Codex's calibration layer in `scripts/launcher/launcher_view_adapter.gd` is operating as the production integration seam. It correctly calibrates home typography and container expansion across resolutions without interfering with Antigravity's internal hierarchy.
- **Contract Version 1 Stability**:
  All signal emissions (`intent_requested`), property getters (`get_contract_version() == 1`), and state hooks (`set_state()`, `update_continue()`, `update_case_summary()`) remain strictly compliant.
- **Zero Core File Overwrites**:
  No files in `scripts/launcher/`, `scenes/launcher/`, `scripts/main.gd`, `main.tscn`, or `project.godot` were altered.

---

## 5. Conclusion & Handoff

The combined ENSA Games launcher and Zombie RPG episode meet all requirements set forth in `docs/ANTIGRAVITY-FINAL-INTEGRATED-ACCEPTANCE.md` and `docs/ANTIGRAVITY-BIG-TASK-ZOMBIE-RPG.md`. There are no blocking presentation defects, no performance stalls, and no regressions in the cybersecurity gameplay mode.
