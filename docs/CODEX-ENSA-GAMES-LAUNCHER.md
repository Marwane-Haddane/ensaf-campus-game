# Codex task — ENSA Games launcher, loading and integration

Give this entire file to Codex. Its companion task is `docs/ANTIGRAVITY-ENSA-GAMES-LAUNCHER.md`. These files define the next implementation task; they do not claim that the launcher is already implemented.

## Objective

Implement a polished, modular **ENSA Games** launcher for the existing Windows PC game. Keep **ENSA Incident Response** as the available cybersecurity mode. Add a **Zombie RPG — COMING SOON** preview without creating or entering an unfinished RPG scene. Preserve the campus, existing first-person gameplay, doors, missions, workstation desktop and simulated command system.

Fix the underlying initialization delays that currently leave the screen saying “Preparing campus...” with disabled navigation. A visual loading animation alone is not a fix. The main menu must become usable without loading the campus.

## Verified project context

- Working directory: `C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game`.
- Engine: **Godot 4.3, GDScript, GL Compatibility**. Keep this engine and renderer. Do not introduce Unity, Unreal, a web wrapper or a replacement game.
- Console engine: `C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe`.
- Existing startup: `project.godot` points to `res://main.tscn`, whose controller is `scripts/main.gd`.
- `main.gd::_ready()` awaits `CampusRuntime.build()` before enabling the current start menu.
- `campus_runtime.gd::build()` uses synchronous `load(CAMPUS_PATH)` and `packed.instantiate()`. It yields every 100 processed meshes, but materials, scene instantiation, shape creation, batch construction and merged surfaces can still block individual frames.
- Recent scene statistics: about 5,965 source mesh nodes, 28 MultiMesh batches and 92 merged static batches. Treat these as context, not a startup-time guarantee.
- `PLAY.cmd` can run a blocking first-import preparation before the game process starts. A launcher inside the game cannot animate before that separate import process finishes. Distinguish development import from normal distributed-game startup; ship pre-imported/exported resources, or provide honest separate preparation feedback. Do not hide this boundary.
- `main.gd` currently hardcodes mouse sensitivity and adds default key bindings at runtime. Preferences must replace those defaults rather than being overwritten on world launch.
- Existing mission progress appears memory-local; do not assume a valid disk save already exists or show a misleading Continue button.
- Antigravity's environment module is `scripts/antigravity/environment_polish.gd`. Codex is completing its production integration separately. Inspect the latest files and `docs/CODEX-STATUS.md` before starting; do not revert the integration or the material/shadow fixes.

## Collaboration and file ownership

Codex owns:

- `project.godot`, `main.tscn`, `scripts/main.gd`, `scripts/campus_runtime.gd` and necessary core adapters.
- `scenes/launcher/boot.tscn`, the launcher root and loader/service scripts.
- `scripts/launcher/launcher_controller.gd`, `boot_state.gd`, `mode_registry.gd`, `mission_loader.gd`, `settings_store.gd`, `save_store.gd`, and game-session integration.
- Production wiring, InputMap, audio-bus setup, settings persistence, save validation, loading/cancellation, error recovery and final combined QA.
- Core tests under `tools/launcher/`, plus regression tests where necessary.

Antigravity owns **presentation only** in:

- `scenes/antigravity/launcher/`
- `scripts/antigravity/launcher/`
- `assets/antigravity/launcher/`
- `shaders/antigravity/launcher/`
- `tools/antigravity/launcher/`
- `antigravity/launcher/`

Do not edit Antigravity's launcher files concurrently. Build a minimal functional fallback view in `scenes/launcher/` / `scripts/launcher/` so core development can proceed independently. Connect Antigravity's final view through the versioned contract below. Proposed contract changes go in `docs/LAUNCHER-STATUS.md` and `antigravity/launcher/INTEGRATION.md` before either side depends on them.

The user relays handoffs through these files. Do not assume a direct live connection between assistants. Do not stop the user's game or Antigravity's processes. Never run two GPU benchmarks simultaneously. New external 3D models still require explicit user approval before downloading/importing; no new models are needed for this launcher.

## Shared presentation contract — version 1

