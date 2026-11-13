# Antigravity — build the first playable ENSA Zombie RPG mode

**This is an implementation assignment, not a verification-only task.** Build a substantial playable game mode using the user's supplied models and the existing campus. Deliver working scenes, gameplay systems, animation integration, objectives, inventory, saves, HUD and a standalone playable entry. Tests support the implementation; they are not the main deliverable.

## 1. Product goal

Create a polished, offline Windows first-person survival/RPG episode inside the ENSA campus: **Zombie RPG — After Hours**.

First episode:

- Mission ID: **ZB-2026-001**.
- Title: **After Hours**.
- Main objective: **Restore power and reach extraction**.
- A complete session should take roughly **6–10 minutes**, depending on the player.
- Loop: explore the campus, find supplies, fight animated zombies, collect two power components, restore power, help a survivor and reach an extraction point.
- Include a clear beginning, progressing objectives, meaningful resource decisions, win state, death state, retry and checkpoint restoration.
- Preserve the recognizable ENSA buildings and layout. Use existing assets instead of rebuilding the campus or every prop from scratch.

The cybersecurity game remains its own educational mode. Never mix zombie enemies, damage, weapons or RPG save data into ENSA Incident Response.

## 2. Project, engine and ownership

Working directory:

```text
C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game
```

Engine:

```text
C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe
```

Use **Godot 4.3, GDScript, GL Compatibility**. The target is the existing Windows PC / Intel Iris Plus class hardware. Do not change engines or switch the whole project to Forward+.

### Your writable areas

```text
scenes/antigravity/zombie/
scripts/antigravity/zombie/
assets/antigravity/zombie/
shaders/antigravity/zombie/
design/antigravity/zombie/
tools/antigravity/zombie/
antigravity/zombie/
```

You own the complete new mode inside these folders. Create real gameplay code and scenes there.

### Read-only shared areas

- `scripts/launcher/`, `scenes/launcher/`, `project.godot`, PLAY.cmd.
- Existing cybersecurity player, training UI, workstation/shell, mission/report, doors and collision scripts.
- Original campus/approved models and `assets/runtime_campus/`, `assets/runtime_surfaces/`.
- Existing Antigravity launcher presentation and Codex's current reference-home calibration adapter.

Codex owns shared launcher/core integration, mode registration and final cross-mode regression. Put proposed shared changes in `antigravity/zombie/INTEGRATION.md`; do not apply them yourself. Do not reopen the completed launcher redesign as a substitute for building this mode.

## 3. Supplied assets — actual inspected capabilities

Source folder, outside the game:

```text
C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\3D-modeling\3d models\zombie
```

Read `design/future_zombie_assets.json` for hashes, sizes, embedded metadata and the initial inventory. Original files stay unchanged.

### Prefer these for the first playable episode

**Zombie Apocalypse Kit archive**:

```text
Zombie Apocalypse Kit - March 2024-20261102T030551Z-1-001.zip
```

The archive contains native glTF models with relative dependencies. Prefer those over FBX to avoid introducing an FBX conversion dependency.

Already inspected:

- `Characters/glTF/Zombie_Basic.gltf`: one skin, **16 animations**.
- `Characters/glTF/Zombie_Chubby.gltf`: one skin, **16 animations**.
- `Characters/glTF/Characters_Shaun.gltf`: one skin, **20 animations**.

Zombie_Basic animation names:

```text
Crawl, Death, HitReact, Idle, Idle_Attack, Jump, Jump_Idle, Jump_Land,
No, Punch, Run, Run_Arms, Run_Attack, Walk, Wave, Yes
```

Characters_Shaun animation names:

```text
Death, Duck, HitReact, Idle, Idle_Gun, Jump, Jump_Idle, Jump_Land,
No, Punch, Run, Run_Gun, Run_Slash, Run_Stab, Slash, Stab,
Walk, Walk_Gun, Wave, Yes
```

The included License.txt says **CC0 1.0**, credits **@Quaternius**, and has a header mentioning Ultimate Platformer Pack. Preserve that exact supplied licence/provenance rather than inventing a different author or rewriting it. Record the folder/header discrepancy factually in the asset manifest if relevant.

**Pistol with first-person hands** — about 5.8 MB, one skin, 10 animations:

```text
pistol_animation_wip__really_stiff.glb

Armature|A_Draw
Armature|A_Origin
Armature|A_Aim
Armature|A_AimBack
Armature|A_Fire
Armature|A_FireLast
Armature|A_ReloadStart
Armature|A_Reloading
Armature|A_ReloadEnd
Armature|A_Holster
```

Use this as the baseline weapon and integrate its real draw/aim/fire/reload/holster clips. Adjust playback/blending thoughtfully rather than showing a static gun.

**Scorpion first-person weapon** — about **141 MB**, one skin, 9 animations:

```text
scorpion__first_person_animations_2026_remake.glb

rig|Equip, rig|Idle, rig|Walk, rig|Run, rig|Fire,
rig|Reload, rig|Reload_Empty, rig|Inspect, rig|Unequip
```

Use as a second weapon/unlock if it meets the performance/memory budget. Optimize a derived copy where justified; do not load 141 MB merely to show a menu card. The baseline episode must work even if the optional heavy weapon is disabled by a low preset.

### These are not ready-made animated actors

- `free_benelli_m4_shotgun_gameready_rigged.glb`: one skin, **no animation clips**.
- `low_poly_female_warrior_charctor.glb`: **no skin and no animation clips**.
- `low_poly_lion_with_wings_warrior_character_model.glb`: **no skin and no animation clips**.

Do not treat those as fully animated characters or ship sliding T-poses. The provided animated kit is the foundation. A properly animated use of the other models is a later bonus after the main playable loop works; do not let rigging the lion consume the whole assignment. A brute enemy using the kit's animated Chubby model is a suitable first-episode boss variant.

### Import policy

- You may copy/import the user's supplied assets into your own namespace; this is authorized.
- Extract only needed archive files and their dependencies into your namespace, retaining glTF `.bin`/textures/relative paths. Check resolved extraction paths stay inside the destination; never trust `..` archive paths.
- Preserve source originals and licence text. Maintain an asset manifest mapping derived assets to their source files/archive entries and modifications.
- Do not download/import new external 3D models without user approval. Do not replace missing animations with unrelated downloaded assets silently.
- Convert/optimize derived copies offline where needed, preserving texture/rig/clip attribution and documenting differences.

## 4. Deliver a real playable episode

Implement the following systems together. A model gallery, decorative HUD, shooting-only empty arena or a prototype with no end condition does not satisfy this task.

### A. Independent mode scene and first-person controller

- New root scene: `res://scenes/antigravity/zombie/zombie_game.tscn`.
- Independent mode state; no dependency on cybersecurity `main.tscn` or its TrainingUI.
- First-person movement, mouse look, run, jump, gravity, capsule collision, sensible step handling and safe spawn.
- Apply shared sensitivity, movement bindings, graphics/accessibility preferences and audio buses. Mode-specific controls/settings live in the zombie namespace.
- Default extra controls: left click fire, right click aim, R reload, 1/2 switch weapon, E interact, I inventory, Tab objective journal, Esc pause. Resolve action naming/context rather than hijacking the cybersecurity input handler.
- No movement or shooting while inventory, journal, dialogue or pause UI owns input.
- Correct near-plane/viewmodel placement, stable FOV, restrained recoil and camera motion. Reduced motion disables decorative bob/shake while essential combat cues remain readable.

### B. Campus environment and playable route

- Reuse the existing campus source/runtime sections read-only. Do not instantiate the cybersecurity main scene just to obtain its buildings.
- Use a bounded first-episode route: courtyard, supply location, power location, survivor location and extraction. Place them in actual reachable campus spaces.
- Preserve building dimensions and existing geometry. Add selected kit props such as crates, barriers and a vehicle to dress the route within your mode instance only.
- Dusk atmosphere with readable interiors/exits. Use Compatibility-supported lighting and restrained shadows, not unsupported volumetric effects or expensive per-enemy lights.
- Keep floor, landing, stair and doorway collision walkable. Do not solve traversal by invisible bridges across holes or moving the real buildings.
- Support existing doors through the shared door helper where useful, without editing its source or letting NPCs pass through closed leaves.

### C. Animated enemies and AI

At least two distinct animated enemy types:

1. Walker using Zombie_Basic: readable patrol/idle, detection, chase, attack, hit reaction and death.
2. Brute using Zombie_Chubby: slower/heavier, more health, clear attack windup and a distinguishable silhouette/behavior. It may serve as the final encounter.

