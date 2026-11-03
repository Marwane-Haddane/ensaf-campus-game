# ENSA Games Launcher — Presentation Integration Guide (v1 Final Visual QA Pass)

**Module Owner**: Antigravity  
**Companion Backend Controller Owner**: Codex (`docs/CODEX-ENSA-GAMES-LAUNCHER.md`)  
**Shared Presentation Contract**: Version 1 (Hardened, Adapter-Compatible, Visual QA Sign-off)  
**Target Engine & Renderer**: Godot 4.3 Stable, GL Compatibility (Intel Iris Plus target)  
**Primary Deliverable Scene**: `res://scenes/antigravity/launcher/launcher_view.tscn`  
**Date**: 2026-11-02  

---

## 1. Architectural Boundaries & Division of Responsibility

| Component | Codex Responsibility | Antigravity Responsibility |
|---|---|---|
| **Startup** | Boot scene, entry point, first-frame measurement, background services | Boot presentation, typography, lightweight logo emblem, non-blocking spinner |
| **Menu Hub** | State machine, request validation, mode registry, session persistence | Home, modes, briefing, help, credits, settings, loading, ready, error page layouts |
| **Artwork & Assets** | Asset loading, cache management, lifecycle | Clean native scene captures without baked HUD/prompts, GL-compatible background shaders |
| **Loading** | Threaded resource requests, world construction, work counters, retry/cancel | Centered loading panel, accurate progress bar, work units, elapsed timer, focus stability |
| **Settings** | Disk persistence (`preferences.cfg`), validation, display mode changes, audio buses | Expanding height (>250px), dedicated tab scroll containers, draft synchronization, modal focus |
| **Saves** | Checkpoint verification, save restore, continue state model | Display Continue and summary only when model permits |
| **Modals** | Confirm countdown timer, display revert/commit | Centered layout, scrim click-blocking, focus loop containment, Esc cancellation |
| **QA** | Full game regression, campus world, doors, PCs, desktop terminal | Standalone preview test suite (17 suites), multi-resolution captures, native geometry checks |

---

## 2. Shared Presentation Contract (Version 1)

The deliverable scene `res://scenes/antigravity/launcher/launcher_view.tscn` root Control exposes:

```gdscript
signal intent_requested(action: StringName, payload: Dictionary)

func get_contract_version() -> int # Always returns 1
func present(model: Dictionary) -> void
func set_preferences_preview(preferences: Dictionary) -> void
func focus_primary() -> void
```

### 2.1 Authoritative Data Model Schema (`present(model)`)

