# Zombie RPG — Shared Launcher Integration Contract

**Mode ID:** `zombie_rpg`  
**Mission ID:** `ZB-2026-001` ("After Hours")  
**Adapter Path:** `res://scripts/antigravity/zombie/zombie_mode_adapter.gd`  
**Entry Scene:** `res://scenes/antigravity/zombie/zombie_game.tscn`

---

## 1. Concrete Integration Fixes Delivered

### A. Checkpoint Ownership & Validation (`save_store.gd`)
- **Overridable Path:** Exposes `var path: String` with production default (`user://ensagames/saves/zombie_rpg/checkpoint.json`). Derives base directory, `.tmp`, and `.bak` paths directly.
- **Shared Save Service:** `create_session` in `ZombieModeAdapter` passes the adapter's authoritative `save_service()` instance into `game.save_store`, preventing duplicate save stores.
- **Schema & Type Validation:** Strict `validate(payload: Dictionary)` checks `schema_version` (1), `mode_id` (`zombie_rpg`), `mission_id` (`ZB-2026-001`), root checkpoint IDs/names, nested types, and non-empty arrays.
- **Finite & Ranged Player Values:** Verifies finite floats, valid health bounds (`0.0 <= health <= max_health`), valid stamina bounds (`0.0 <= stamina <= max_stamina`), 3D finite coordinates (`abs(coord) <= 10000.0`), finite camera pitch and yaw.
- **Quest & Inventory Validation:** Validates non-negative integer item counts, weapon slot structures, and step indices within valid step ranges.
- **Atomic Commit Preservation:** Commits write first to `.tmp`, creates a `.bak` of existing saves, and atomically commits to the target path. If any commit failure occurs, the previous valid save file is restored intact from backup.

### B. No Initialization Overwrite (`zombie_game.gd`)
- In managed launcher sessions (`launcher_managed == true`), the initial checkpoint `cp_start` is **deferred** until intentional gameplay entry (`start()` or `start_gameplay()`).
- Loading an existing checkpoint or cancelling during loading never overwrites existing saved progress on disk.

### C. World State Restoration (`zombie_mode_adapter.gd`)
- Adapter `restore(game, checkpoint)` performs semantic validation of the checkpoint payload. If invalid, returns `false` and sets `last_error`.
- Executes `_resync_world_state()` to eliminate defeated enemies (boss does not resurrect), despawn collected pickups (no duplicate rewards), and restore substation power state.
- Refreshes HUD elements (`_refresh_hud()`) with restored health, stamina, ammo, weapon slot, scrap, and objective text.
- Verifies safe player standing pose via ground collision clearance check (`_verify_safe_player_pose()`).
- Freezes restored session state (`freeze(game)`) until the launcher explicitly calls `start(game)`.

### D. Managed Replay & Reset
- In managed sessions, calling retry or restart emits `launcher_restart_requested` and performs a mode-local reset (`_reset_mode_state()`), preserving the launcher's root tree.
- Standalone mode retains `get_tree().reload_current_scene()`.

### E. Pause & Input Lifecycle & Escape Key Handling
- Game session root explicitly sets `process_mode = Node.PROCESS_MODE_PAUSABLE`.
- When the game is paused, all game entities freeze while launcher/HUD menus remain responsive (`PROCESS_MODE_ALWAYS`).
- `zombie_hud.gd` implements `_unhandled_input` under `PROCESS_MODE_ALWAYS` to reliably catch the second <kbd>Esc</kbd> keypress while the SceneTree is paused, resuming the game, restoring input capture, and consuming the event via `get_viewport().set_input_as_handled()`.
- When initializing or frozen, attacks, damage, shooting, and mouse look are blocked; mouse capture remains visible (`MOUSE_MODE_VISIBLE`).
- `cancel_initialization()` sets `campus.cancelled = true` on `CampusRuntime`, unwinding background mesh coroutines cleanly, and reports `initialization_finished = true`, `ready_to_play = false`, `initialization_error = "Initialization cancelled"`.