Required AI behavior:

- State machine: idle/patrol → investigate/detect → chase → attack → hit/death, with sensible recovery/lost-target behavior.
- Distance + line-of-sight detection. Enemies cannot see through walls, hit through walls or apply damage before their attack contact window.
- Navigation around buildings/barriers/stairs. Use pre-baked or incrementally prepared navigation for the bounded route, filtering out decorative geometry. Never synchronously bake the entire dense campus on every launch.
- Smooth capsule movement with animations matched to speed; no doubled root motion, skating, permanent T-pose or uncontrolled overlap piles.
- Reasonable avoidance/collision, stuck recovery and valid spawn checks. No spawning inside the player, walls, stairs or unsupported ground.
- Reusable enemy configuration and spawn-point data. Initial cap around 8 active enemies plus one brute is a starting budget; tune from actual measurement.
- Bounded corpse/FX cleanup and distant AI/animation update budgets. No unbounded spawn/corpse accumulation.

### D. Functional weapons and combat

- Real hitscan/raycast shooting against world/enemy collision with damage, ammo, reload and weapon switching.
- Pistol first, optional Scorpion second. Use the supplied hands and authored animation clips through AnimationPlayer/AnimationTree as appropriate.
- Hits must respect walls and muzzle obstruction. Aim/camera and muzzle traces must not let a gun shoot through a nearby wall.
- Muzzle flash, impact feedback, subtle recoil, readable hit confirmation and appropriate damage feedback. Keep effects bounded.
- Aim/draw/fire/reload states must not overlap incorrectly. Cancel/switch/reload/death/pause cannot duplicate ammo, get stuck or keep firing in menus.
- Distinguish magazine from reserve ammo. Handle empty fire and empty reload correctly. Define values in data, not scattered constants.
- Enemy damage/kill credit occurs once; death does not continue attacking. Survivor NPC is not treated as an enemy target.

### E. Survival, inventory and modest RPG progression

- Player health and stamina, damage/recovery, run expenditure and clear death handling.
- Pickups: ammo, medkit, scrap and the two mission power components. E prompts appear only when actually targeting a nearby usable item.
- Small functional inventory with quantities, weapon slots and medkit use; no generic fake inventory grid.
- One meaningful upgrade choice, such as increased health versus improved magazine capacity, paid with collected scrap. Persist it and reflect its actual effect.
- Simple XP/kill/progression tracking with idempotent rewards. No need for a huge skill tree, crafting economy or loot rarity system in this first episode.
- Clear feedback when a pickup cannot be collected or an action lacks resources.

### F. Authored objective chain and survivor interaction

Implement a complete sequence with clear triggers and persistent state:

1. Establish the initial objective and learn movement/interaction.
2. Find supplies and the first power component.
3. Reach a second supply location and obtain the other component.
4. Restore power at a reachable physical interaction point.
5. Help a survivor using an animated kit character, with short authored text interaction and a reachable escort/meet-up route.
6. Survive the final brute encounter or pressure event and reach extraction.
7. Show a victory/debrief screen with real time, kills, resources/upgrade and completed objectives; offer replay and return to launcher.

Use mode-owned data files for mission steps, dialogue, pickup placements, enemy configuration and encounter tuning. Objectives advance from actual events, not timers pretending the player completed them. Repeated interactions/reloads cannot duplicate quest rewards or skip prerequisites.

### G. Professional mode HUD, pause and menus

- Visually related to ENSA Games but clearly a survival mode: restrained navy/graphite with warm/amber accents, readable off-white typography.
- Small health/stamina, ammo/weapon status, objective and context interaction prompt. Calm spacing and clear hierarchy; avoid covering the campus with dashboard panels.
- Inventory, journal, brief interaction/dialogue, pause, death and victory screens are real native UI with keyboard/mouse focus and Back/Esc behavior.
- Pause freezes AI, attacks, damage and input consistently. Resume restores the same situation.
- Use shared Master/Music/SFX buses. Add supplied/licensed or original SFX if needed; do not claim music/voice acting exists when it does not. Record provenance.
- UI scales to 1280×720 and 1920×1080 and respects reduced motion. No fake multiplayer/profile/online features.

### H. Independent checkpoint/save system

