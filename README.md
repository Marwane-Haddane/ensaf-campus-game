# ENSA Games — campus launcher and Incident Response

Double-click **PLAY.cmd** to play on Windows. Use **EDIT.cmd** to edit the Godot project. Godot 4.3 is bundled from the engine already present on this PC; a separate engine installation is not required. Keep the entire campus-game folder together.

## Download for Windows

Friends can download and unzip the standalone Windows build from the [latest release](https://github.com/Marwane-Haddane/ensaf-campus-game/releases/latest). Open **ENSA-Games.exe** to play. This release is for 64-bit Windows PCs. The source project and editing tools are not needed.

The game uses the latest campus revision 9. The editable Blender source remains in `../3D-modeling/campus-design-v9/ensaf-campus-v9-final.blend`.

## Play

1. Select **Play**, review **The borrowed session**, then choose **Start Mission**. The menu is usable before the campus loads.
2. Follow real loading stages, then select **Enter Mission**. Cancel returns to the launcher; a failed load offers Retry.
3. Walk to reception, or press **Tab** and choose **Reception / response desk**. Aim at a door within two metres and press **E** to open it.
4. Look at the marked computer and press **E**. Open **Help** or type `cat ~/Help/START_HERE.md`, then follow the seven response guides.
5. Complete the incident report and review the debrief. **Continue** appears only for a valid saved session. Return to the launcher from the game pause menu.

Settings apply real display, graphics, audio, mouse and binding preferences and persist across restart. Display changes offer Keep/Revert. Choose **Game Modes → Zombie RPG** to play **After Hours**. Restore power, check in with Shaun, and evade the Brute's swing before counterattacking. Follow the truck's headlights and use **E** to board. The mode loads on demand. See [launcher architecture, tests and mode registration](docs/ENSA-GAMES-ARCHITECTURE.md). A fresh source copy without imported data needs one EDIT.cmd preparation; normal PLAY.cmd opens the launcher immediately.

Install Git LFS before cloning. The bundled Godot runtime and large models are stored in LFS. Run `git lfs pull` if you cloned before installing it, then run `EDIT.cmd` once to import assets.

### Controls

| Control | Action |
| --- | --- |
| WASD, ZQSD, or arrow keys | Move |
| Mouse | Look |
| Shift | Run |
| Space | Jump |
| E | Use the computer, server or entrance door under the centre crosshair |
| Tab, while exploring | Campus destinations / quick travel |
| J | Open or close the full response plan |
| Esc | Close terminal / plan, or pause and release the mouse |

The destination menu includes the plaza, reception, auditorium rear aisle, glazed building entrance, security training area and auditorium teaching desk. There are three interactive response PCs using the user's chosen computer model. The E card, console label and cyan screen outline appear only while the centre crosshair is over a nearby computer. Looking beside it, moving out of reach or standing behind a wall hides the cues. The same aiming rule applies to server and door interactions.

### Workstation desktop

The in-game Linux-style desktop has **Home**, **File System**, **Help**, **Evidence** and **Reports** folders, an Applications menu, four workspaces, a terminal and a file manager. Native windows can be dragged, resized, maximized, minimized to their task buttons, closed and reopened. Reports and the evidence journal open in document windows. Local-exercise status stays in the small bottom strip.

The terminal supports `pwd`, `ls`, `cd`, `cat`, `help` and the case actions listed by `ir help`. For example:

```text
ls
cd Evidence
cat session.log
ir inspect
```

**Tab** completes commands and virtual paths, **Up/Down** recalls command history and preserves unfinished input, and **Ctrl+L** clears the display. Help contains `START_HERE.md` plus seven step guides; selecting a guide previews it and its command link can run the next action. `ir report` opens the incident handover form. The Reports folder shows the submitted handover after completion.

### Pause and entrances

**Esc** opens a full-screen pause menu with the campus still visible behind a soft blur and dark gradient. Use **Resume exploration**, **Campus destinations** or **Quit game**. The initial screen enables **Start exploration** when loading finishes. The campus guide uses the same layout, and the menu shows the current case and objective.

Four entrances are interactive. **Reception** uses two central sliding panels that park in front of the fixed sidelights. The **cream main building** and **atrium front entrance** have hinged double glass doors; the **atrium side entrance** has a hinged single door opening onto the broad portico to keep the internal route clear. Aim within two metres and press **E** to open or close. Movement takes about one second. Solid collisions follow the visible leaves, and closing pauses when the player occupies the moving area.

The atrium side-landing gap is filled with visible, solid tile geometry. Its landing and front threshold share a 1.814 m level and a world-aligned 60 cm tile pattern. Original lower-hall stairs remain open and walkable. Overlapping plaza step sections have been trimmed out of reception, retaining the original plaza stairs outside the reception frontage.

The cream entrance has three regular steps, an aligned tiled approach, a continuous landing and a threshold flush with the original 0.52 m floor. The original interior plinth now has matching triangle collision across its full visible footprint. Canopy underside slats and restrained recessed light strips refine the existing canopy; the facade, upper floors, windows, pillars, fence and trees keep their source dimensions and positions.

## Visual pass

The exploration interface uses a compact translucent case card, segmented progress, small key hints and a full response plan available on J. The pause and destination screens use a restrained charcoal and teal palette; the workstation has its own dark desktop, blue folder accents and monospace terminal. Computer cues are attached to the actual imported screen.

Shared real-time surface finishes cover the campus: honed stone and terrazzo, limestone, slate, subtle wood grain, fabric, carpet, paving and planting. Materials preserve modeled joints and the selected props' authored texture maps. Daylight, interior fill and small workstation lights are balanced across the plaza, reception, auditorium and glazed building. Existing garden-tree crowns have smoother silhouettes and keep their original bounds and bark. Conservative occlusion of verified solid walls/floors reduces work on hidden geometry without closing doorways or windows. The source Blender and downloaded GLBs remain unchanged. The supplied computer has a runtime-only darker teal case/LED palette and the training display.

## First mission

The scenario is fictional. The student recognises the incident, preserves evidence, isolates an affected workstation, revokes a stolen session, restores from a verified clean source, checks recovery, and submits a report. Incorrect ordering gives an explanation. Completing the seven actions earns up to 100 points.

The terminal's files and command results are authored training data. Commands stay inside the game and use the scenario's fictional hostnames, logs and documentation IP addresses. Progress lasts for the current session; reopening the game starts a fresh exercise. The `reset` command asks before restarting the local exercise.

## Asset approval

The five models selected and supplied by the user in `../3D-modeling/3d models` have been integrated: the computer set, office desk, office chair, and both server racks. Their copied GLBs are in `assets/user_models`. The original downloads and Blender campus source remain unchanged. Scale, placement, collisions and interaction targets are set up in the game. The imported chairs replace the two earlier reception-chair placeholders in the game view; the Blender model retains its original contents. Credits are in [CREDITS.md](CREDITS.md), with provenance and approval in `ASSET-APPROVALS.md`. Any additional external assets still require user approval before download/import.

## Current scope and limits

This is a playable foundation with one teaching mission. The campus remains a simplified photo-based model with estimated proportions. Surface finishes are adapted for real-time rendering; the user-supplied props retain their source texture maps, with the computer palette/display changes listed above. Some decorative objects do not block movement. Four entrances are animated; other source doors remain static or passable. The desktop exposes the commands listed in `help` and `ir help`, and its case files are virtual training documents. Progress is session-only. Initial loading and shader compilation are slower than warmed-up play. The game targets 1280×720 with the Compatibility renderer and 2× MSAA; performance varies by device and camera view.

## Project structure

- `project.godot`, `main.tscn` — engine project and starting scene.
- `scripts/main.gd` — movement, campus destinations, response PCs and scene lighting.
- `scripts/campus_runtime.gd` — static collision and rendering batches.
- `scripts/training_ui.gd` — mission state, exploration HUD, evidence, report, scoring and debrief.
- `scripts/workstation_desktop.gd`, `scripts/desktop_window.gd`, `scripts/workstation_shell.gd` — native workstation windows and virtual filesystem/commands.
- `scripts/pause_menu.gd`, `shaders/pause_backdrop.gdshader` — full-screen start, pause and campus guide.
- `scripts/interactive_door.gd`, `scripts/sliding_door.gd`, `scripts/campus_doors.gd`, `scripts/entrance_geometry.gd`, `scripts/atrium_entrance_repair.gd` — moving door leaves and bounded entrance/floor repairs.
- `scripts/interaction_target.gd`, `scripts/interaction_focus.gd` — crosshair targeting and contextual computer cues.
- `scripts/campus_materials.gd` — shared campus surface finishes.
- `scripts/campus_occlusion.gd`, `scripts/canopy_detail.gd` — conservative hidden-geometry culling and garden-tree crown refinement.
- `design/incident.json` — editable case data and command responses.
- `design/GAMEPLAY.md` — teaching sequence and future expansion.
- `assets/campus.glb` — optimized export of the existing campus.
- `assets/asset-manifest.json`, `assets/validation.json` — asset provenance and checks.
- `assets/ui/icons/LICENSE.txt` — Tabler icon licence.
- `tools/*-preview.png` — actual game captures.

The headless smoke test is available with the console build of Godot: `--headless --path . -- --smoke-test`. It checks mission completion, grounding at all six destinations, movement and auditorium aisle traversal. The approved-asset integration test at `tools/computer_integration_test.gd` verifies all five station interactions, line of sight, range and standing clearance. `tools/hover_target_test.gd` checks precise PC hover, look-away, range, obstruction, modal visibility and unchanged mission state. The training-only test is `--headless --path . --script res://tests/training_state_test.gd`.

Standalone checks are also available in `tools/workstation_shell_test.gd`, `tools/workstation_desktop_test.gd`, `tools/pause_menu_test.gd` and `tools/entrance_geometry_test.gd`. Run each with `--headless --path . --script res://tools/<test-name>.gd`. Desktop captures and their visual review are in `tools/workstation_desktop_design-qa.md`. The geometry test checks the actual source meshes, continuous floor probes and a standing-player walk from the sidewalk five metres into the cream building. `tools/door_physics_test.gd` exercises the hinged leaves and collisions; `tools/game_ui_integration_test.gd` checks the main scene's menu/workstation flow. Focused checks and combined integration results are kept separately in their test outputs.

Engine documentation: [Godot 3D asset import](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [Godot renderer choices](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html). Godot is distributed under the MIT licence: [engine licence](https://godotengine.org/license/).


## Collaboration with Antigravity

The optional environment polish is enabled. See [integration verification and rollback](docs/POLISH-INTEGRATION.md); pass `-- --no-polish` for baseline comparison. ENSA Games launcher briefs: [Codex core/loading](docs/CODEX-ENSA-GAMES-LAUNCHER.md) and [Antigravity presentation](docs/ANTIGRAVITY-ENSA-GAMES-LAUNCHER.md).

The complete environment-polish brief is in [docs/ANTIGRAVITY-PROMPT.md](docs/ANTIGRAVITY-PROMPT.md), with shared-file boundaries in [docs/COLLABORATION.md](docs/COLLABORATION.md). Antigravity owns its isolated visual-polish module/resources and QA folders. Codex retains core gameplay/UI/physics and production integration; proposed shared-file edits go through the handoff document. Original user reference images are retained in `docs/references`.
