# ENSA Games launcher architecture

Godot 4.3 / GDScript / GL Compatibility, Windows PC. The launcher preserves the existing first-person campus, four doors, five response stations, Linux-style training desktop and seven-step incident mission.

## Scene structure and ownership

```text
project.godot -> scenes/launcher/boot.tscn
  ENSAGames / launcher_controller.gd
    CanvasLayer 100
      Minimal first-frame boot UI
      Antigravity LauncherView (optional, loaded after first frame)
      Settings/save feedback
    MissionLoader
      Incident-response main.tscn (only after Start Mission)
        Existing player, CampusRuntime, doors, stations, training and pause UI
```

The boot scene references lightweight scripts and metadata only. It has no campus/prop GLB, game-world PackedScene or live 3D menu background. `main.tscn` remains directly runnable by existing tests. Antigravity owns its launcher presentation folders; Codex owns boot, services, gameplay integration and `scripts/launcher/launcher_view_adapter.gd`.

Services:

- `boot_state.gd`: permitted state transitions/history.
- `launcher_controller.gd`: authoritative model, intent validation, navigation, input ownership, preferences and current session.
- `mode_registry.gd`: lightweight mode descriptors and paths, including a disabled Zombie RPG preview.
- `mode_services.gd`: lazily creates the selected mode's adapter and caches its independent save service, normalizes String/Dictionary summaries and verifies checkpoint mode/mission identity. Test paths and recent-mode metadata stay isolated by mode.
- `mission_loader.gd`: threaded resource loading, request IDs, cancellation/draining, construction readiness, first-frame preparation and bounded cleanup.
- `incident_mode_adapter.gd`: cybersecurity-specific resources, readiness, input, events and checkpoint integration.
- `settings_store.gd`: saved/draft/live preferences, validation, display confirmation and persistence.
- `save_store.gd`: versioned incident checkpoints, prerequisite/points validation and safe pose restoration.
- `launcher_view_adapter.gd`: reference-home typography and proportional layout calibration on the supplied Antigravity view. Earlier settings, transition and modal behavior overrides were removed after Antigravity implemented them natively. The remaining home calibration uses the delivered home widget references and handles resize/visibility/minimum-size changes; preserve those references when updating the presentation.
- `fallback_view.gd`: basic working menu/recovery navigation if optional presentation is missing; full settings presentation uses Antigravity's supplied view.

## Lifecycle

```text
STARTUP -> INITIALIZING -> MAIN_MENU -> SELECT_MODE -> LOADING_GAME -> READY -> PLAYING
LOADING_GAME -> ERROR -> MAIN_MENU or SELECT_MODE/retry
LOADING_GAME / READY -> CANCELLED -> MAIN_MENU
PLAYING -> MAIN_MENU after saving and unloading
```

Settings/help/credits/briefing are pages within this lifecycle. Game pause remains separate. Initialization draws boot feedback first, then reads preferences/save metadata and prepares the UI. The main menu does not request the campus.

Start Mission owns a monotonically increasing request ID. Double Start, stale Enter/Retry/Cancel and late completions cannot create another playable world. The selected adapter validates readiness. For Incident Response this includes the world, collision, player, mission, four entrances and five stations; native first-frame preparation runs before Enter. Enter intentionally enables game input and mouse capture.

The hidden launcher does not consume game input. The controller and loader use always-processing so shared settings, feedback and display confirmation remain interactive during a mode's tree pause. Session roots are explicitly pausable. Ready pauses the tree after adapter freeze; floors and doors stay in the physics space. Disabling the root at Ready would remove its CollisionObject3D descendants and is deliberately avoided. Enter clears the pause and enables gameplay.

In-game Settings suspends game input; Back returns to the existing paused session. Return to Launcher saves, disables and incrementally frees the session, then clears any global pause state. A new load waits for prior cleanup/request draining. Disposal hides descendant CanvasLayers generically, without requiring cyber-specific HUD property names.

## Genuine progress and cancellation

Resource loading uses `ResourceLoader.load_threaded_request()` and polls status/progress each frame. `load_threaded_get()` is called only after LOADED. Scene-tree/rendering/collision attachment stays on the supported main-thread path.

Progress is engine-reported resource-stage progress or actual processed section/mesh counts. Unknown work is indeterminate with its descriptive stage. There is no fabricated overall percentage or fixed loading delay. Long stages show Still preparing with actual elapsed time.