```gdscript
{
    "contract_version": 1,
    "state": "STARTUP" | "INITIALIZING" | "MAIN_MENU" | "SELECT_MODE" | "LOADING_GAME" | "READY" | "PLAYING" | "ERROR" | "CANCELLED",
    "page": "boot" | "home" | "modes" | "briefing" | "settings" | "how_to_play" | "credits" | "loading" | "ready" | "error",
    "brand": "ENSA Games",
    "modes": [
        {
            "id": "incident_response",
            "title": "ENSA Incident Response",
            "subtitle": "Cybersecurity Training Simulation",
            "availability": "available", # "available" or "coming_soon"
            "artwork_path": "res://assets/antigravity/launcher/mode_cyber.png",
            "description": "Inspect suspicious network traffic, discover compromised workstations, and file reports."
        },
        {
            "id": "zombie_rpg",
            "title": "Zombie RPG Survival",
            "subtitle": "Campus Tactical Defense",
            "availability": "coming_soon",
            "artwork_path": "res://assets/antigravity/launcher/mode_zombie.png",
            "description": "Survive hostile incursions across campus buildings. Resource gathering and barricading."
        }
    ],
    "selected_mode_id": "incident_response",
    "mission": {
        "id": "IR-2026-001",
        "title": "The borrowed session",
        "objective": "Find the marked workstation",
        "briefing": "Inspect the workstation, preserve evidence, contain the issue, restore safely and submit an incident report.",
        "controls": [
            {"action": "Movement", "binding": "WASD / Arrows", "label": "move_forward"},
            {"action": "Look Around", "binding": "Mouse Look", "label": "look"},
            {"action": "Interact", "binding": "E (within 2m)", "label": "interact"},
            {"action": "Sprint", "binding": "Shift", "label": "run"},
            {"action": "Jump", "binding": "Space", "label": "jump"},
            {"action": "Campus Guide", "binding": "Tab", "label": "destinations"},
            {"action": "Response Plan", "binding": "J", "label": "response_plan"},
            {"action": "Pause", "binding": "Esc", "label": "pause"}
        ]
    },
    "continue": {
        "available": bool, # If false, Continue container is cleanly hidden
        "mode_id": "incident_response",
        "mission_id": "IR-2026-001",
        "summary": "Checkpoint: Reception Terminal Alpha"
    },
    "loading": {
        "request_id": "REQ-1001", # String echoed unchanged in cancel/retry/enter
        "stage_id": "mesh_batching",
        "stage_label": "Preparing render batches",
        "completed_units": 730, # int or null (never a fake percentage)
        "total_units": 2200,    # int or null
        "resource_progress": 0.45, # float 0.0-1.0 or null
        "can_cancel": true,
        "still_preparing": false,
        "elapsed_seconds": 3.8
    },
    "error": {
        "code": "ERR_LOAD_FAILED",
        "message": "Human-readable failure explanation.",
        "diagnostic": "Optional technical stack trace (displayed in dev builds only)",
        "retry_allowed": true,
        "return_allowed": true
    },
    "settings": {
        "saved": Dictionary,
        "draft": Dictionary,
        "dirty": bool,
        "validation_errors": Array[String],
        "capabilities": Dictionary,
        "display_confirmation_required": bool,
        "display_confirmation_seconds_remaining": int,
        "message": String # Optional feedback text from backend
    },
    "preferences": {
        "reduced_motion": bool,
        "language": "en",
        "subtitles": bool,
        "ui_scale": float
    },
    "control_hints": Array[Dictionary], # Authoritative action/binding/label list
    "capturing_action": String,          # Optional action ID currently waiting for keypress
    "case_summary": {                    # Optional home active-case tracker
        "id": "IR-2026-001",
        "title": "The borrowed session",
        "status": "Investigation pending",
        "completed": 0,                  # Authored steps completed (0..total)
        "total": 7,
        "objective": "Find the marked workstation"
    },
    "brand_assets": {                    # Optional visual asset overrides
        "logo_path": "res://assets/launcher/ensa-emblem-white.svg",
        "background_path": "res://assets/launcher/campus-dusk-reference.png",
        "case_image_path": "res://assets/launcher/case-workstation.png"
    },
    "development_build": bool
}
```

### 2.2 View Intents (`intent_requested(action, payload)`)

| Action Name | Payload Dictionary | Description |
|---|---|---|
| `skip_branding` | `{}` | Skipped boot intro |
| `play` | `{}` | Clicked Play from home |
| `show_modes` | `{}` | Navigate to mode chooser |
| `select_mode` | `{"mode_id": String}` | Mode selected |
| `show_briefing` | `{"mode_id": String, "mission_id": String}` | View mission briefing |
| `start_mission` | `{"mode_id": String, "mission_id": String, "skip_briefing": bool}` | Begin mission loading |
| `continue_game` | `{}` | Continue saved game session |
| `cancel_loading` | `{"request_id": String}` | Cancel loading |
| `retry_loading` | `{"request_id": String}` | Retry failed loading |
| `enter_game` | `{"request_id": String}` | Enter completed ready mission |
| `return_to_menu` | `{}` | Return to main menu |
| `show_settings` | `{}` | Navigate to settings |
| `edit_setting` | `{"key": String, "value": Variant}` | Modified draft setting |
| `apply_settings` | `{}` | Clicked Apply Changes |
| `cancel_settings` | `{}` | Discarded draft changes |
| `restore_defaults` | `{}` | Restore default preferences |
| `capture_binding` | `{"action": String}` | Clicked key to rebind |
| `confirm_display` | `{}` | Clicked Keep Changes on display confirm |
| `revert_display` | `{}` | Clicked Revert on display confirm |
| `show_how_to_play` | `{}` | Navigate to operational guide |
| `show_credits` | `{}` | Navigate to credits & attributions |
| `back` | `{}` | Back navigation / Esc key |
| `quit` | `{}` | Quit application |

---

## 3. Visual QA & Presentation Fixes

