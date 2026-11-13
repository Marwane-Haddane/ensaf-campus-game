# Antigravity task — ENSA campus environment polish

You are collaborating with Codex on an existing Windows first-person cybersecurity training game. Work on the environment task below. This is implementation in the existing Godot project, not a website, replacement game, image mockup, or engine migration.

## Working directory and engine

Project: C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game
Parent campus project: C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4
Godot project files: project.godot and main.tscn. Windows launch: PLAY.cmd; editor: EDIT.cmd.
Engine: Godot 4.3, GDScript, GL Compatibility renderer. Bundled executable: runtime\Godot.exe. Console executable installed at C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe.
Target machine uses Intel Iris Plus integrated graphics. Current game targets 1280x720 and 2x MSAA. Preserve this renderer and engine version. Do not add a dependency on Unity, Unreal, Vulkan-only effects, a browser, a VM, or a real Linux installation.

First read README.md, CREDITS.md, ASSET-APPROVALS.md and docs/COLLABORATION.md. Inspect current production files and screenshots; Codex may continue changing protected files while you work.

## Ownership — avoid shared-file conflicts

Codex owns all core gameplay and integration: movement, physics, doors, stairs/landing repair, crosshair targeting, the Linux desktop/shell, mission engine, reports, HUD, pause/menu, project settings and source-campus import/batching.

Your task is campus ENVIRONMENT VISUAL POLISH and its performance/visual QA, implemented in an isolated optional module.

You may create/edit ONLY:
- scripts/antigravity/environment_polish.gd and additional helpers inside scripts/antigravity/
- assets/antigravity/ for any original/licensed environment resources
- tools/antigravity/ for a native Godot preview harness, tests, measurements and screenshots
- antigravity/STATUS.md, VISUAL-AUDIT.md, INTEGRATION.md and CHANGELOG.md

Do not directly edit main.tscn, project.godot, PLAY.cmd, EDIT.cmd, scripts/main.gd, scripts/campus_runtime.gd, campus_materials.gd, campus_occlusion.gd, canopy_detail.gd, entrance_geometry.gd, interactive_door.gd, campus_doors.gd, interaction_focus.gd, interaction_target.gd, training_ui.gd, workstation_desktop.gd, desktop_window.gd, workstation_shell.gd, pause_menu.gd, sliding_door.gd, atrium_entrance_repair.gd, the existing shaders, mission JSON or existing tests. Do not manually change runtime or .godot cache files. Normal engine-generated imports are fine.

If a shared-file change is essential, explain the exact file, insertion point and patch in antigravity/INTEGRATION.md. Leave Codex to apply it. Do not change building geometry, transforms, door openings, pivots, floor heights, colliders, stairs, ramps, navigation routes or the surrounding layout in this task.

## Goal and visual direction

Improve the actual playable 3D environment throughout the campus. The user wants a coherent professional look, with realistic restrained surface variation, readable daylight, grounded furniture and consistent finishes. A polished single room is insufficient. Preserve the recognizable ENSA campus rather than replacing it with an unrelated spectacular location.

Cover:
1. Courtyard/plaza, paving, gardens, trees and palms.
2. Auditorium reception, counter and glass facade.
3. Auditorium seating, wood wall panels, stage and ceiling.
4. Glazed building entrance and atrium.
5. Security workstation/server area.
6. Auditorium teaching workstation.
7. Cream main-building entrance, canopy and connecting pavement.

Priorities: remove distracting shadow acne/moiré and shimmer; improve gentle contact/grounding; restrained glass reflections/transparency; clean cream finishes; subtle stone/wood/fabric detail; coordinated plant tones. Avoid very noisy plaster, corrugated-looking wood grain, blown-out floors, overly dark interiors, garish neon or heavy postprocessing. Avoid decorative clutter in walking paths. Do not paint new geometry over a door or transparent opening.

Reference images are retained inside the project so you do not need temporary chat attachments:
- docs/references/environment-target.png — professional in-game art direction.
- docs/references/campus-glass-building.png — real campus glass building.
- docs/references/campus-wide-exterior.png — real campus wide exterior.
- docs/references/cream-entrance-target.png — cream entrance aesthetic target.
The last reference is an aesthetic target; preserve our actual geometry and the implemented door/landing behavior. Use current native screenshots in tools/door-*.png and tools/visual-polish/ as the implemented baseline. Do not treat generated target images as proof of the current game's appearance.

## What already exists — preserve it