Antigravity supplies `res://scenes/antigravity/launcher/launcher_view.tscn`, with a full-screen `Control` root and this public API:

```gdscript
signal intent_requested(action: StringName, payload: Dictionary)

func get_contract_version() -> int: # returns 1
func present(model: Dictionary) -> void:
func set_preferences_preview(preferences: Dictionary) -> void:
func focus_primary() -> void:
```

These are signatures to implement, not placeholder function bodies. Codex owns the controller and all authoritative state. The view never loads a game world, writes preferences/saves, changes display settings, quits the application, changes InputMap or invokes mission commands. `present()` must be idempotent and may be called many times during loading without rebuilding the entire UI or losing field focus.

Model fields:

```text
contract_version: 1
state: STARTUP | INITIALIZING | MAIN_MENU | SELECT_MODE | LOADING_GAME | READY | PLAYING | ERROR | CANCELLED
page: boot | home | modes | briefing | settings | how_to_play | credits | loading | ready | error
brand: "ENSA Games"
modes: [{id, title, subtitle, availability, artwork_path, description}]
selected_mode_id: "incident_response" or "zombie_rpg"
mission: {id, title, objective, briefing, controls}
continue: {available, mode_id, mission_id, summary}
loading: {request_id, stage_id, stage_label, completed_units, total_units,
          resource_progress, can_cancel, still_preparing, elapsed_seconds}
error: {code, message, diagnostic, retry_allowed, return_allowed}
settings: {saved, draft, capabilities, dirty, validation_errors,
           display_confirmation_required, display_confirmation_seconds_remaining}
preferences: {reduced_motion, language, subtitles, ui_scale}
control_hints: [{action, binding, label}]
development_build: bool
```

`resource_progress` is null when unavailable, otherwise 0–1 for the current resource-loading stage only. `completed_units` and `total_units` are actual completed work units or null. They are never an invented overall percentage. `artwork_path` references approved lightweight UI images, never a live 3D scene. Capabilities explain unsupported settings and list actual available languages/presets/display choices.

Allowed intents:

```text
play, show_modes, select_mode {mode_id}, show_briefing {mode_id, mission_id},
start_mission {mode_id, mission_id, skip_briefing}, continue_game,
show_settings, edit_setting {key, value}, apply_settings, cancel_settings,
restore_defaults, capture_binding {action}, confirm_display, revert_display,
show_how_to_play, show_credits, back, skip_branding,
cancel_loading {request_id}, retry_loading {request_id}, return_to_menu,
enter_game {request_id}, quit
```

Codex must validate every payload and transition. Disabled Zombie RPG clicks cannot bypass the mode registry. The view may manage purely visual subpanels, focus and a local draft to emit, but cannot invent successful gameplay or loading state.

## Implementation order

### 1. Record a baseline and isolate the boot path

1. Read current source, handoff/status and tests before editing. Record startup timing by real stages: process start, first rendered boot frame, menu interactive, mission request, resource retrieval, world construction, player readiness and first playable frame.
2. Set `project.godot` to a lightweight `scenes/launcher/boot.tscn`. Preserve `res://main.tscn` as the cybersecurity scene for existing tests and adapters.
3. Boot must have no eager `preload()` or scene dependency chain referencing campus GLB, approved prop GLBs, gameplay `main.gd`, or full game UI. Use string scene/resource paths in the mode registry until launch.
4. Render the boot identity/indicator at the first available frame. Load only preferences, registry metadata, save headers and small shared UI resources during INITIALIZING. No fixed-duration logo gate; branding is optional/skippable.
5. Reach MAIN_MENU independently of any 3D world. Settings, How to Play, Credits, mode cards, Back and Quit must work immediately. Cosmetic resources can arrive later with a safe fallback.

### 2. Implement the boot state machine and request ownership

Normal flow: `STARTUP -> INITIALIZING -> MAIN_MENU -> SELECT_MODE -> LOADING_GAME -> READY -> PLAYING`.