- Store under `user://ensagames/saves/zombie_rpg/`, with its own schema/version. Never write the incident-response checkpoint.
- Save mission flags, player health/resources/upgrade, inventory/ammo, safe pose, relevant pickup/encounter state and checkpoint identity.
- Restore a consistent playable state: no duplicated pickups/rewards, dead enemies dealing damage, invalid ammo or player inside geometry.
- Validate malformed/missing/incompatible files. Safe fallback to a new mission or last valid checkpoint, with readable feedback.
- Use recoverable writes. Save at meaningful checkpoints and on authorized exit, without stalling every frame.
- Death supports retry from checkpoint and new mission. Victory supports replay without contaminating the previous save.

## 5. Shared launcher integration contract

Read the working `scripts/launcher/incident_mode_adapter.gd` and `docs/ENSA-GAMES-ARCHITECTURE.md`. They are examples of the current loader interface, not files for you to edit.

Create:

```text
scripts/antigravity/zombie/zombie_mode_adapter.gd
```

The adapter is a lightweight RefCounted object and exposes:

```text
required_resources() -> Array[String]
entry_scene() -> String
create_session(resources, preferences) -> Node3D
initialization_finished(game) -> bool
validate_ready(game) -> bool
error_detail(game) -> String
cancel(game)
freeze(game)
start(game)
set_input(game, enabled)
connect_events(game, on_return, on_settings, on_progress)
apply_preferences(game, preferences)
capture(game) -> Dictionary
restore(game, checkpoint) -> bool
is_ready(game) -> bool
save_service() -> RefCounted
```

Optional `validate_spawn(game) -> bool` should verify safe ground/capsule clearance after physics initialization.

Session root emits:

```gdscript
signal initialization_progress(label: String, stage: String, completed: Variant, total: Variant)
```

Your save service provides `read_save()`, `write_save(payload)`, `summary(payload)`, `last_error`, and a mode-specific path/schema. Common checkpoint headers identify `mode_id: zombie_rpg` and `mission_id: ZB-2026-001`; gameplay payload remains yours.

Rules:

- Adapter constructors must not preload the campus or 141 MB weapon. Return string resource paths and let the shared loader load them only after mode/mission selection.
- `create_session` receives already loaded resources. Avoid re-requesting the same large assets synchronously.
- `freeze` means ready but not playable yet: no movement, shooting, AI damage or cursor capture behind the launcher Ready screen.
- `start` intentionally enables gameplay. `set_input(false)` must actually suspend input for shared settings/menu ownership.
- Readiness must represent real geometry, physics, player, assets, nav/AI and objective state, not a timer or successful file read.
- Cancellation must stop further mode construction at safe boundaries. Report real progress/counters and genuine errors.
- Cancellation must eventually make `initialization_finished(game)` true with a cancelled/error result so the shared loader can drain ownership; never leave a construction coroutine waiting forever. Hide your mode-owned HUD when frozen/cancelled and release all input ownership.
- Do not assume the shared loader requires a TrainingUI or cybersecurity station count in your mode. If shared code still contains a cybersecurity-specific assumption, report its exact location for Codex to generalize; do not imitate those objects to pass a check.

Deliver a proposed registry descriptor in `antigravity/zombie/MODE-REGISTRATION.json`, including scene/adapter paths, mode/mission IDs, save/settings namespaces, artwork and mission briefing/controls. **Do not change design/extra_modes.json or flip the production Zombie card to available yourself.** Codex owns final registry/launcher wiring after your module is concrete and reviewable.

## 6. Performance and implementation constraints

- Keep large loading off the initial launcher path. No eagerly instantiated second campus or hidden full zombie world in the menu.
- Reuse shared runtime sections/surface resources and existing helpers read-only. If you need a mode-specific environmental wrapper, make it in your namespace.
- Do not run a blocking whole-campus nav bake during startup. Precompute the bounded playable route or build it incrementally with real stages.
- Prefer pooled/instanced props and bounded enemies/FX. No unlimited physics ragdolls or dozens of shadow-casting enemy lights.
- Budget AI/path queries; keep movement smooth without querying every distant enemy's full perception every frame.
- Optimize the optional heavy gun in a derived asset or exclude it from the low preset. Do not silently degrade the user's originals.
- Record real hardware/view-dependent FPS/frame times, memory, active enemy count and load stages. Never claim universal 60/30 FPS or zero overhead from a fixture run.
- Do not terminate the user's/Codex's processes or run simultaneous GPU benchmarks. Coordinate through status files.