### F. Shared Preferences & Graphics Settings
- Movement, sprint, jump, and interact inputs read from Godot's `InputMap` actions (`move_forward`, `move_back`, `move_left`, `move_right`, `run`, `jump`, `interact`, `pause`) with graceful key fallbacks.
- Mouse sensitivity and reduced-motion preferences apply dynamically to player controller and HUD camera bob/shake.
- Pause menu "Settings" button emits `settings_requested` without mutating or toggling preferences locally.
- Supported graphics settings via shared launcher:
  - Presets: `low` (MSAA disabled, shadows simplified), `medium` (MSAA 2X, 40m shadows), `high` (MSAA 4X, 60m shadows)
  - Display Resolutions: `1280x720`, `1600x900`, `1920x1080`
  - Window Modes: Windowed, Fullscreen
  - VSync: Enabled / Disabled
  - Frame Limits: 30 FPS, 60 FPS, Unlimited (0)

### G. HUD Anchoring & Viewmodel Calibration
- Responsive HUD bounding boxes configured with `grow_vertical = GROW_DIRECTION_BEGIN` and explicit margins across all resolutions (960×540, 1280×720, 1920×1080).
- Bottom-left health/stamina/scrap bars and bottom-right weapon/ammo indicators stay strictly within safe margins.
- Viewmodel scale and camera clearance calibrated for Pistol, CZ Scorpion EVO 3 SMG, and Benelli M4 Tactical Shotgun with zero near-plane clipping.
- Dusk atmosphere uses `ProceduralSkyMaterial`, ACES tone-mapping, and anti-acne shadow parameters (`shadow_bias = 0.12`, `shadow_normal_bias = 2.0`).

### H. Metadata Contract (`MODE-REGISTRATION.json`)
- Mission controls are formatted as an Array of `{ "action": "...", "binding": "..." }` dictionaries.
- Save summary returns a dictionary containing formatted `label`, mode/mission IDs, checkpoint name, health, and scrap.

---

## 2. Adapter Interface Reference

```gdscript
func required_resources() -> Array[String]
func entry_scene() -> String
func create_session(resources: Dictionary, preferences: Dictionary) -> Node3D
func initialization_finished(game: Node3D) -> bool
func validate_ready(game: Node3D) -> bool
func validate_spawn(game: Node3D) -> bool
func error_detail(game: Node3D) -> String
func cancel(game: Node3D) -> void
func freeze(game: Node3D) -> void
func start(game: Node3D) -> void
func set_input(game: Node3D, enabled: bool) -> void
func connect_events(game: Node3D, on_return: Callable, on_settings: Callable, on_progress: Callable) -> void
func apply_preferences(game: Node3D, preferences: Dictionary) -> void
func capture(game: Node3D) -> Dictionary
func restore(game: Node3D, checkpoint: Dictionary) -> bool
func is_ready(game: Node3D) -> bool
func save_service() -> RefCounted
```

---

## 3. Verification Commands

1. **Shared Launcher Integration Harness:**
   ```powershell
   & "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --script res://tools/launcher/zombie_launcher_test.gd
   ```
   *(Result: 29 / 29 checks passed, 0 failures)*

2. **Core Systems Unit Tests:**
   ```powershell
   & "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --script res://tools/antigravity/zombie/test_systems.gd
   ```
   *(Result: 110 / 110 checks passed, 0 failures)*

3. **Full End-to-End Integration Tests:**
   ```powershell
   & "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --script res://tools/antigravity/zombie/test_integration.gd
   ```
   *(Result: 94 / 94 checks passed, 0 failures)*

4. **Real Campus Playthrough Scenario:**
   ```powershell
   & "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --script res://tools/antigravity/zombie/test_playthrough.gd
   ```
   *(Result: 12 / 12 checks passed, 0 failures across all 7 checkpoints)*

5. **Reference Home Visual Layout:**
   ```powershell
   & "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --script res://tools/launcher/home_visual_test.gd
   ```
   *(Result: 39 / 39 checks passed across 5 display resolutions)*