- Main-menu Play may advance through SELECT_MODE directly into the available mission briefing. Game Modes opens the mode chooser. Settings/help/credits are pages under the appropriate menu state.
- READY means world geometry, collision, player, input, UI, station targets, doors, lighting and required mission data are initialized. Resource bytes loaded is not READY.
- Only one active transition request. Use monotonically increasing request IDs/generation tokens. Double clicks, late callbacks and stale cancelled loads cannot instantiate another world or capture the mouse.
- ERROR and CANCELLED recover to an interactive menu. Retry creates a fresh request. Never trap the user on disabled controls.
- While PLAYING, game pause is distinct from launcher startup. Returning to launcher releases mouse capture, stops gameplay input, frees/disconnects session objects safely and retains only deliberately cached resources.
- Preserve existing `_smoke_test`, direct `main.tscn` tests and developer paths, or migrate them deliberately with documented replacements. Do not silently invalidate their coverage by changing the project entry scene.

### 3. Genuine staged asynchronous mission loading

1. Queue large resources with `ResourceLoader.load_threaded_request()` and poll status/progress each frame. Call `load_threaded_get()` only after `THREAD_LOAD_LOADED`; an early call can block.
2. Refactor `CampusRuntime.build()` to accept already loaded resources or a loader-owned provider instead of synchronously reloading the GLB. Request approved props on demand in the same pipeline.
3. Keep scene-tree changes, rendering resources, collision attachment and GPU-facing work on the supported main-thread path. Do not put active scene-tree edits in a worker or enable an experimental rendering thread mode to mask stalls.
4. Profile synchronous `PackedScene.instantiate()`, mesh collection, texture generation, collision cooking, entrance repair, batching/merging, occluders, props and polish installation separately.
5. Process eligible loops by an elapsed-time budget (start around 3–5 ms per frame, tune from measurement), rather than only “every 100 nodes”. Yield between jobs; cache/share shapes and materials safely. A single expensive atomic job can exceed the budget: measure and report it.
6. If whole-campus instantiation or a large mesh merge is itself a material freeze, split derived runtime scenes/merge jobs into measured chunks, generated by an offline tool if needed. Preserve original source assets, names, transforms, metadata and collision alignment. Do not claim a single `await process_frame` before a blocking operation makes it incremental.
7. Prebake/cache procedural texture data where profiling justifies it. Keep runtime/derived assets small and traceable. Do not redesign architecture or discard geometry to claim faster loading.
8. Emit actual stages, for example: Loading campus resource; Creating campus sections; Preparing surfaces; Building collision 730/2,200; Repairing entrances; Preparing render batches; Placing response stations; Applying visual finishes; Checking player readiness.
9. Show stage-local percentages only where the engine reports progress; show counters for measurable work and an indeterminate ring otherwise. No fabricated weighted total or “estimated 5–10 seconds”.
10. On a genuinely long stage, show “Still preparing...” with the actual stage and elapsed time. Thresholds are diagnostic triggers, never artificial delays. Controls and animation must remain responsive where engine operations permit.

