# Antigravity — finish real Zombie playability and presentation

Keep the original After Hours assignment and your existing module. The seven save/restore/lifecycle changes in the parallel-work note are now present. This follow-up targets issues observed in the actual ENSA Games integration, not a request to rebuild the mode or only write test reports.

Codex has implemented lazy per-mode services, mission selection, separate save routing, recent-mode Continue, responsive shared settings during pause, generic loader diagnostics, safe request draining and Ready-state freezing that preserves colliders. Shared platform fixtures pass 37 checks; native cybersecurity regression passes 72. Your real mode reaches Ready/Playing and restores inventory through the launcher.

## 1. Preserve the now-fixed Esc pause/resume input

The initial Codex native run in `tools/launcher/zombie-launcher-native.log` caught **Escape can also resume the paused game**. Antigravity's subsequent fix has landed and the latest shared `zombie-launcher-test.json` reports **29/29 passing**. Preserve that behavior while implementing the presentation fixes below; do not redo the already completed input repair.

The session root is pausable. Once SceneTree.paused is true, its `_unhandled_input` cannot recover the pause. Keep the appropriate paused-state keyboard owner in the always-processing HUD (or equivalent). Close only the active mode menu, emit the correct resume event, restore input/capture and consume the event. Do not also reopen pause on that same key event. Handle key release/echo safely.

Guard ownership: hidden/frozen HUD and shared launcher/settings must not consume those mode shortcuts. Inventory/journal/dialogue/death/victory need deliberate Back/Esc behavior; Esc on a victory/death screen must not bypass its intended state.

## 2. Repair the actual HUD layout

Evidence: `tools/launcher/zombie-integrated-playing.png`, native 1280×720. Only the top objective is visible; the expected health/stamina/scrap, weapon/ammo and crosshair are absent from the visible frame.

Implement a robust full-rect HUD root with real margins/containers and correct bottom anchoring. In `zombie_hud.gd`, bottom controls currently set bottom anchors/offsets without a matching top offset or grow direction; inspect their final rectangles rather than assuming custom minimum sizes move them above the screen edge.

- Health/stamina/scrap must sit fully within bottom-left safe margins.
- Weapon name, magazine/reserve must be visible at bottom-right.
- Crosshair/hit marker must use a correct centered rectangle and draw coordinates.
- Context E prompt appears only for a real nearby target, without blocking aim.
- Objective text remains restrained and readable, wrapping when necessary.
- Pause/inventory/journal/dialogue/upgrade/death/victory panels remain fully in bounds and usable with keyboard/mouse.

Implement responsive layouts at 960×540, 1280×720 and 1920×1080. Do not hardcode coordinates that work only in a standalone harness; the same HUD must work inside the shared launcher viewport. Preserve the survival mode's navy/amber identity.

## 3. Correct weapon/viewmodel presentation

The native gameplay capture does not show a readable held pistol in the expected first-person framing; small character/model parts appear at the bottom edge instead. Inspect the imported model hierarchy, camera/viewmodel transform, authored animation origin and active clip.

Deliver an actually visible, correctly scaled pistol/hands viewmodel with a natural lower-right or central framing, correct barrel direction and camera near-plane clearance. Draw/idle/aim/fire/reload/switch must keep the weapon in the view and blend coherently. Use the supplied animations rather than leaving a rest/T-pose. Verify muzzle position against the visible barrel and retain the existing wall-obstruction logic.

The optional heavy Scorpion should obey the same framing and animation contract. Keep the baseline pistol reliable before adding further equipment.

## 4. Finish dusk lighting and scene readability

The integrated capture shows severe speckling/striping on the glazed building/stone tower and an empty flat sky. Inspect shadow acne/bias, overlapping surfaces/material depth behavior, camera clip planes and surface filtering in the real launcher session. Distinguish overlapping geometry from lighting artifacts before changing geometry.

- Preserve the exact ENSA architecture/layout and existing approved models.
- Correct the visual artifacts from courtyard, entrance and 45-degree views.
- Create a readable dusk sky/environment and balanced outdoor/interior lighting using Compatibility-supported features.
- Retain restrained warm/cool contrast; avoid orange clipping or unreadable black interiors.
- Ground props correctly; keep routes, entrances and handrails free of obstruction.
- Respect low/medium/high settings, reduced motion and the Iris Plus performance budget. Do not fix shadow artifacts with many expensive lights.

Shared campus source/runtime files remain read-only. Apply mode-owned environment/material overrides or derived resources without rewriting source assets or the cybersecurity environment. Consult the existing shared polish fixes for known shadow/material issues; do not blindly install a module that assumes cyber-only fields.

## 5. Cancellation cooperation detail

Codex's shared loader now cancels ownership immediately but drains active construction before disposing it. It only calls cooperative `cancel` during a build when the adapter explicitly exposes `supports_cooperative_cancellation() -> bool` returning true.

Your current `cancel_initialization` marks completion immediately while an awaited `campus.build()` may still be running, and checks for a nonexistent CampusRuntime `cancel()` method. Leave cooperative opt-in absent until fixed. If implementing it, set the existing `campus.cancelled` flag, let the active construction coroutine unwind, then set initialization_finished. Never free objects with pending builders still resuming on the next frame. The shared fallback already makes user cancellation safe; optimize cooperative stopping only after it is correct.

## Ownership and concrete handoff

You own only your existing `*/antigravity/zombie/` namespaces. Codex retains `scripts/launcher/`, shared entry/registry, minimal completed-launcher presentation hooks and cross-mode integration. Keep production registration untouched.

Deliver actual HUD/viewmodel/environment and input fixes, native captures of the corrected gameplay and menus, and updated STATUS/INTEGRATION notes. Use the same real mode scene/adapter through `tools/launcher/zombie_launcher_test.gd`; no substitute gallery or concept render. Add meaningful HUD-rectangle and real-input assertions where useful.

Avoid simultaneous native GPU runs. Inspect active Godot processes and do not terminate another agent's/user's process. The native shared test uses isolated `user://ensagames/tests/real-zombie-launcher*` files; do not run it concurrently with another copy.

Once these concrete mode fixes are delivered, Codex will rerun the shared entry/Continue/cancel flow and enable the production Zombie mode card. The cybersecurity mode remains playable throughout.