- Optimized source campus in assets/campus.glb; object provenance in assets/asset-manifest.json.
- Original editable Blender at ..\3D-modeling\campus-design-v9\ensaf-campus-v9-final.blend. Do not overwrite it or regenerate the full campus export.
- Shared bounded-cost campus material library, rendering batches, tree crown refinement and conservative solid-wall occlusion.
- Three approved interactive PC assemblies; two approved server racks; imported office furniture.
- Contextual PC outline/label/E prompt only while aiming at a nearby PC; range and wall checks.
- Linux-style in-game desktop, movable native windows, virtual folders/files, typed ls/cd/cat/ir commands, history, completion and validated incident report. This is a contained game simulation; do not connect it to an operating-system shell or real campus services.
- Full-screen native pause/start/destination menu with the existing courtyard behind a restrained blur/gradient.
- Reception central entrance: two separate sliding glass panels, following the user-confirmed change to the latest sliding-door reference.
- Cream entrance: central double glass leaves with outer hinges, fixed sidelights and slim black frames; inward 90 degrees.
- Door interaction is E while aiming within 2m; about 1s ease-in/ease-out; moving solid leaf collisions and anti-crush handling.
- Atrium front entrance: hinged glass double doors, fixed transoms and aligned threshold. Atrium side entrance: single hinged door opening onto the broad portico; floor gap closed at y=1.814 with continuous tiled landing and railing. Read docs/CODEX-STATUS.md and docs/ENTRANCE-BUGFIXES.md for current source geometry.
- Repaired cream entrance: three equal steps, consistent landing/threshold at y=.52, matching full visible interior plinth collision, retained original canopy footprint/pillars, underside slats and recessed light strips.

Do not replace or duplicate these systems. Do not use always-visible interaction labels. Do not restore the old dashboard-style computer interface or central boxed pause menu.

## Asset policy

The user explicitly requires review before importing/downloading NEW third-party 3D models. The five user-supplied approved GLBs already live in assets/user_models: gamer_setup_pack.glb, office_chair.glb, office_desk_140x60.glb, server_rack.glb and server_rack_1.glb. Original downloads are in ..\3D-modeling\3d models. Reuse them where appropriate without altering the originals or their authored texture maps.

For any proposed new 3D asset, provide its preview, exact source URL, creator, license, download format and approximate size, then wait for user approval. Do not download/import it automatically. No purchases, publishing or uploads. Credit any new non-3D resources you create or are authorized to use, retaining licenses. Keep materials and textures original/licensed, shared and modest in size; avoid unnecessary huge assets.

## Module contract and integration

Provide a Node3D script at res://scripts/antigravity/environment_polish.gd with:
  func install(game: Node3D) -> Dictionary

It should be idempotent, detect the actual game.campus/camera/environment resources, and return a compact report of changes, resource counts, affected areas and measured costs. Any runtime material replacement must duplicate shared resources before altering them, apply through explicit material/source-name allowlists, preserve approved prop maps, glass alpha and render batching, and be reversible through uninstall() if feasible. Do not indiscriminately retune every imported material.

Do not install your module in protected production files. Demonstrate it through your own tools/antigravity preview harness using the existing main.tscn, waiting for game.ready_to_play before installing. Supply the exact proposed integration call for Codex to review and apply once.

Useful current destinations in scripts/main.gd:
- Campus plaza: (-27, 1.25, -85)
- Reception / response desk: (-36.2, 1.91, -104.1)
- Auditorium rear aisle: (-37, 1.924, -107.95)
- Glazed building entrance: (-5.8, 2.80, -102.9)
- Security training area: (0.90, 2.80, -110.5)
- Auditorium teaching desk: (-43, 1.09, -121.4)
- Cream main entrance: doorway near (-14, .52, .04), outdoors toward +Z.
Read the current files to confirm values. Never move these locations to hide visual problems.

## Verification and performance

Capture and inspect before/after native game views for all seven areas, using the same resolution/camera/lighting state in each comparison. Include cream entrance front, 45-degree exterior and inside-looking-out views. Do not use edited/generated mockup images as proof of implementation.

Keep shared material/texture budgets bounded; retain instancing, occlusion and LOD. Avoid expensive per-pixel procedural noise, unnecessary real-time shadow lights, broad translucent overdraw and giant textures. Do not enable unsupported effects just because they look attractive in a different renderer. Measure warmed play under comparable conditions; separate first-load shader compilation from actual gameplay. Aim to keep roughly 30fps where this PC can sustain it; report actual per-view results and any regression candidly rather than promising fixed FPS.

Run a native Compatibility preview and inspect renderer/script errors. A headless smoke test alone does not establish visual quality. On this project minimized native windows can skip normal drawing: for a test-only capture, await two process frames then call RenderingServer.force_draw(false), then get_viewport().get_texture().get_image(). Avoid an unbounded frame_post_draw wait. Do not close the user's running game or run overlapping GPU benchmarks with Codex. State when a GPU test starts/finishes in STATUS.md; use short bounded runs and close only your own test processes.

## Deliverables and collaboration

1. antigravity/VISUAL-AUDIT.md: prioritized findings tied to actual views and source objects/materials.
2. Isolated module/resources within your allowed folders.
3. antigravity/INTEGRATION.md: exact API, proposed integration snippet, resource/licensing notes, validation steps and limitations.
4. tools/antigravity/: genuine before/after screenshots and performance/error evidence.
5. antigravity/CHANGELOG.md: precise changed-file list and behavior summary.
6. antigravity/STATUS.md: current phase, files touched, test process status, blockers and final handoff.

Do not mark completion merely because the module parses or the game launches. Inspect every affected area, ensure doorways and routes stay clear, and explain any remaining quality/performance limitation. End with a concise handoff that the user can paste back to Codex, including the files to review and how to test your isolated module. You and Codex share local files; do not assume a direct chat connection to Codex or make uncoordinated changes to its protected files.