Godot 4.3 references: [background loading](https://docs.godotengine.org/en/4.3/tutorials/io/background_loading.html), [ResourceLoader](https://docs.godotengine.org/en/4.3/classes/class_resourceloader.html), [thread-safe API limits](https://docs.godotengine.org/en/4.3/tutorials/performance/thread_safe_apis.html).

### 4. Cancellation and errors

- Godot 4.3 ResourceLoader has no general cancel-threaded-request API. Implement logical cancellation: invalidate the request, stop scheduling world construction, return to menu, ignore/drain the outstanding result safely. Avoid requesting the same path again until its prior request is handled.
- Partial worlds remain inactive and never become playable. Clean up nodes/signals/collisions safely at a frame boundary. Keep loader ownership alive long enough to handle background completion; no access to freed UI/session nodes.
- For atomic non-cancellable work, state the current stage honestly, queue cancellation until a safe boundary and keep its button semantics accurate.
- Handle missing scene, missing asset, invalid registry, bad mission JSON, load failure and readiness failure. ERROR offers Retry where possible, Return to Menu and Quit.
- Log request ID, stage, resource path and underlying error. Development diagnostics may be expandable; release-facing copy remains readable. Do not convert a slow successful load into an unrecoverable error solely because a timer expires.

### 5. Modes, briefing and future RPG integration

- Registry entries are data with stable IDs, availability, entry-scene path, mission provider, artwork, save namespace, settings namespace and adapter/lifecycle version. Do not scatter `if zombie` branches through the launcher.
- `incident_response`: AVAILABLE, scene `res://main.tscn` or its documented adapter; separate saves/settings namespace.
- `zombie_rpg`: COMING_SOON, no executable entry scene. Preview only. Do not create zombies, combat or RPG mechanics in this task.
- Briefing: `IR-2026-001`, **The borrowed session**, objective **Find the marked workstation**. Explain investigation, preservation, containment, recovery and report; show actual configured controls. Skip briefing skips copy, never readiness checks/loading.
- READY presents Enter Mission clearly; enter only on the current ready request. Transition to first-person input/mouse capture intentionally.
- Document a mode adapter lifecycle for initialize, readiness, start, pause, resume, save and unload. Future RPG owns its own scene tree, save payload and mode settings, while the shared launcher remains unchanged.

### 6. Functional preferences

Use a versioned `ConfigFile` or similarly validated store under `user://ensagames/`. Load safe defaults on missing/corrupt values; clamp values and handle write failures. Keep saved, draft and live-preview state separate.

- Display: resolution, windowed/fullscreen, actual supported choices, UI scale if offered. Apply risky display changes with a visible confirmation countdown; Keep saves them, timeout/Revert restores prior mode, position and size. This countdown protects display recovery and is not a loading delay.
- Graphics: Low/Medium/High only if each maps to real supported settings such as MSAA and shadow resolution/distance. Preserve GL Compatibility; no pretend ray tracing or renderer switch. Provide a custom state if individual values differ.
- Frame cap and V-Sync: actually call the appropriate engine settings. Explain effective caps briefly if needed.
- Audio: Master, Music and SFX buses, independently adjustable, with persisted volumes. Do not play music if no licensed track is available. An audio control must not pretend content exists; declare unavailable content accurately.
- Mouse: persisted sensitivity must replace the current hardcoded `0.0024` multiplier. Show an understandable range and default.
- Bindings: movement, run, jump, interact, guide, response plan and pause as supported. Capture one input without also activating the focused button; support cancel, detect conflicts, preserve a reachable menu/back action. Apply InputMap without re-adding defaults on every scene start. Update all relevant prompts and How to Play text.
- Language: expose only translations actually supplied. Persist selection and fall back safely; do not claim full French/Arabic support by changing one heading. Keep the structure ready for additional locales.
- Subtitles: apply to any supplied dialogue/captions; if there is no spoken content, explain this without pretending subtitles change the terminal text.
- Reduced motion: persist and apply to both the launcher and compatible game transitions; eliminate decorative scanning/parallax, suppress motion-dependent effects, preserve readable status.
- Apply validates, changes supported live settings and saves only on success. Cancel restores the last applied state including any live previews. Restore Defaults populates the draft without silently discarding the saved configuration. Closing a dirty panel offers clear Apply/Discard/Stay semantics.

### 7. Continue/save correctness

- Continue appears/enables only after validating a compatible saved mode/mission, schema version and payload. Do not treat the preferences file as a game save.
- Implement a minimal real incident-mode checkpoint if needed: mission state, evidence journal, points, report state and safe player spawn/pose. Reuse the mission model; do not restore points without its prerequisites.
- Use per-mode saves under `user://ensagames/saves/<mode_id>/`, with versioning, validation and recoverable/atomic writes. Do not overwrite a good save with an incomplete load.
- A corrupt/missing/incompatible save leaves New Mission available with an honest explanation. Save failures are visible and logged.
- Validate saved positions against loaded geometry; fall back to a safe destination if invalid. Never spawn through closed doors or under the floor.

### 8. Presentation integration and preservation

- Wire the Antigravity view only when its contract version and scene are valid. Keep a functional fallback menu if absent.
- Use “ENSA Games” for the launcher, “ENSA Incident Response” inside cybersecurity. The reference Unity splash is inspiration only. Use appropriate Godot identification/credits without implying Godot requires a startup logo or adding an unnecessary forced splash.
- Preserve the professional in-game HUD, Linux-style interactive desktop, hover-only E prompts, existing pause design, three PCs/two server racks, four interactive entrances and source campus layout.
- The environment polish runs once after world construction/batching and prop installation. Uninstall or free it safely on unload. Keep `--no-polish` working for comparison. Guard against duplicate installs on repeated mission launches.
- No live 3D campus, SubViewport world or full gameplay scene is allowed behind the main menu just for cinematic imagery. Use lightweight stills and restrained 2D effects from Antigravity.

## QA and acceptance

Create tests that target behavior rather than mirroring code. Record actual measurements on this machine; do not promise a hardware-independent startup time or 30 FPS. Test the slow path through injectable loader scheduling/resource providers or a documented throttling option, without shipping artificial delays in normal play.

Required checks:

1. First boot UI renders; main menu is interactive before any campus/prop GLB request or world instantiation. Verify using loader logs/metrics and tree/resource inspection, not appearance alone.
2. Cold/warm startup timings and maximum UI frame gaps by stage; repeat after restart and capture evidence. Record any remaining atomic stalls honestly.
3. Every navigation button, Back/Esc, keyboard focus, mouse focus, Enter/Space selection and screen-size layout. No cursor capture in menus.
4. Zombie RPG cannot start through click, keyboard or forged intent. Invalid mode/mission IDs are rejected.
5. Double Start, rapid Back/Start, Cancel at each feasible stage, late completion, Retry, failed load, corrupt registry and return to menu. Exactly one active world/request.
6. At least five load/play/pause/return cycles; no growing duplicate nodes, signals, lights, audio or collision bodies. Check memory trends after warm-up without demanding that all cached resources disappear.
7. Display Apply/Keep/Revert/timeout; all preferences Apply/Cancel/Defaults, valid persistence across process restart, corrupt file fallback and unsupported capabilities.
8. Rebinding updates actual gameplay and prompts; typing in the PC desktop still cannot move the player. Sensitivity, frame cap, V-Sync and independent audio buses work.
9. Continue: no save, valid save, corrupt/incompatible save, restored mission and safe position. New Mission does not silently erase a valid checkpoint.
10. Real physics readiness: grounded player, walkable landing/stairs, closed/open door collisions, slider/hinge movement, station targeting, mission completion and report. Run appropriate existing regressions.
11. Reduced motion, available language choices, meaningful accessible labels, contrast and 1280×720 plus 1920×1080 layouts. Verify native rendered screenshots; engine check-only/headless tests do not validate visual quality or GPU performance.
12. Quit and restart from menus, loading, error and gameplay. Do not terminate unrelated processes.

Useful existing tests, run with the engine above and the project as working directory:

```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/entrance_bugfix_test.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/computer_integration_test.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/hover_target_test.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/workstation_shell_test.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/workstation_desktop_test.gd
```

Use native rendering selectively for captures and interaction/GPU QA. Existing Godot 4.3 dummy-renderer shutdown warnings must be distinguished from new script/logic failures.

## Handoff milestones and deliverables

1. **Contract and boot:** publish the version-1 model/intents, working lightweight fallback menu and measured startup trace. Antigravity can develop immediately against the contract without waiting for world changes.
2. **Real loader:** measurable stages, request ownership, incremental construction, cancellation/error recovery and gameplay readiness.
3. **Persistent services:** functional preferences, mode registry, briefing and real validated Continue behavior.
4. **Visual integration:** connect Antigravity's delivered scene, then perform joint screenshot/input/loading QA. Fix functional regressions in Codex-owned files; send presentation issues back through its handoff.
5. **Final delivery:** document `docs/ENSA-GAMES-ARCHITECTURE.md`, the new scene tree, state transitions, future-mode registration example, preferences/save schema, test commands, measured startup/frame gaps, remaining limitations and rollback. Update README and `docs/LAUNCHER-STATUS.md`.

Do the authorized work to completion once implementation begins. Do not wait for cosmetic assets to finish the underlying loader, and do not label a frozen-looking loading screen fixed until the blocking path has been measured and addressed.
