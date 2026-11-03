# Antigravity — final acceptance of the combined ENSA Games launcher

Give this entire file to Antigravity. This is the next task after the home-reference redesign. It does not ask you to repeat the old two-card menu, settings synchronization or clean-artwork work.

## Objective

Verify and finish the **actual combined launcher**, using Codex's real controller/services and your delivered presentation. Concentrate on the newly integrated reference-home layout, real saved-session display, input/focus and rendering at supported screen sizes. Fix only presentation defects you reproduce. Deliver a concrete final acceptance report with native evidence.

Project:

```text
C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game
```

Engine:

```text
C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe
```

Normal entry is now `res://scenes/launcher/boot.tscn`. **PLAY.cmd opens the real launcher.** The old `main.tscn` is the on-demand cybersecurity session, not the main menu.

## Current state — use this as the baseline

Already implemented by Codex:

- Lightweight first-frame boot and interactive main menu before campus loading.
- Genuine staged resource loading, request IDs, safe cancellation/draining, error/retry and readiness checks.
- Incremental campus construction/cleanup, 94 derived scene sections and precomputed exact collision pieces; original campus GLB unchanged.
- Settings persistence, graphics/display/audio/input controls, display Keep/Revert/timeout and reduced motion.
- Validated per-mode checkpoint, real Continue, mission/points restoration and safe player pose.
- Actual pause → settings → pause and pause → launcher → new mission paths.
- Registry and adapter seam for future modes. Zombie remains COMING SOON; its supplied models are inventoried only.

Recent verification already passed:

- 72 combined native integration checks.
- 82 checks in five load/play/return cycles.
- 19 native settings checks and a separate-process preference check.
- 84 entrance checks and 81 PC checks against both source and derived campus.
- Existing hover, shell, desktop and smoke regressions.

Read `docs/LAUNCHER-STATUS.md`, `docs/ENSA-GAMES-ARCHITECTURE.md` and the actual latest JSON/logs. These baseline results do not replace your visual/input review, and should not be rerun endlessly unless your changes affect them.

## Critical coordination: Codex's home layout calibration is active

After inspecting your latest 720p/1080p captures, Codex added a **presentation-only reference calibration** in:

```text
scripts/launcher/launcher_view_adapter.gd
```

It preserves your behavior and adjusts home typography, vertical spacing, sidebar branding, thumbnail proportions and proportional scaling. In particular, it makes the heading larger/bolder, centers the Play label, prevents the 1080p version using tiny 720p-sized UI text, and keeps the case section near the reference location.

**Do not delete, replace, edit or work around this adapter without a migration handoff.** It is Codex-owned and is currently the production integration seam. Your previous statement that the adapter can be entirely removed no longer applies to this new reference-calibration code; the old settings/modal/transition compensations have already been removed.

Before changing home internals, read the adapter. It currently relies on these home fields:

```text
_root_vbox, _left_rail, _bottom_left_box, _main_content_margin,
_heading_label, _subheading_label, _emblem_rect, _cta_play_btn,
_play_btn, _modes_btn, _continue_btn, _settings_btn,
_how_to_play_btn, _credits_btn, _quit_btn,
_case_title_label, _workstation_rect, _zombie_thumb,
_zombie_card, _zombie_title, _progress_segments
```

Preserve their types and parent hierarchy during this pass. If a better native layout should absorb the adapter, propose exact equivalent changes and the adapter lines to remove in `antigravity/launcher/INTEGRATION.md`; let Codex perform the coordinated migration. Do not introduce competing scale factors or resize loops.

## Ownership

You may edit only:

```text
scenes/antigravity/launcher/
scripts/antigravity/launcher/
assets/antigravity/launcher/
shaders/antigravity/launcher/
tools/antigravity/launcher/
antigravity/launcher/
```

Read-only for you: `scripts/launcher/`, `scenes/launcher/`, gameplay/core scripts, project.godot, PLAY.cmd, tests outside your namespace, original/derived campus data, and `assets/launcher/` supplied by Codex.

Do not introduce a second launcher controller, save store, settings store, loader or mode registry. Keep the version-1 public presentation API/intents unchanged. No new 3D models, no Zombie gameplay and no changes to current cybersecurity gameplay in this task.

## Visual target and actual assets

- Selected target: `docs/references/launcher-final-target.png`.
- Emblem source: `docs/references/ensa-emblem-source.png`.
- White transparent vector: `res://assets/launcher/ensa-emblem-white.svg`.
- Dusk background: `res://assets/launcher/campus-dusk-reference.png`.
- Workstation thumbnail: `res://assets/launcher/case-workstation.png`.

The SVG is a real monochrome vector recreation from the supplied raster, not an official vector master. It has already passed white-only/transparent/no-embedded-raster checks. Do not substitute the old shield or a blue/red bitmap. The menu illustrations do not replace the actual playable campus geometry.

Current combined reference captures, produced through the real boot/controller and adapter:

```text
tools/launcher/reference-home-1280x720.png
tools/launcher/reference-home-1920x1080.png
tools/launcher/reference-home-continue-1920x1080.png
```

Prefer these over older standalone images when evaluating production layout. Older integrated-home.png files can predate the latest layout and should not be presented as current proof without checking timestamps.

## Work package 1 — final home fidelity and layout checks

Use the real `boot.tscn` controller, not only `launcher_view.tscn` with fixture data.