Godot 4.3 has no general threaded-load cancellation API. Cancel invalidates ownership immediately, returns to the menu, drains the in-flight request and stops further construction at safe boundaries. A stale result never enters gameplay. Retry creates a new request.

An adapter may opt into cooperative construction cancellation with `supports_cooperative_cancellation() -> bool`. It must only return true if its initialization completion flag means all construction coroutines have unwound. The incident adapter satisfies that contract. Other modes default to finishing/draining their active construction before disposal, without calling a cancellation method that could report completion prematurely. This keeps Cancel responsive without freeing nodes still used by an awaiting builder.

Time-budgeted loops reduce blocking, but some driver/resource operations are atomic. A loading animation cannot make those calls asynchronous. Record remaining native frame gaps honestly; headless results are not GPU performance guarantees.

## Derived runtime assets

The original campus GLB is unchanged. Offline tools derive:

- `assets/runtime_campus/`: 94 small native scene sections, about 42 MB total, with source names/transforms, all 5,965 mesh nodes and precomputed split exact triangle shapes. Runtime canonical keys restore shared meshes/materials, retaining 28 MultiMesh batches and 92 static batches. Triangle pieces preserve the same surfaces while bounding attachment work.
- `assets/runtime_surfaces/`: deterministic PNGs from the existing campus surface generator. Normal loading avoids CPU pixel-generation loops; the procedural path remains a recovery fallback.

Regenerate when the source model or surface generator changes:

```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/launcher/bake_campus_chunks.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/launcher/bake_surfaces.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --editor --path . --import
```

The section manifest records the source SHA256. Keeping original and derived assets uses extra disk space while preserving source/editing and direct-scene recovery paths.

## Preferences and saves

Data stays under the application's `user://ensagames/` directory. `OS.get_user_data_dir()` reports the actual Windows location.

- `preferences.cfg`, schema 1: display, graphics, FPS cap, V-Sync, separate Master/Music/SFX, sensitivity, bindings, English locale and accessibility preferences.
- `saves/incident_response/checkpoint.json`, version 1: mode/mission, position/yaw/pitch, authored flags/points, journal/history and report state.
- `last-session.cfg`: latest available mode/mission identity for its save service.

Each mode's cached adapter and game share one save service. Continue reads the recorded mode's service, validates its mode/mission headers and renders either a String summary or a normalized Dictionary label. The cybersecurity case panel always reads the cybersecurity checkpoint, even when Continue points to survival. Test sessions derive separate per-mode checkpoint and recent-mode paths from `test_save_path`.

Settings separate saved/draft/live state. Audio is previewed and Cancel restores it. Defaults populate the draft until Apply. Invalid values, unsupported locales and conflicting bindings are rejected; Escape remains reserved. Risky display changes need Keep within 15 seconds or Revert/timeout restores the previous mode/size/position. Only confirmed preferences persist.

Graphics changes actual Compatibility MSAA and shadow behavior. Audio buses are independent; a quiet original launcher tone supplies SFX feedback. No music or spoken dialogue is shipped; the UI must describe this accurately.

Continue requires a validated compatible checkpoint and matching prerequisite flags/points. Missing/corrupt saves leave New Mission available. Writes use temporary files/rename; failures show feedback. Pose restoration checks ground/capsule clearance, otherwise using a safe spawn. Commands remain virtual and never execute on Windows or the network.

## Registering a future independent mode

Zombie RPG remains coming_soon. `design/future_zombie_assets.json` inventories the user's original files, hashes, animations and embedded provenance without importing them into startup or changing their source folder. The active implementation assignment is [ANTIGRAVITY-BIG-TASK-ZOMBIE-RPG.md](ANTIGRAVITY-BIG-TASK-ZOMBIE-RPG.md): an independent playable After Hours episode. Antigravity owns its new zombie folders; Codex owns shared registration and integration after delivery.

A future mode supplies an independent scene, lightweight RefCounted adapter, save service/schema and mode settings. Register its metadata in `design/extra_modes.json`; a descriptor may replace its coming-soon placeholder, but cannot silently replace an already available mode. Keep it coming_soon until its real implementation/tests are ready.

Example **future descriptor**, not an existing scene to enable now:

```json
[
  {
    "id":"zombie_rpg",
    "title":"Zombie RPG Survival",
    "subtitle":"Survival · Exploration · RPG",
    "availability":"available",
    "adapter_version":1,
    "adapter_path":"res://scripts/antigravity/zombie/zombie_mode_adapter.gd",
    "scene_path":"res://scenes/antigravity/zombie/zombie_game.tscn",
    "save_namespace":"zombie_rpg",
    "settings_namespace":"zombie_rpg",
    "mission_ids":["ZB-2026-001"],
    "missions":[{"id":"ZB-2026-001","title":"After Hours","objective":"Restore power and reach extraction","briefing":"Mode-owned briefing."}]
  }
]
```

Adapter version 1 follows the working incident_mode_adapter.gd:

```text
required_resources() -> Array[String]
entry_scene() -> String
create_session(resources, preferences) -> Node3D
initialization_finished(game) -> bool
validate_ready(game) -> bool
error_detail(game) -> String
cancel(game), freeze(game), start(game)
set_input(game, enabled)
connect_events(game, on_return, on_settings, on_progress)
apply_preferences(game, preferences)
capture(game) -> Dictionary
restore(game, checkpoint) -> bool
is_ready(game) -> bool
save_service() -> RefCounted
```

Sessions expose `initialization_progress(label, stage, completed, total)`. The adapter translates its own internals into readiness/lifecycle methods. Its save service offers read_save(), write_save(payload), summary(payload), last_error and its own namespace/schema; checkpoint headers identify mode_id/mission_id. Constructors must not eagerly load 3D environments. Extra mode-specific settings can remain inside that mode while the launcher shares global display/audio/accessibility settings.

Save services expose an overridable `path` used by both adapter and session. Return the same service from `save_service()` and inject it before the session enters the tree. Scene initialization/Ready cannot write a persistent checkpoint; intentional entry and actual progress may write. `summary` may return a String or a Dictionary containing `label`/`checkpoint_name`. Mission controls are an Array of `{action,binding}` dictionaries; legacy prose is kept as `controls_text`, never passed to the native grid as characters. Mode cards resolve the registered default mission and do not assume IR-2026-001.

Optional `validate_spawn(game) -> bool` checks ground and capsule clearance after physics initialization. Cancellation must eventually finish initialization with a cancelled/error state so the loader can drain ownership safely. `freeze` and `cancel` must hide mode-owned UI and suspend gameplay; no damage or input may run behind Ready/settings/menu pages.

## Verification and rollback

- `tools/launcher/integration_test.gd`: real navigation/services, missing-resource recovery, stale IDs, cancellation, world readiness, source/batch preservation, 28 landing probes, case progress, Continue restoration and corrupt-save recovery. `-- --stress` runs five total mode cycles.
- `settings_test.gd`: real graphics/audio/input and native display Keep/Revert/timeout. `-- --read-persistence` verifies a saved value in a different process.
- `profile_load.gd`: native timing without screenshot readbacks/PNG writes contaminating measurements.
- `home_visual_test.gd`: real integrated home navigation and layout at 960×540, 1280×720, 1920×1080, 1280×1024 and 1920×720, including a validated Continue checkpoint. Confirms the white vector emblem, no AVAILABLE badge, in-bounds content and real Play/Settings navigation.
- `multi_mode_test.gd`: isolated real fixture scenes exercise independent adapters/services, mode-card routing, frozen Ready, paused settings, dictionary summaries, separate checkpoints and a fresh-launcher recent-mode restore. It never imports zombie models or writes production saves.
- `zombie_launcher_test.gd`: loads Antigravity's actual mode through the shared launcher with isolated metadata/save paths. Exercises native input, settings, inventory Continue and cancellation during active construction. Current remaining mode-owned issues are recorded in ANTIGRAVITY-ZOMBIE-PLAYABILITY-AND-VISUAL-FINISH.md; production remains coming soon until resolved.
- Existing entrance, PC/hover, desktop, shell and smoke tests remain available. Explicit `-- --smoke-test` and `-- --preview` developer paths are preserved through boot. Known headless dummy-renderer warnings are distinguished from script failures/native results.

Set project.godot run/main_scene back to `res://main.tscn` to roll back the launcher entry. Pre-launcher core copies are under editor-ignored `tools/launcher/original/`; the project configuration is `project.godot.before`. Environment polish has its separate `-- --no-polish` rollback.

PLAY.cmd now opens the lightweight launcher immediately instead of blocking on a whole-project editor import. Prepared distributions/exports include imported resources. For a completely fresh source copy without import data, prepare it once with EDIT.cmd; that editor import is separate from normal game loading and cannot be animated by a process that has not started yet.
