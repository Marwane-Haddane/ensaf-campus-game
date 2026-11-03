# ENSA Games — active task split and Antigravity integration pass

Date: 2026-11-02. Give this entire document to Antigravity now.

This replaces the assumption that the standalone preview is the final integrated launcher. Antigravity has delivered presentation version 1. Codex is actively implementing real loading, settings, saves and session transitions. Your next assignment is to harden presentation against those real services and verify the final integrated experience without overlapping Codex's edits.

## Shared objective and scope

Deliver a responsive, polished **ENSA Games** Windows launcher in the existing **Godot 4.3 / GDScript / GL Compatibility** project. The available mode remains **ENSA Incident Response**. **Zombie RPG stays COMING SOON**; the supplied zombie assets are future inventory, not a reason to implement combat or load that world at startup.

Working directory:

```text
C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game
```

Engine:

```text
C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe
```

Read these before editing:

- `docs/CODEX-ENSA-GAMES-LAUNCHER.md` — full functional requirements.
- `docs/ANTIGRAVITY-ENSA-GAMES-LAUNCHER.md` — presentation requirements.
- `antigravity/launcher/INTEGRATION.md` — your delivered version-1 API.
- `docs/LAUNCHER-STATUS.md` if present — active implementation state.
- `scripts/launcher/launcher_view_adapter.gd` **read-only** — current Codex compatibility adapter.

The user relays messages and handoff files. There is no assumed direct live assistant connection. Keep tasks independent, record changes clearly, and do not silently change the shared interface.

## Exact division of responsibility

| Work | Codex owns | Antigravity owns |
|---|---|---|
| Startup | Lightweight boot scene, project entry point, first-frame initialization and measurements | Boot presentation, typography and restrained animation |
| Menu | Navigation/state validation, request IDs, data model, unavailable-mode enforcement | Native home/modes/briefing/help/credits/loading/ready/error layouts |
| Loading | Threaded resource requests, incremental world construction, genuine counters, cancellation/draining, errors and retry | Render supplied progress/status accurately; keep Cancel readable and focusable |
| Settings | Saved/draft/live state, validation, display apply/revert, engine settings, audio buses, InputMap and disk persistence | Controls reflect the supplied draft; labels, focus, validation, dirty state and confirmation presentation |
| Saves | Validate/write/restore real per-mode checkpoint; determine Continue availability | Show Continue and its real summary only when the model allows it |
| Gameplay | Campus, physics, doors, PCs, desktop/terminal, mission/report, pause and session lifecycle | No gameplay edits; visual findings go into the handoff |
| Art/resources | Approve production wiring and resource budgets | Theme, existing licensed imagery, icons and lightweight optional audio in your namespace |
| QA | Real startup/load/interaction/settings/save/error regression; combined integration | Presentation fixtures, keyboard/mouse/resolution/reduced-motion QA and native screenshots |

Codex is already creating/editing:

```text
scenes/launcher/boot.tscn
scripts/launcher/boot_state.gd
scripts/launcher/mode_registry.gd
scripts/launcher/settings_store.gd
scripts/launcher/save_store.gd
scripts/launcher/mission_loader.gd
scripts/launcher/launcher_controller.gd
scripts/launcher/launcher_view_adapter.gd
scripts/launcher/fallback_view.gd
tools/launcher/
scripts/main.gd
scripts/campus_runtime.gd
scripts/training_ui.gd
scripts/pause_menu.gd
project.godot
PLAY.cmd
```

These are **read-only for Antigravity**. Some are still being created or validated; their presence is not proof of completion. Do not add a second controller, save store, threaded loader or InputMap layer.

Antigravity may edit only:

```text
scenes/antigravity/launcher/
scripts/antigravity/launcher/
assets/antigravity/launcher/
shaders/antigravity/launcher/
tools/antigravity/launcher/
antigravity/launcher/
```

Do not change the existing environment-polish module, campus GLBs, Blender files, supplied zombie models or core tests. Proposed outside changes belong in `antigravity/launcher/INTEGRATION.md` for Codex to apply. Preserve user files and do not terminate another person's game/test process.

## Public interface — keep version 1 compatible

Deliverable scene remains:

```text
res://scenes/antigravity/launcher/launcher_view.tscn
```

Keep these methods and signal unchanged:

```gdscript
signal intent_requested(action: StringName, payload: Dictionary)
func get_contract_version() -> int # 1
func present(model: Dictionary) -> void
func set_preferences_preview(preferences: Dictionary) -> void
func focus_primary() -> void
```

The complete model/intents remain those in the two original briefs and your INTEGRATION.md. In particular:

- `settings.saved` and `settings.draft` contain the actual preference values.
- `settings.dirty`, `settings.validation_errors`, `settings.capabilities` and display-confirmation fields are authoritative.
- `preferences` supplies effective presentation preferences; do not save them yourself.
- `control_hints` contains current action/binding/label dictionaries.
- `loading.request_id` is a **string**, echoed unchanged in Cancel/Retry/Enter intents.
- `loading.resource_progress` is null or a genuine resource-stage value 0–1. Completed/total units are actual work counters or null.
- Mode availability uses `available` / `coming_soon`, with stable IDs `incident_response` / `zombie_rpg`.
- `continue.available` comes from valid save data; never infer it from a fixture, file name or local UI state.

Codex may supply optional `capturing_action` and `settings.message` to describe binding capture and save/settings feedback. Absence must be harmless. Do not require more fields without proposing them first.

### Preserve current adapter compatibility during this pass

Codex's adapter currently subclasses your `launcher_view.gd`. Keep the following existing names/types and behavior available while integration is active:

- Root `_pages` dictionary and page IDs; `_current_page`; `_transition_to_page(target)`; `_display_confirm_overlay`.
- Settings widget references `_res_option`, `_fullscreen_check`, `_preset_option`, `_fps_option`, `_vsync_check`, `_master_slider`, `_master_val`, `_music_slider`, `_music_val`, `_sfx_slider`, `_sfx_val`, `_sens_slider`, `_sens_val`, `_lang_option`, `_subtitles_check`, `_reduced_motion_check`, `_bindings_vbox`, `_discard_modal`, `_status_label`.
- Existing settings binding rows contain the label followed by the Button, in the established ten-action order.
- Loading page `_spinner` remains a Control.

Prefer adding public update helpers and stable node names rather than removing those fields. If you want to remove/rename them, describe a migration in INTEGRATION.md and let Codex update/remove its adapter before making the incompatible change. This temporary compatibility requirement prevents a visually improved page from breaking production integration.

Settings option payloads must remain:

```text
resolution: "1280x720", "1920x1080", "1600x900"
fullscreen: bool
graphics_preset: "low", "medium", "high"
frame_cap: 30, 60, 0   # 0 = unlimited
vsync: bool
master_volume / music_volume / sfx_volume: number 0–100
mouse_sensitivity: multiplier 0.5–3.0
language: actual supported language code
subtitles / reduced_motion: bool
```

Current resolution/preset/FPS indices in your original view have this exact order. Keep it stable or make the option-to-value mapping data-driven and document the change. Rebinding intents currently use `move_forward`, `move_backward`, `move_left`, `move_right`, `sprint`, `jump`, `interact`, `campus_guide`, `response_plan`, `pause`; Codex maps the aliases to the existing gameplay actions. Escape stays reserved for recovery.

## Your concrete assignment: fix presentation integration gaps

### 1. Reflect real settings values

The delivered `settings_page.gd::update_from_model()` currently updates status/dirty information but does not synchronize most controls to `settings.draft`. Fix this in your presentation module.

- Load/reopen/Cancel/Defaults/Apply must show the actual supplied resolution, preset, checkboxes, sliders and binding labels.
- Use no-signal setters or block signals during model synchronization. `present(model)` must not emit an edit simply because it is reflecting an existing value.
- Preserve active slider/key interaction and keyboard focus during frequent model updates. Do not rebuild the settings tree every frame.
- Show validation failures without claiming Apply succeeded. A failed disk write must not display “All settings up to date”.
- Restore Defaults changes the draft; it must not imply disk persistence before Apply.
- Keep Apply/Discard/Stay behavior clear. Do not navigate away when display confirmation is pending or a validation/save error remains. Codex owns deciding whether navigation is allowed.