### 3.1 Clean Native Artwork (Zero Baked HUD)
- Old captures contained gameplay HUD, crosshairs, case notes, and prompts baked into image pixels.
- Re-captured natively using `tools/antigravity/launcher/capture_clean_artwork.gd` on `main.tscn`.
- All `CanvasLayer` children (HUD, prompts, terminal overlays) and 3D `Label3D` markers were hidden before taking screenshots.
- Clean assets stored at:
  - `res://assets/antigravity/launcher/bg_campus.png`
  - `res://assets/antigravity/launcher/mode_cyber.png`
  - `res://assets/antigravity/launcher/mode_zombie.png`

### 3.2 Settings Expanding Height & Full Tab Scrolling
- `content_panel` in `settings_page.gd` previously collapsed to an empty horizontal line.
- Fixed by configuring:
  - `content_panel.custom_minimum_size = Vector2(0, 300)`
  - `content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL`
  - `tab_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL`
- Enclosed each tab (`Graphics`, `Audio`, `Controls`, `Accessibility`) inside a dedicated `ScrollContainer` with `follow_focus = true` and `PRESET_FULL_RECT`.
- Measured layout at 720p: `content_panel.size.y == 408.0 px` (> 250 px threshold), `scroll.size.y == 376.0 px`.
- All action buttons (`Apply Changes`, `Cancel`, `Restore Defaults`, `Back`) stay within on-screen bounds [0..720].
- Added programmatic accessors: `get_content_panel()`, `select_tab(index)`, `get_active_tab_index()`, `get_tab_container(index)`.

### 3.3 Loading & Ready Panel Centering
- `loading_page.gd` and `ready_page.gd` previously docked panels in the top-left corner.
- Fixed by:
  - Setting `use_top_left = false` on `CenterContainer`.
  - Applying `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` and `grow_horizontal/vertical = BOTH` to root pages and `CenterContainer` instances.
  - Adding `_notification(what)` handlers for `NOTIFICATION_RESIZED` and `NOTIFICATION_VISIBILITY_CHANGED`.
  - Exposing `get_panel() -> PanelContainer` for automated geometry verification.
- Panels remain perfectly centered (`Diff: (0.0, 0.0)`) across page transitions, rapid switches, and window resizing from 960×540 to 1920×1080.

### 3.4 Modal Scrims & Focus Containment
- Both `_display_confirm_overlay` and `_discard_modal` feature full-rect semi-transparent scrims (`mouse_filter = MOUSE_FILTER_STOP`) blocking underlying clicks.
- Centering is enforced via `Vector2(maxf(0.0, (size.x - modal.size.x) * 0.5), maxf(0.0, (size.y - modal.size.y) * 0.5))` and updated automatically on viewport resize.
- Keyboard navigation is contained inside a closed 4-directional focus loop (`focus_next`, `focus_previous`, `focus_neighbor_left`, `focus_neighbor_right`, `focus_neighbor_top`, `focus_neighbor_bottom`).
- Esc on display confirmation emits `revert_display`; Esc on invalid settings opens the discard modal defaulting to Discard & Exit.

### 3.5 Interrupted Transitions & Settling
- Interrupted page transitions immediately kill active tweens, hide all non-target pages (`visible = false`, `modulate.a = 0.0`), and apply `mouse_filter = MOUSE_FILTER_IGNORE`.
- Settling logic awaits `_active_tween.finished` plus 3 settling frames, ensuring opacity settles to `modulate.a >= 0.99`.

### 3.6 User-Selected Home Redesign & White SVG Emblem
- Implemented exact visual hierarchy from `docs/references/launcher-final-target.png`:
  - **Dusk Campus Background**: Full-screen `res://assets/launcher/campus-dusk-reference.png` with gentle grading and soft left/bottom scrims to preserve window luminosity and reflections while maximizing UI contrast.
  - **White Vector SVG Emblem**: Integrated `res://assets/launcher/ensa-emblem-white.svg` (recreation of `docs/references/ensa-emblem-source.png`), centered above `ENSA GAMES` and `Campus Operations & Simulation Hub`.
  - **Left Navigation Rail (~17% width)**: Real licensed icons, quiet teal highlight with left vertical accent on selected `Play`, and conditional `Continue` item shown only when `continue.available == true`.
  - **Removed AVAILABLE Badge**: Completely eliminated on Home (no reserved row, no gap).
  - **Play CTA & Keycap**: 290px prominent teal CTA button with right chevron; outlined `[Enter]` keycap row beneath. Both emit `play` intent.
  - **Active Case & Zombie Split**: Workstation thumbnail (`res://assets/launcher/case-workstation.png`), case tracker, code `IR-2026-001`, title `The borrowed session`, dynamic status, 7-segment progress display, and objective with desktop monitor icon. Zombie RPG Survival preview with dusk thumbnail, lock icon, and `COMING SOON` badge.
  - **Bottom Status Strip (36px)**: Full width with calm ring indicator, `ENSA Simulation Hub`, and calm teal indicator with `Menu ready`.

