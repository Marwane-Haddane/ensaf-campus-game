# Antigravity task — ENSA Games launcher presentation

Give this entire file to Antigravity. Codex's companion task is `docs/CODEX-ENSA-GAMES-LAUNCHER.md`. Implement the presentation module described here, not a replacement engine or a separate unrelated game. These files define upcoming work; the launcher is not already complete.

## Your objective

Create a polished, lightweight **ENSA Games** launcher presentation for the existing Windows PC game. Keep **ENSA Incident Response** as the cybersecurity mode branding. Deliver a native Godot UI that feels like a coherent PC game launcher: precise typography, cinematic campus still imagery, deep navy/graphite, restrained cyan/teal, strong hierarchy and calm animation.

Codex is responsible for fixing the actual blocking startup path, loading state machine, settings behavior, saves and gameplay integration. Your UI must make those real states clear and must never conceal a blocking load behind fake progress. Work in parallel through the shared interface below.

## Existing project and references

- Project directory: `C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game`.
- Engine: **Godot 4.3 / GDScript / GL Compatibility**. Use native `Control` scenes, Containers, Theme resources, SVG/texture UI assets and compatible CanvasItem shaders if needed. No HTML/browser UI or engine switch.
- Engine executable: `C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe`.
- Current world: `res://main.tscn`; existing controllers in `scripts/main.gd`, `campus_runtime.gd`, `pause_menu.gd`, `training_ui.gd` and workstation scripts are Codex-owned.
- Read `docs/COLLABORATION.md`, `docs/CODEX-STATUS.md`, your environment-polish handoff and Codex's launcher brief before work. Do not undo the completed environment module or its integration corrections.
- User reference boards are retained at `docs/references/launcher-storyboard.png` and `docs/references/launcher-flow.png`. The first board includes a Unity logo only as a flow example; this project stays in Godot. Godot identification can be used appropriately in credits or an optional understated splash; never show “Made with Unity”.
- Other visual continuity references: `docs/references/environment-target.png`, campus photos in `docs/references/`, and the actual native captures in `tools/polish-integrated/` after Codex finishes verification. Do not present generated reference art as proof of implemented gameplay.
- Current issue: “Preparing campus...” with disabled Start Exploration and Campus Destinations can look frozen. Your launcher must be light enough to display before the world exists. Codex owns correcting the synchronous loading/instantiation underneath it.

## Strict ownership boundaries

You may create/edit:

```text
scenes/antigravity/launcher/
scripts/antigravity/launcher/
assets/antigravity/launcher/
shaders/antigravity/launcher/
tools/antigravity/launcher/
antigravity/launcher/
```

Required deliverable: `res://scenes/antigravity/launcher/launcher_view.tscn`.

Do not edit `project.godot`, `main.tscn`, `PLAY.cmd`, core gameplay/menu/UI/mission/door/collision scripts, Codex's `scripts/launcher/` services, or existing tests. Put proposed changes outside your namespace in `antigravity/launcher/INTEGRATION.md`, with exact paths and reasons, for Codex to integrate. Do not fork or overwrite the current environment-polish script for this launcher task.

No new external 3D models are needed. Existing policy requires user approval before downloading/importing any new 3D model. Use original/licensed lightweight UI art, approved assets and retained campus images; record font, icon, image and sound provenance. Never flatten the supplied storyboard into the menu background with its baked labels/buttons.

Do not close user/Codex processes. Coordinate native GPU tests through handoff/status files so benchmarks are not simultaneous. There is no assumed direct live assistant connection: the user and local handoff documents carry integration updates.

## Shared presentation contract — version 1

The full-screen `Control` root of `launcher_view.tscn` exposes:

```gdscript
signal intent_requested(action: StringName, payload: Dictionary)

func get_contract_version() -> int: # returns 1
func present(model: Dictionary) -> void:
func set_preferences_preview(preferences: Dictionary) -> void:
func focus_primary() -> void:
```