## 7. Standalone playable delivery — do not wait for launcher wiring

Provide a dedicated standalone entry and launch harness in your namespace that lets the user play the new episode before Codex registers it in the shared launcher. It must use the same mode scene/adapter and actual gameplay systems, not a separate fake demo.

Suggested deliverables:

```text
scenes/antigravity/zombie/zombie_game.tscn
scripts/antigravity/zombie/zombie_mode_adapter.gd
scripts/antigravity/zombie/player_controller.gd
scripts/antigravity/zombie/weapon_controller.gd
scripts/antigravity/zombie/enemy_controller.gd
scripts/antigravity/zombie/mission_state.gd
scripts/antigravity/zombie/inventory.gd
scripts/antigravity/zombie/save_store.gd
scripts/antigravity/zombie/zombie_hud.gd
design/antigravity/zombie/episode_01.json
design/antigravity/zombie/weapons.json
design/antigravity/zombie/enemies.json
tools/antigravity/zombie/play_mode.gd
```

You may choose a cleaner internal structure, but the scope must remain playable and modular. Document the actual launch command only once its target exists.

## 8. Build milestones — implementation first

### Milestone 1: playable movement/combat foundation

Import selected animated assets, load the existing campus route, provide first-person movement, one animated weapon and one animated enemy that detects/chases/attacks/dies. Deliver a real standalone playable scene.

### Milestone 2: complete episode loop

Add second enemy type, pickups/inventory, health/stamina, power-component objectives, survivor interaction, final encounter, extraction, death/retry and victory. This is the main deliverable, not optional polish.

### Milestone 3: persistence and presentation

Implement checkpoints/restoration, upgrade choice, complete HUD/menus, sound feedback, animation blending, mode adapter and proposed registration metadata.

### Milestone 4: playable polish and integration handoff

Fix actual collision/navigation/combat/animation issues, tune the episode with real playthroughs, verify performance and save/reload, then hand the module to Codex for shared launcher integration. Optional second weapon or extra model use comes after the episode works.

## 9. Verification supporting the build

Required evidence concerns real play, not only synthetic assertions:

- Full beginning-to-extraction playthrough and a death/checkpoint retry.
- Movement over the route's stairs/landings, doors and obstacles with no falling through/stuck capsules.
- Enemies navigate around obstacles, obey line of sight, animate correctly, and apply attack damage only in range/contact windows.
- Shooting/reload/aim/switch behavior and ammo correctness, including menus, pause and death during animation transitions.
- Inventory/pickup/upgrade/quest rewards are idempotent and persist correctly.
- Save/exit/restart/resume restores the real episode state; corrupt-save recovery remains playable.
- Native HUD/menus at 720p/1080p, keyboard/mouse focus and reduced-motion behavior.
- Low-preset test with bounded enemy counts; report actual performance and limits.
- Existing cybersecurity files are unchanged and no zombie data/assets are loaded by the launcher home.

Write meaningful targeted tests for those systems, but do not spend the assignment producing only reports or mocks.

## 10. Handoff and done criteria

Keep these current:

- `antigravity/zombie/STATUS.md`: implemented systems, playable command, next milestone and genuine blockers.
- `antigravity/zombie/INTEGRATION.md`: actual adapter API, scene paths, dependencies, loading stages, input/bus requirements, save schema, proposed shared changes and rollback.
- `antigravity/zombie/ASSETS.md`: source/archive paths, licences, animation mappings and derived optimizations.
- `antigravity/zombie/MODE-REGISTRATION.json`: proposed registration, not a direct production edit.
- Native screenshots and optional short gameplay capture showing actual combat/objectives/HUD; do not present generated concept art as proof of gameplay.

Done means the user can launch your standalone mode and complete a real survival episode with animation, combat, enemy AI, resources, objectives, checkpoint retry and extraction. Codex can then connect it to ENSA Games without rewriting the launcher or breaking the cybersecurity mode.

Work autonomously through ordinary implementation decisions inside your boundary. Ask through the handoff only for genuine missing information/shared-file changes or approval of new external 3D assets. Do not stop at a plan, a model showcase or a test checklist.
