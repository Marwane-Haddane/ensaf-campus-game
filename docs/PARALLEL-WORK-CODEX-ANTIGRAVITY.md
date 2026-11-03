# Parallel work: Codex + Antigravity

The user's pasted assignment already contains the complete After Hours build. The latest brief differs only by one explicit cancellation-completion safeguard. Keep the existing assignment; do not restart or duplicate it.

**Current progress:** Codex has implemented the shared platform work below; focused fixtures pass 37 checks and native cybersecurity regression passes 72. Antigravity's checkpoint/metadata/lifecycle updates are present. The initial real survival run caught Esc-to-resume; Antigravity's fix is now delivered and the latest shared harness reports 29/29 passing. Native capture still exposes HUD/viewmodel/environment presentation work. Antigravity's next concrete implementation work is [ANTIGRAVITY-ZOMBIE-PLAYABILITY-AND-VISUAL-FINISH.md](ANTIGRAVITY-ZOMBIE-PLAYABILITY-AND-VISUAL-FINISH.md). Keep production availability gated until that work is integrated.

## Antigravity retains the playable mode

Own all implementation under your existing `*/antigravity/zombie/` namespaces: controller, weapons/animations, enemies/navigation, level route, encounters, objectives, inventory, HUD, checkpoint state and standalone entry. Continue improving the actual playable episode. Codex will not edit those files while you work.

Your delivered files now include these contract fixes. Preserve them while finishing the native playability/presentation work:

1. **Checkpoint ownership and validation.** `save_store.gd` currently uses constant `SAVE_FILE`, whereas the launcher needs an overridable `path` for isolated tests and a single authoritative save service. Expose `var path` with the production default; derive parent/tmp/backup paths from it. Make `create_session` share the adapter's service with the game rather than the game always constructing a second one. Validate schema, mode/mission, nested payload types, finite/ranged player values and quest/inventory data. Preserve the last valid file if a commit fails.
2. **No initialization overwrite.** `zombie_game.gd` currently calls `_create_checkpoint("cp_start",...)` during construction, before the launcher chooses Enter versus Cancel/Continue. In a managed session, defer persistent writes until intentional gameplay entry. Loading or cancelling must not overwrite the previous checkpoint.
3. **Restore the world, not only dictionaries.** Adapter `restore` must restore valid player/inventory/mission state, resynchronize pickups/power/enemies using `_resync_world_state`, refresh HUD, and verify a safe player pose. The launcher must receive false plus `last_error` on invalid restoration. Freeze restored state until Enter; no duplicate rewards or resurrected defeated enemies.
4. **Managed replay/restart.** `reload_current_scene()` inside a child mode would reload the ENSA Games boot scene. In managed mode, restart the mode's own state/scene through an explicit request or mode-local reset, preserving the launcher. Standalone replay still needs to work.
5. **Pause/input lifecycle.** Ensure Resume restores processing and tree pause consistently. Frozen/initializing sessions must not run attacks, damage, shooting or capture the mouse behind Loading/Ready. Cancel must eventually complete initialization with an error/cancelled result. The shared launcher will remain active during a paused mode, and its session root will explicitly use pausable processing.
6. **Shared preferences.** Apply the existing InputMap movement/run/jump/interact bindings and reduced-motion/sensitivity preferences. Your Settings action should request shared settings without silently toggling a saved preference first. Extra zombie controls remain mode-owned. Document what graphics settings are supported.
7. **Metadata contract.** Mission `controls` must be an Array of `{ "action": "...", "binding": "..." }` dictionaries, not a prose String. Your save summary may be a Dictionary; Codex will normalize it for the launcher. Supply actual checkpoint/mission labels and keep artwork authentic.

These are gameplay/persistence implementation tasks, not a new verification-only assignment. Keep polishing animations, combat readability, NPC behavior and the complete episode while Codex works on the platform.

## Codex owns shared platform implementation in parallel

Writable scope: `scripts/launcher/`, `scenes/launcher/`, `tools/launcher/`, launcher documentation and final registration metadata. Minimal metadata-driven presentation hooks can be applied in the integration adapter; your zombie folders remain untouched.

Codex will implement:

- Mode-driven mission defaults/briefing and control-hint normalization; no cybersecurity mission IDs assumed for another available mode.
- Per-mode adapter/save services and valid Continue routing, with a recent-mode pointer and independent test paths. A survival checkpoint must never be passed to the cybersecurity store or displayed as the cyber case.
- Safe tree-pause ownership: shared UI/settings/display countdowns and cleanup remain responsive while a mode is paused; the world remains frozen behind Ready and settings.
- Generic loading/readiness errors, scene contract checks, cancellation ownership and bounded disposal. No dependence on cyber HUD field names or expected station counts in shared loader diagnostics.
- Focused two-mode lifecycle fixtures plus existing cybersecurity regression, followed by actual Zombie launcher integration once the module's checkpoint/restore fixes are delivered.
- Final available-mode registration and home/mode-card wiring after concrete integration passes. Until then the production Zombie preview stays Coming Soon.

## Small handoff contract

Keep `antigravity/zombie/STATUS.md` and `INTEGRATION.md` current. Record changed APIs, actual commands and unresolved issues. Update the proposed `MODE-REGISTRATION.json`, but do not edit production registration or shared launcher files.

The shared adapter methods remain those in the original brief. `save_service()` returns the same mode-owned service used by the game. A service offers `path`, `last_error`, `read_save`, `write_save`, `summary`; the mode adapter owns semantic checkpoint validation/restoration. Mode constructors return resource paths and do not instantiate worlds.

Avoid simultaneous native GPU captures/benchmarks; inspect active Godot processes before starting one. Never stop someone else's process. Headless tests may proceed independently if they use separate output/save paths.

The shared loader now supports optional `supports_cooperative_cancellation() -> bool`. Default behavior invalidates ownership immediately and drains an active construction before disposal. Only opt in when `cancel` cooperatively stops the builder and `initialization_finished` is set after all pending construction coroutines finish. The current zombie cancellation method immediately sets that flag while `campus.build()` may still be awaiting a frame; do not opt in with that implementation. CampusRuntime exposes its existing `cancelled` flag, not a `cancel()` method.

The session root uses pausable processing; the launcher/UI services use always-processing. Ready pauses the tree to suspend AI/timers while preserving floor/door physics bodies. Any Esc-to-resume handling must live in the mode's always-processing HUD (or equivalent input owner) while paused, and must ignore input when the shared settings page owns it.

Completion is a playable mode plus a working ENSA Games entry, not two disconnected demos. Antigravity delivers the mode; Codex connects and validates the shared transitions. Neither side needs to redo the other's implementation.