Implement these methods. `present()` renders authoritative data from Codex. It must be idempotent, preserve keyboard focus and unsent text/slider interaction, and avoid rebuilding the whole tree for every progress tick.

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

`resource_progress` is null when unmeasurable, otherwise a real 0–1 resource-stage value. Completed/total units are actual work counters or null. No simulated overall percentage. Mode artwork is a lightweight still image path, not a 3D scene.

Allowed view intents:

```text
play, show_modes, select_mode {mode_id}, show_briefing {mode_id, mission_id},
start_mission {mode_id, mission_id, skip_briefing}, continue_game,
show_settings, edit_setting {key, value}, apply_settings, cancel_settings,
restore_defaults, capture_binding {action}, confirm_display, revert_display,
show_how_to_play, show_credits, back, skip_branding,
cancel_loading {request_id}, retry_loading {request_id}, return_to_menu,
enter_game {request_id}, quit
```

Emit intents; do not call ResourceLoader for the campus, instantiate gameplay, write saves/preferences, change InputMap, set display modes, capture the mouse, quit the process or execute shell/mission commands. Those actions belong to Codex's controller. A slider may preview its local appearance and emit a draft edit; successful application must come from the controller's returned model.

If the contract needs a change, propose it in your integration handoff before depending on it. A standalone mock provider is allowed under your tools namespace for testing; label it clearly and never wire mocked readiness/progress into production.

## Art direction and layout

- Premium dark navy/graphite with cool off-white type, steel-gray secondary copy, one restrained mint/cyan-teal accent. Preserve the calm incident-response identity.
- Use a consistent font system with clear title, navigation, section and small metadata levels. Bundle licensed fonts if needed; supply licences. No tiny essential text.
- At 1280×720, allow approximately 48–64 px safe margins where the layout permits; scale gracefully to 1920×1080 and wider aspect ratios. Use anchors/Containers and real minimum sizes, not a single 1920-pixel coordinate layout.
- Full-bleed campus still imagery with controlled dark gradient and subtle atmosphere. The campus remains recognizable. Keep backgrounds legible beneath text and avoid loading a live campus scene to create the backdrop.
- Restrained panels and short rules; navigation should feel authored, not a generic dashboard full of oversized rounded cards. No neon code rain, skulls, glitch clutter, charts, fake online status or invented player accounts.
- Cybersecurity card uses cool incident-response imagery. Zombie RPG preview may use a warmer dusk mood and campus silhouettes, but must remain plainly **COMING SOON**, not imply playable content or show a fake Start action.
- Mouse hover, keyboard focus and selected state must be visibly different and consistent. Focus cannot rely only on color. Disabled items need readable explanations.

## Screens and required behavior

### A. Boot / startup identity

- Lightweight ENSA Games shield/identity, optional understated Godot credit, status label and responsive indicator from the first available rendered frame.
- Subtle shield line/pulse or network-style motion, with no seizure-prone flashing. Branding can be skipped immediately by the appropriate intent; do not impose a fixed 1–4 second gate.
- STARTUP/INITIALIZING display the actual short status from the model. Never preload all your imagery, audio or large fonts synchronously before drawing this screen.
- In reduced motion, keep identity and readable status without scan-lines, parallax or continuous decorative movement. Any indeterminate activity indicator must have a calm accessible alternative.

### B. Main hub

Required navigation: **Play**, **Game Modes**, **Continue** only when `continue.available` is true, **Settings**, **How to Play**, **Credits**, **Quit**.

- Lead with ENSA Games identity, available cybersecurity experience and a clear primary Play action.
- Include two prominent mode cards: **Cybersecurity / Incident Response — AVAILABLE** and **Zombie RPG — COMING SOON**.
- Do not show “Preparing campus...” as a blocking prerequisite on this page. Main navigation remains usable without a world instance.
- If Continue is absent, layout must remain balanced. Do not render a permanently disabled fake save slot. If a save summary is supplied, present only those real values.
- No invented profile, notification counts, online connection, achievement percentage or autosave guarantee.

### C. Mode selection