1. Compare settled screenshots at 1280×720 and 1920×1080 against the selected reference. Check hierarchy, large heading, CTA alignment, sidebar, case image/details, smaller Zombie preview, divider rules and footer.
2. Confirm **AVAILABLE is absent**, including hidden empty badge rows/gaps. Keep the backend availability metadata intact.
3. Confirm the white SVG and real menu icons render after a fresh import/restart. No missing icons, old HUD pixels, crosshairs or debug-contract labels in normal play.
4. Check the active-case title/progress/objective at 0/7, an in-progress checkpoint and 7/7. Use the authoritative `case_summary`; do not infer saved progress from fixture labels or read save files in the view.
5. Test valid Continue visible and no-save/corrupt-save Continue absent through the real controller/store. The extra item/summary must not push Quit below the screen or collide with other navigation.
6. Check a compact 960×540 window and a wider supported desktop window. Primary controls remain reachable, the hero/case do not overlap, footer remains visible, and the new scale calibration does not apply twice.
7. Do not add fake loading text to home. It says Menu ready after initialization. Real resource stages appear only after mission start.

Fix reproducible issues inside your presentation namespace; log any issue requiring the Codex adapter as a concrete handoff rather than changing that file.

## Work package 2 — keyboard/mouse usability on the combined build

- Keyboard-only: focused Play, Enter/Space, Tab/Shift+Tab, arrows and Escape. Both Play controls open the real briefing, without duplicate mission requests.
- Mouse: navigation hover/click, CTA, settings widgets, Back and Quit. Scaled controls must receive clicks at their visible location; check this at both main resolutions.
- Hidden/transitioning pages cannot intercept input. Rapid Home → Modes → Briefing → Back → Settings must leave a single active destination and stable focus.
- Loading Cancel remains focusable during frequent progress updates. Error recovery and Ready's Enter Mission work via keyboard and mouse.
- In-game pause → Settings → Back must return to the paused game, not lose mouse ownership or close the application.
- A PC desktop must still own typing; the launcher cannot consume terminal input after hiding.

Do not repeat every core physics test for this package. Test the input/visual boundary that changed, then use existing core reports as supporting evidence.

## Work package 3 — presentation consistency of secondary screens

The home art now differs from the earlier launcher. Check that Briefing, Game Modes, Settings, How to Play, Credits, Loading, Ready and Error remain readable/coherent over the new dusk art.

- Consistent off-white type, navy/graphite, restrained teal and amber. Avoid unrelated hacker-dashboard decoration.
- Four settings tabs scroll correctly; Apply/Cancel/Defaults stay visible. Values/validation reflect the controller's saved/draft state.
- Display confirmation and dirty prompts remain centered, contain keyboard focus and block clicks beneath them at both resolutions.
- Reduced motion suppresses decorative movement without hiding progress/status or breaking page transitions.
- English is the supplied active translation. No claim of shipped dialogue/music. Control hints show actual bindings.
- Credits retain real engine/asset/contributor information. No implementation details such as Contract v1 in normal player-facing screens. Development diagnostics can be enabled deliberately by Codex's `--launcher-debug` flag.
- Longer errors and validation messages wrap or scroll without pushing Retry/Return/Quit off-screen.

## Test isolation and safety

- Use your own harness under `tools/antigravity/launcher/`.
- For real-controller tests, instantiate `scenes/launcher/boot.tscn` and set `test_preferences_path` / `test_save_path` to unique files under `user://ensagames/tests/` **before** adding it to the tree. Do not overwrite the player's actual preferences/checkpoint.
- Use real settings/save services for integrated behavior. Fixture-only cases must be labelled as fixtures, not reported as persistence/load verification.
- Do not kill user/Codex processes, alter source models or move/delete their data.
- Check other Godot processes before native GPU tests. Coordinate through STATUS.md; never run simultaneous performance benchmarks. Ordinary UI screenshots are not a reliable gameplay FPS benchmark.
- Do not edit Codex's tests. You may run the current tests, but changing their source is not your task.

Useful current commands:

```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --script res://tools/launcher/home_visual_test.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://tools/launcher/integration_test.gd
```

The first exercises the **combined** view/controller and reference calibration. It uses isolated test files and produces actual home screenshots. Your own acceptance harness should add real keyboard/mouse and secondary-screen evidence without modifying it.

## Required deliverables

1. `antigravity/launcher/FINAL-ACCEPTANCE.md` with a table: check, resolution/input mode, actual result, evidence path, remaining issue.
2. Fresh native settled screenshots for the combined home (with/without Continue), settings/modal, briefing/loading/ready/error as changed or reviewed. Avoid redundant screenshots that prove no new behavior.
3. Exact changed files and test commands/results. Report pass/fail counts honestly; a screenshot or an intent fixture is not proof of saved state or physics.
4. Any Codex-owned issue: reproduction steps, expected/actual, screenshot/log and proposed minimal change. Do not apply it to core files.
5. Update STATUS.md and INTEGRATION.md to acknowledge the current adapter calibration and identify any safe future migration. Keep the public API stable.

## Completion rule

Finish when the integrated reference home is usable and balanced at the supported sizes, valid Continue is honest, input ownership works through menu/game transitions, secondary screens remain coherent, and there are no unreported presentation blockers. Do not create a new redesign or add features to keep busy. If nothing needs changing, deliver the verified acceptance report and exact evidence instead of inventing work.