Codex's adapter is compensating for these gaps meanwhile. Make your fix idempotent so both can coexist temporarily. Document what Codex can remove from the adapter after your handoff.

### 2. Capabilities and honest copy

- Do not offer French as a usable language unless actual translated UI resources are delivered and the backend advertises it. Currently English is the only supplied translation; disable/explain unsupported choices.
- No spoken dialogue or background soundtrack is currently shipped. Do not promise subtitles, ambient realism or footsteps that do not exist. Music/SFX buses are real services, but content availability must be described accurately.
- Codex may provide a subtle original launcher feedback tone routed to SFX. Do not add duplicate audio players or a parallel audio-bus graph.
- How to Play must describe this actual mission: inspect, preserve evidence, isolate workstation, revoke the reused session, restore baseline, verify, report. Do not invent cron-job investigations, persistence scripts or unrelated mission mechanics.
- Supported terminal examples: `help`, `ls`, `cd`, `pwd`, `cat ~/Help/START_HERE.md`, `ir inspect`. Do not claim flags/outputs that are not implemented. Ask Codex through the handoff if additional examples are needed.
- Interaction ranges differ: doors 2 m, PCs 2.8 m. Use the actual configured key labels; do not leave E/J/Tab hardcoded after rebinding.
- Display real credits/asset authors from project CREDITS/README/licence manifests, without invented names, sponsors or permissions.
- Use ENSA Games for the hub and ENSA Incident Response for the available mode. No Unity branding. A Godot credit does not need a forced startup splash.

### 3. Rapid navigation and focus safety

- Interrupting a 200–400 ms transition must leave only the current destination page interactive. Kill stale tweens, hide non-current pages and prevent transparent old pages intercepting input.
- Hidden pages must not handle Escape, keyboard navigation, clicks or audio. While the launcher is hidden for PLAYING, the view must not consume gameplay input.
- When returning to a page, restore meaningful focus. Loading updates must not steal focus from Cancel. Keyboard-only navigation must reach every active control and Back action.
- Disabled Zombie RPG must never emit a mission-start intent or create a 3D preview scene. The backend independently enforces this too.
- Avoid re-focusing a default button on every `present()` call.

### 4. Modal presentation and layout

- Center and size the display Keep/Revert and dirty-settings prompts correctly after layout. Their current center anchor alone does not guarantee centered content once the panel receives its minimum size.
- While a confirmation modal is open, underlying controls must not receive mouse or keyboard activation. Trap focus appropriately, then restore it on dismissal.
- Display Keep/Revert countdown comes from the model, not a second UI timer. Esc should request the appropriate cancellation/revert through the controller, not bypass it.
- At 1280×720 and 1920×1080, essential buttons, validation text, long bindings and error details must stay visible; settings content should scroll when necessary.
- Avoid labels saying “Press any key” indefinitely after capture completes/cancels/conflicts. Use `capturing_action` plus authoritative draft bindings to restore the right text.

### 5. Loading, ready and recovery presentation

- Startup/hub must not instantiate or wait for the live campus to create a cinematic background. Use your lightweight local stills.
- Resource-stage progress is not whole-mission progress. Clearly label resource loading and use stage/counters for construction. Null progress means indeterminate, never a fake percentage.
- Real stage labels may include Creating campus geometry, Preparing surfaces and collision, Aligning entrances, Preparing batches, Merging surfaces, Placing stations, Applying finishes and readiness checks. Display them without inventing completion.
- Still preparing shows actual stage and elapsed time. Do not impose a fixed animation duration or block Back/Cancel to finish a cinematic sequence.
- READY should show Enter Mission only on actual backend readiness. Failed/cancelled requests cannot visually transition themselves to ready.
- Error offers Retry, Return to Menu and Quit, honoring allowed actions. Diagnostic detail is development-only and can be expanded without overflowing the page.
- Reduced motion must stop decorative scanning, pulse, parallax and spinning motion; preserve readable status. Queue a redraw when the static indicator changes so a stale arc does not remain visible.

## QA you own

Keep your standalone harness under `tools/antigravity/launcher/`. Extend it with real contract edge cases, not just attractive fixed screens:

1. Reopen settings with non-default saved values; edit, Cancel, Defaults and simulated Apply failure. Verify each widget equals the authoritative draft and synchronization emits no edit intents.
2. Rebinding: begin capture, cancel with Escape, accept a new key, show a conflict and return to the actual binding. Do not add a competing raw-key listener; backend owns capture.
3. Only English supplied; unsupported subtitles/music copy accurate.
4. Rapidly switch Home → Modes → Briefing → Settings → Home before prior tweens finish. Assert only the active page can receive input and no old pages remain visible afterward.
5. Display confirmation and dirty modal: center, correct text/countdown, keyboard focus containment, no clicks through the panel, correct returned intent.
6. Repeated identical `present()` calls and frequent loading progress: stable focus, node counts and signal counts; no accumulated tweens/audio.
7. Continue absent/present; Zombie unavailable; incorrect request IDs simply echoed to backend rather than interpreted locally.
8. Measured/indeterminate/still-preparing/cancelling/ready/error fixtures; no fabricated progress or auto-entry.
9. Reduced motion at every animated page. No game scene dependency in the harness.
10. Native captures at 1280×720 and 1920×1080, plus long text/compact window checks. Report actual resource sizes and UI timings; do not call them gameplay performance results.

Run your standalone test with the known engine and `--path . --script res://tools/antigravity/launcher/preview_launcher.gd`. Use headless tests for contract logic and native rendering for visuals. Do not benchmark at the same time as Codex: mark STATUS.md before and after a native test, and avoid running if another identified QA process is active. Never kill it to get the GPU.

After Codex's controller is runnable, inspect the real integrated menu in a separate agreed test window and report issues by screen, action sequence, expected/actual behavior and screenshot. **Do not edit the core to fix them yourself.**

## Zombie asset inventory: future work only

The user supplied:

```text
..\3d models\zombie\free_benelli_m4_shotgun_gameready_rigged.glb
..\3d models\zombie\low_poly_female_warrior_charctor.glb
..\3d models\zombie\low_poly_lion_with_wings_warrior_character_model.glb
..\3d models\zombie\pistol_animation_wip__really_stiff.glb
..\3d models\zombie\scorpion__first_person_animations_2026_remake.glb
..\3d models\zombie\Zombie Apocalypse Kit - March 2024-20261102T030551Z-1-001.zip
```

Do not copy these into the boot scene or preload them for the mode card. One first-person asset is about 141 MB; loading it for a menu would undermine this task. Codex will record the inventory and available provenance/animation information for a later independent RPG mode. Keep COMING SOON honest. Any later playable mode needs its own agreed gameplay scope, adapter, saves, settings and tests.

## Required handoff — make integration reviewable

Update `antigravity/launcher/STATUS.md` and `INTEGRATION.md` with:

- Exact changed files and public interface/compatibility statement.
- Which of the gaps above are fixed, tested or still unresolved.
- Actual test commands/results and capture paths; distinguish fixture success from integrated behavior.
- Any optional new model fields/intents; absent fields must preserve version-1 operation.
- Which Codex adapter compensations can be safely removed and why. Do not remove them yourself.
- Resource/texture/audio budgets, licences and missing-content notes.
- Rollback limited to your presentation changes; do not roll back core loading/services.

Do not claim all 19 core files remain untouched as a substitute for testing the interface. Preservation is required, and actual working integration is required too.

## Completion order and final acceptance

1. Keep version-1 interface/adapter compatibility stable.
2. Fix model synchronization, capabilities/copy, focus/transitions and modal layout.
3. Run standalone edge-case and native visual QA.
4. Deliver the handoff. Codex integrates/removes redundant adapter behavior and runs real loader/settings/save/gameplay regression.
5. Final joint acceptance requires: menu works without campus load; real mission loads/cancels/retries; saved settings and Continue work across restart; Zombie cannot launch; pause/return/relaunch works; existing doors, PCs and mission remain intact; screenshots and measurements match the delivered build.

Proceed within this ownership boundary without waiting for core loading to finish. If a change would break the shared contract or a listed adapter dependency, document the proposed change first and continue with independent presentation fixes.
