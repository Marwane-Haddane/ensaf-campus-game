# Milestone 8: After Hours deep-dusk mood

Date: 2026-11-19 · Skills: `apocalypse-worlds` → `dark-gritty-mood` → `set-dressing` → `prop-artist` → `lighting`

Decisions (user): **deep dusk** (not full night), applied on **all presets**. Low gets fewer lights, particles and props.

## Lighting (`scripts/antigravity/zombie/zombie_game.gd`, `_setup_environment`)

| | Before | After |
| --- | --- | --- |
| Sun | 24° up, pale warm, 1.0 energy | 11° up, orange (1.0, 0.64, 0.44), 0.7 energy, so shadows run long |
| Sky | twilight blue, grey horizon | near-black zenith, smoky orange horizon band |
| Ambient | 0.75, neutral blue | 0.62, cooler blue, so warm light and cool shadows contrast |
| Fog | none | blue-grey haze (density 0.011) |

Before, the plaza read as noon light under a dark sky. It now reads as the last light of the day, and enemies stay visible.

## Dressing (`tools/after_hours_kit.py`, run in Blender 4.3 → `assets/antigravity/zombie/after_hours/`)

| Mesh | Tris |
| --- | ---: |
| SM_AH_BurntCar (resting on rims, charred cabin) | 284 |
| SM_AH_JerseyBarrier | 28 |
| SM_AH_PlankBarricade | 108 |
| SM_AH_RubblePile (concrete chunks + rebar) | 256 |

- **Textures:** concrete, burnt metal and wood (albedo + normal), two crate textures and a scorch decal. All are 512 px and procedural.
- **Placement:** `scripts/antigravity/zombie/after_hours_mood.gd` places the props at the plaza edges, away from enemy patrols and pickups. The car, barriers and barricades get box collision; the rubble has none.
- **Effects:**
  - a burning barrel next to the existing barrel prop
  - a smouldering burnt car with a smoke column and scorch marks
  - amber warning beacons at the extraction barriers
  - red alarm pulses at the reception and glazed entrances
- **Animated lights:** `mood_light.gd` drives them. Reduced motion holds a steady glow.
- **Crates:** loot crates were flat dark metal boxes. The weapons case now uses painted military steel and supply crates use weathered planks (`loot_chest.gd`).

| Preset | Props | Lights | Particle systems |
| --- | ---: | ---: | ---: |
| Low | 5 | 3 | 3 |
| Medium / High | 9 | 6 | 4 |

All lights run without shadows.

## QA

- **Captures:** `tools/after_hours_capture.gd` takes 5 fixed views per preset (`09_after_hours_{low,medium,high}`). The before shots are in `art_audit/before/after_hours_08/`.
- **Frame snapshot (capture machine):** Medium went from 872 to 902 draw calls. Low runs at 793 draws and 39 FPS.
- **Zombie tests:** `test_systems` (99/109), `test_playthrough` and `placement_test` give identical results with and without these changes. Their failures already existed (mission-step advancement checks).

## Known limits

- The flames are additive billboard particles. Up close they read as bright blobs rather than detailed fire.
- The baked navmesh was not rebuilt. Enemies chasing the player can brush against the car and barriers, which sit at the plaza edges.