- Card-based mode chooser, persistent Back control and strong selected/available/coming-soon hierarchy.
- Selecting cybersecurity opens its briefing through an intent.
- Zombie RPG may reveal a compelling preview description, but never emits `start_mission` for the unavailable mode. Make the badge readable for both mouse and keyboard users.
- Source the list from `model.modes` so future entries can be added without rebuilding the launcher UI.

### D. Cybersecurity briefing

Exact initial data:

- Mode: **ENSA Incident Response**.
- Mission: **IR-2026-001**.
- Title: **The borrowed session**.
- Objective: **Find the marked workstation**.
- Explain the fictional training exercise: inspect the workstation, preserve evidence, contain the issue, restore safely and submit an incident report.
- Show actual configured controls supplied by the model; defaults include WASD/ZQSD/arrows, mouse look, E interact, Shift run, Space jump, Tab campus guide, J response plan, Esc pause.
- Provide **Start Mission**, Back and an optional Skip Briefing option. Skipping must still trigger the normal loader; never bypass readiness.

### E. Mission loading

- Keep the composition cinematic, readable and restrained. Show selected mode/mission, actual active stage, a responsive ring and actual progress/counters when supplied.
- If `resource_progress` is measurable, label it as resource-stage progress. If it is null, show an indeterminate state and descriptive stage instead of “72%”.
- A real counter such as “Building collision — 730 / 2,200” is acceptable only when those values come from the controller.
- Crossfade status changes without delaying them or holding a fake completion animation. No fabricated time estimate or fixed-duration loading sequence.
- When `still_preparing` is true, show **Still preparing...** with the current stage and elapsed time. Do not imply a crash or successful completion.
- Show Cancel only when allowed; when cancellation is pending, reflect the controller's real state. A progress update must never erase keyboard focus from Cancel.
- READY presents **Enter Mission** and the current mission/controls clearly. Emit `enter_game` with the active request ID. Do not capture the cursor yourself.

### F. Settings presentation

Build tabs/sections for Graphics & Display, Audio, Controls, and Gameplay & Accessibility. Every offered option must have a real controller capability, be editable through intents and visibly reflect Apply/Cancel state.

- Display: resolution and windowed/fullscreen; optional UI scale if supported. Include the controller-driven Keep/Revert confirmation overlay and real remaining countdown after risky display changes.
- Graphics preset, frame cap and V-Sync. Do not offer unsupported features or unimplemented “Ultra/ray tracing”.
- Independent Master/Music/SFX sliders with actual values, clear mute state and keyboard adjustment. No loud autoplay.
- Mouse sensitivity and a readable key-binding list/capture state; allow cancelling capture and show conflicts from validation results. Binding labels elsewhere must update from model data.
- Language: show only `capabilities`-supported translations; no fake localization choices. Use strings/resources ready for translation, sensible wrapping and a layout that can accommodate longer labels.
- Subtitles where content exists, with an honest note if this version has no spoken content. Reduced motion must have a real preview in your module.
- **Apply**, **Cancel**, **Restore Defaults**. Defaults populate the draft; do not visually claim they were saved. Show unsaved changes and validation errors. Leaving dirty settings supports a clear Apply/Discard/Stay interaction through the controller.
- Capability-disabled controls must explain why instead of silently accepting values with no effect.

### G. How to Play / Credits

- How to Play is short, well spaced and keyboard-scrollable. Explain exploration, crosshair targeting, E at a nearby PC/door, Linux-style simulated desktop commands and the response workflow. Use configured key labels and preserve the safe local training framing.
- Credits include the actual engine, supplied asset/licence attributions and contributors already documented. Do not invent names, sponsors or permissions. Keep details readable without placing implementation jargon in the main flow.

### H. Error and cancelled recovery

- ERROR includes a human-readable message and **Retry**, **Return to Menu**, **Quit**, respecting which actions the controller allows.
- Only development builds show the expandable diagnostic supplied in the model. Never fabricate an error code or replace underlying diagnostics with a success animation.
- CANCELLED returns to a usable menu and preserves useful mode/briefing selection. Do not leave a full-screen input-blocking overlay after dismissal.
- Back/Esc semantics must be predictable, including leaving settings, returning from preview and cancellation prompts. Preserve focus when returning to the previous page.

