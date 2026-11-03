# Project: ENSA Fez Campus Environment Visual Polish & Performance QA

## Architecture
- **Engine & Renderer**: Godot 4.3 (GL Compatibility renderer, GDScript), viewport 1280x720, 2x MSAA.
- **Module Isolation Boundary**: All polish logic is contained strictly in `res://scripts/antigravity/environment_polish.gd` with auxiliary assets in `assets/antigravity/` and preview/test harnesses in `tools/antigravity/`.
- **Protected Files**: `main.tscn`, `project.godot`, `PLAY.cmd`, `EDIT.cmd`, `scripts/main.gd`, `scripts/campus_runtime.gd`, `campus_materials.gd`, `campus_occlusion.gd`, `canopy_detail.gd`, `entrance_geometry.gd`, interactive door scripts, workstation/UI scripts, existing shaders, and test scenes remain completely untouched.
- **Hook & Integration Contract**: `environment_polish.gd` exposes an idempotent `func install(game: Node3D) -> Dictionary` (and reversible `uninstall() -> Dictionary`). It attaches after `game.ready_to_play == true` when `CampusRuntime.build()` has completed mesh batching, occlusion, and prop instantiation.
- **Rendering & Material Strategy**: Uses non-destructive `material_override` and surface overrides on allowlisted nodes and `CampusRenderBatches` (MultiMeshInstance3Ds and merged static surface meshes), duplicating materials at runtime to preserve authored maps, collision, and occlusion.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Visual Audit & Defect Documentation | Prioritized visual audit report across 7 campus areas and documentation of any authentic geometry defects with screenshots. | M1 | Survey / R5 |
| F2 | Isolated Polish Module Architecture | Resilient Node3D script at `res://scripts/antigravity/environment_polish.gd` with idempotent `install(game)` and reversible `uninstall()`. | M1 | Survey / R2 |
| F3 | Preview Harness & Baseline Captures | Dedicated standalone SceneTree harness in `tools/antigravity/` to record baseline captures at 1280x720 across 7 areas. | M1 | Survey / R5 |
| F4 | Lighting & Shadow Realism Tuning | Fine-tune directional light normal bias (~0.8), split blends, and ambient intensity to ground floating furniture and eliminate stairstepped acne without extra shadow passes. | M2 | Survey / R1, R4 |
| F5 | Acoustic Ceiling Moiré Elimination | Soften albedo contrast between acoustic tile surface and reveal joints in auditorium ceiling without altering geometry. | M2 | Survey / R1 |
| F6 | Glazed Atrium Reflection & Glare Calibration | Reduce ambient wash and tune glass material alpha/roughness to eliminate milky haze and preserve framing. | M2 | Survey / R1, R4 |
| F7 | Furniture Grounding & Workstation Polish | Ensure contact grounding for desks, chairs, server racks in Reception and Security areas while preserving unshaded PC display shaders. | M2 | Survey / R1, R3 |
| F8 | Cream Main Entrance Canopy & Signage Polish | Add warm canopy downlight, "ENSA FÈS" entrance signage, and polished interior marble reflection while preserving working doors and steps. | M2 | Survey / R1, R3 |
| F9 | Performance Benchmarking & QA Verification | Measure warmed play (20 frames warmup, 30 frames timed) at 1280x720 2x MSAA, ensuring ~30 FPS envelope without regressions. | M3 | Survey / R4, R5 |
| F10 | After-Polish Game Captures | Capture native 1280x720 screenshots across all 7 locations (+ 3 angles for Cream entrance) under identical transforms. | M3 | Survey / R5 |
| F11 | Integration & Handover Deliverables | Author `antigravity/INTEGRATION.md`, `antigravity/CHANGELOG.md`, `antigravity/STATUS.md`, and `antigravity/VISUAL-AUDIT.md`. | M3 | Survey / R5 |
| F12 | E2E Test Suite Validation & Adversarial Hardening | Comprehensive 4-Tier test suite execution (Tiers 1-4) plus Tier 5 adversarial coverage hardening. | M4 | Dual Track / E2E |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Architecture & Test Harness | F1, F2, F3: Module skeleton, standalone preview harness, baseline 1280x720 captures, visual audit draft. | none | DONE |
| M2 | Visual Polish Implementation Across 7 Areas | F4, F5, F6, F7, F8: Full material overrides, lighting tuning, moiré fix, atrium glass calibration, cream canopy & signage. | M1 | DONE |
| M3 | Performance QA, Native Captures & Handover Docs | F9, F10, F11: Warmed performance benchmark, after-captures, final INTEGRATION.md, CHANGELOG.md, STATUS.md. | M2 | DONE |
| M4 | Final Milestone: 100% E2E Pass & Hardening | F12: Pass 100% of E2E test suite (Tiers 1-4) + Tier 5 adversarial hardening. | M3, TEST_READY.md | DONE |

## Interface Contracts
### `environment_polish.gd` ↔ Game Lifecycle
- Entry Point: `func install(game: Node3D) -> Dictionary`
  - Input: `game` (instance of `res://main.tscn` / `ENSAIncidentResponse`) with `ready_to_play == true`.
  - Output: `Dictionary` with keys:
    - `"installed"`: `bool`
    - `"changes"`: `Array[String]`
    - `"resource_counts"`: `Dictionary` (materials duplicated, lights added/tuned, meshes overridden)
    - `"affected_areas"`: `Array[String]` (all 7 campus areas)
    - `"measured_costs"`: `Dictionary` (approx memory, draw call delta)
- Exit Point: `func uninstall() -> Dictionary`
  - Reverts all material overrides, restores original light parameters, removes injected polish nodes.
  - Returns confirmation `Dictionary`.

### Preview & Test Harness ↔ Game Scene
- Invocation: `& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --headless -s tools/antigravity/preview_harness.gd`
- Behavior: Standalone SceneTree that instantiates `main.tscn`, waits for `game.ready_to_play`, positions camera sequentially across the 7 locations (and 3 cream entrance angles), warms frames, invokes `RenderingServer.force_draw(false)`, saves PNGs, runs benchmarks, and exits with code 0.

## Code Layout
- Allowed Polish Scripts: `res://scripts/antigravity/environment_polish.gd`
- Allowed Polish Assets: `res://assets/antigravity/*`
- Allowed Polish Tools/Harnesses: `res://tools/antigravity/*`
- Allowed Documentation Deliverables:
  - `antigravity/VISUAL-AUDIT.md`
  - `antigravity/INTEGRATION.md`
  - `antigravity/CHANGELOG.md`
  - `antigravity/STATUS.md`
- Agent Metadata (strictly coordination, no source code): `.agents/teamwork/*`