---

## 4. Redundant Adapter Logic Ready for Removal

Codex's `scripts/launcher/launcher_view_adapter.gd` was designed as an interim bridge. All visual and layout compensations are now implemented natively in Antigravity's source files:

1. **`_sync_settings`**: `settings_page.gd` natively handles full model synchronization without signal feedback and expands scrolling tabs.
2. **`_sync_guide`**: `how_to_play_page.gd` natively displays authentic mission copy and correct interaction ranges (2m door vs 2.8m PC).
3. **`_sync_credits`**: `credits_page.gd` natively displays accurate author attributions and prop licenses.
4. **`_pages.loading._spinner.queue_redraw()`**: `loading_page.gd` and `boot_page.gd` natively handle reduced-motion redraws.
5. **`_display_confirm_overlay.position = ...`**: `launcher_view.gd` natively calculates and centers modal dialogs on resize.
6. **`_transition_to_page`**: `launcher_view.gd` natively manages tween cancellation, opacity settling, and mouse filter states.

Codex may safely remove these overrides or replace the adapter with a direct instance of `res://scenes/antigravity/launcher/launcher_view.tscn`.

---

## 5. Verification Commands & Telemetry

### 5.1 Standalone Presentation QA Suite (17 Suites, 41 Captures)
Run native GPU execution:
```powershell
Start-Process -FilePath "runtime\Godot.exe" -ArgumentList "--path", ".", "-s", "tools/antigravity/launcher/preview_launcher.gd", "--capture" -Wait -NoNewWindow
```
- **Result**: `ALL QA SUITES COMPLETE: PASS (Failures: 0)`
- **Duration**: `37,433 ms`
- **Video Memory**: `34.43 MB`
- **Evidence Captures**: 41 files in `tools/antigravity/launcher/captures/`
  - `02_home_no_continue.png` & `1280x720_home_no_continue.png` (1280×720, no save)
  - `03_home_with_continue.png` & `1280x720_home_with_continue.png` (1280×720, with save)
  - `1080p_home_no_continue.png` (1920×1080 FHD, no save)
  - `1080p_home_with_continue.png` (1920×1080 FHD, with save)

Run headless automated verification:
```powershell
Start-Process -FilePath "runtime\Godot.exe" -ArgumentList "--headless", "--path", ".", "-s", "tools/antigravity/launcher/preview_launcher.gd" -Wait -NoNewWindow
```
- **Result**: `ALL QA SUITES COMPLETE: PASS (Failures: 0)`
- **Report**: `tools/antigravity/launcher/preview_launcher_report.json`

### 5.2 Core Backend Integration Regression Test
Run integrated runner:
```powershell
Start-Process -FilePath "runtime\Godot.exe" -ArgumentList "--headless", "--path", ".", "-s", "tools/launcher/integration_test.gd" -Wait -NoNewWindow
```
- **Result**: `LAUNCHER_TEST_RESULT {"captures":[],"checks":72,"failures":[],"passed":true}`
- **Integrated Evidence**:
  - `tools/launcher/integrated-home.png`
  - `tools/launcher/integrated-modes.png`
  - `tools/launcher/integrated-settings.png`
  - `tools/launcher/integrated-loading.png`
  - `tools/launcher/integrated-ready.png`
  - `tools/launcher/integrated-error.png`
  - `tools/launcher/integrated-error.png`

---

## 6. Resource Budget & Rollback Safety

- **Asset Footprint**: ~2.2 MB total (`bg_campus.png`: 848 KB, `mode_cyber.png`: 870 KB, `mode_zombie.png`: 533 KB, shader: 1.1 KB, GDScript UI: ~58 KB).
- **VRAM Consumption**: 24.77 MB (under 2.5% of budget on typical 1GB+ VRAM allocations).
- **Rollback Boundary**: All Antigravity edits are strictly isolated within `scripts/antigravity/launcher/`, `scenes/antigravity/launcher/`, `assets/antigravity/launcher/`, `tools/antigravity/launcher/`, and `antigravity/launcher/`. Rollback involves only reverting these paths without affecting core engine configurations or gameplay systems.