## Animation, sound and resource constraints

- Panel fades/slides and focus transitions should generally take **200–400 ms**, be interruptible, and not stack indefinitely when navigation is rapid. Reduced motion uses immediate or gentle non-spatial transitions.
- Decorative background movement must not interfere with text, loading counters or responsiveness. Use a small number of lightweight effects; avoid many full-screen transparent layers and expensive blur passes.
- Do not use GPU-heavy live SubViewport backgrounds or load the 3D campus to capture an image at launcher runtime.
- Cache Theme/style/icon/font resources once. Avoid per-frame allocation or recreating Controls/materials on every model update. Stop hidden-page animations and sound loops.
- Subtle UI sounds/music are optional only with licensed/original assets. Route proposed sounds to **SFX** and music to **Music** under **Master**, with independent preferences from Codex. Avoid creating separate parallel bus layouts or changing production audio config yourself.
- If you supply no music, do not claim that a Music slider is audibly tested. Document supported content and availability honestly.
- Keep logos and icons crisp. Use local assets with a graceful fallback for missing cinematic artwork. Make assets available without internet access.

## Your standalone preview and QA

Create a lightweight standalone harness under `tools/antigravity/launcher/` that loads only your view and fixture dictionaries. It must work before Codex finishes the real loader and must not instantiate `main.tscn`.

Example command after you create the harness:

```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --script res://tools/antigravity/launcher/preview_launcher.gd
```

The filename above is your deliverable to create, not an existing test to assume is present.

Cover:

1. Boot, main hub, modes, cybersecurity briefing, settings, loading with measured and indeterminate progress, still-preparing, ready, error and cancelled fixtures.
2. Continue absent and valid-save summary present. Disabled Zombie mode never emits a launch intent.
3. Keyboard-only traversal, obvious focus, Enter/Space activation, Esc/Back, mouse hover and click. Focus remains stable during frequent progress updates.
4. 1280×720 and 1920×1080 native captures; add a wider or smaller supported aspect ratio and longer translated sample strings. No cropped primary controls or unreadable details.
5. Apply/Cancel/Defaults intents, binding capture/cancel, validation error display, display Keep/Revert and dirty-setting confirmation. Mocking tests the presentation contract; Codex tests real system changes.
6. Reduced-motion fixtures at every animated page, supported language choices, contrast and legibility over both light and dark campus artwork.
7. Rapid navigation and repeated `present()` calls: no accumulated tweens, dangling signals, duplicate sounds or growing node counts.
8. Measure standalone first-frame/menu time, UI frame time, memory/resource cost and maximal texture size. Capture genuine native results; do not call them full-game performance measurements.

Do not declare “perfect”, “zero overhead”, “all tests passed” or “production ready” from mock screenshots alone. Distinguish visual review, fixture tests and Codex's real integrated gameplay tests.

## Deliverable and handoff

Deliver:

1. The native view scene, reusable page/components, theme and restrained transitions in your allowed folders.
2. Local artwork/icons/fonts/sound if used, with an asset/licence manifest and size budget.
3. A standalone preview harness, actual PNG captures and a concise test report in your tools namespace.
4. `antigravity/launcher/INTEGRATION.md`: contract version, exact scene path, methods/signals, required assets, preview command, minimum UI initialization, intent-to-screen mapping, default focus, performance data and fallback/rollback instructions.
5. `antigravity/launcher/STATUS.md`: completed screens, remaining work, actual tests, known limitations and any requested Codex changes. Never imply core loading is fixed by your module.

Work in milestones: theme/components and contract preview first; all real presentation states next; native visual/input QA and handoff last. Codex can wire the first usable version while you finish polish. Preserve ownership boundaries and keep the two briefs/contracts synchronized through the handoff before changing the interface.
