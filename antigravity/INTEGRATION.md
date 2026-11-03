# Integration Specification & API Guide: Antigravity Visual Polish Module

**Project**: ENSA Fez Incident Response Training Game (`campus-game`)  
**Engine & Renderer**: Godot 4.3 (GL Compatibility renderer, GDScript)  
**Target Hardware Profile**: 1280x720, 2x MSAA, Intel Iris Plus Graphics (Target ~30 FPS envelope)  
**Module Script**: `res://scripts/antigravity/environment_polish.gd`  
**Namespace Discipline**: All polish assets, tools, and docs are strictly isolated in `res://scripts/antigravity/`, `res://assets/antigravity/`, `res://tools/antigravity/`, and `antigravity/`. Protected core production files remain completely untouched.

---

## 1. Architecture & Lifecycle Overview

The Antigravity Visual Polish module provides non-destructive, isolated runtime visual improvements across all seven key areas of the ENSA Fez campus in Morocco.

### Core Architecture Principles
1. **Zero Core File Mutation**: No production files (`main.tscn`, `project.godot`, `PLAY.cmd`, `EDIT.cmd`, `scripts/main.gd`, `scripts/campus_runtime.gd`, `campus_materials.gd`, `campus_occlusion.gd`, `canopy_detail.gd`, `entrance_geometry.gd`, interactive door scripts, workstation/UI scripts, existing shaders, missions, or existing tests) are modified.
2. **Lifecycle Precondition**: The module attaches after `CampusRuntime.build()` has completed mesh batching, occlusion culling, and approved prop instancing, specifically when `game.ready_to_play == true`.
3. **Non-Destructive Overrides**: Meshes, MultiMesh batches, and merged static surface batches receive non-destructive runtime `material_override` and surface overrides using duplicated `StandardMaterial3D` instances. Authored textures, vertex colors, and normal maps are preserved.
4. **Idempotency & Reversibility**: Installation can be invoked repeatedly without leaking resources or accumulating duplicate nodes. Calling `uninstall()` completely reverts all materials, restores original lighting and environment parameters, and removes injected nodes.
5. **Interactive Workstation Screen Preservation**: Terminal screens, unshaded display materials, and viewport textures are strictly protected by guardrails and remain 100% untouched.

---

## 2. Exact API Specification

The module is implemented as a `Node3D` class located at `res://scripts/antigravity/environment_polish.gd`.

### 2.1 `install(game: Node3D) -> Dictionary`

Installs visual polish across the entire campus scene tree.

#### Parameters
- `game`: The root `Node3D` instance of `res://main.tscn` (`ENSAIncidentResponse`). Must satisfy `is_instance_valid(game)` and have property `game.ready_to_play == true`.

#### Return Value
Returns a comprehensive telemetry `Dictionary` with the following structure:

```gdscript
{
    "installed": bool,                   # True if installation succeeded or is already active
    "already_installed": bool,           # True if this was a redundant/idempotent call
    "timestamp": String,                 # ISO 8601 UTC timestamp of execution
    "version": String,                   # Module version string (e.g. "2.0.0")
    "target_renderer": String,           # "gl_compatibility"
    "changes": Array[String],            # Granular list of every change applied
    "resource_counts": {
        "materials_duplicated": int,     # Count of unique StandardMaterial3D duplicates cached
        "mesh_overrides_applied": int,   # Count of individual mesh surfaces overridden
        "multimesh_batches_overridden": int, # Count of MultiMeshInstance3D batches tuned
        "static_surface_batches_overridden": int, # Count of merged static surface meshes tuned
        "lights_tuned": int,             # Count of DirectionalLight3D nodes calibrated
        "environments_tuned": int,       # Count of WorldEnvironment nodes calibrated
        "injected_nodes": int            # Count of new polish nodes added (Downlight, Signage)
    },
    "affected_areas": Array[String],     # List of all 7 audited campus areas
    "measured_costs": {
        "additional_texture_bytes": int, # Additional texture memory allocated (0 bytes)
        "additional_draw_calls": int,    # Additional scene draw calls (0-4 max)
        "multimesh_batches_retained": int, # Verifies 28 batches retained
        "static_surface_batches_retained": int, # Verifies 92 static surfaces retained
        "active_positional_shadows": int, # Bounded to 0 (non-shadow-casting downlight)
        "install_time_msec": float       # Execution duration in milliseconds (~60 ms)
    },
    "warnings": Array[String],           # Non-fatal warnings encountered
    "errors": Array[String]              # Error messages if installation was rejected
}
```

#### Precondition Failures
- If `game == null` or invalid: returns `{"installed": false, "errors": ["Invalid or null game reference provided."]}`.
- If `game.ready_to_play != true`: returns `{"installed": false, "errors": ["Game is not ready_to_play. CampusRuntime initialization must complete first."]}`.

---

### 2.2 `uninstall() -> Dictionary`

Reverts all applied changes, restores original materials and lights, and frees injected nodes.

#### Return Value
Returns a reversion summary `Dictionary`:

```gdscript
{
    "uninstalled": bool,                 # True if reversion was executed cleanly
    "status": String,                    # "clean" or "not_installed"
    "reverted_mesh_overrides": int,      # Count of mesh surfaces restored
    "reverted_multimesh_overrides": int, # Count of MultiMesh batches restored
    "reverted_static_surface_overrides": int, # Count of static surfaces restored
    "reverted_lights": int,              # Count of lights restored to baseline parameters
    "reverted_environments": int,        # Count of environment nodes restored
    "removed_nodes": int,                # Count of injected nodes freed
    "errors": Array[String]              # Error messages if issues occurred
}
```

---

### 2.3 Additional Query Methods

- `func is_installed() -> bool`: Returns `true` if the module is currently active.
- `func get_report() -> Dictionary`: Returns a deep copy of the cached installation telemetry report.

---

## 3. Proposed Integration Snippet for Codex

Codex can integrate the visual polish module into production with an isolated, defensive 8-line snippet in `scripts/main.gd`.

### Exact Location in `scripts/main.gd`
In `_init()` / `_ready()` or the asynchronous initialization sequence, immediately after line 73 where `ready_to_play = true` is set:

```gdscript
	# ... line 72: print("APPROVED_PROPS_READY ", imported_props.size(), " stations=", stations.size())
	ready_to_play = true
	pause_menu.set_ready(true)
	DisplayServer.window_set_title("ENSA | Incident Response")
	loading.text = "Campus ready / choose Start exploration"
	_spawn("Campus plaza")
```

### Proposed 8-Line Integration Snippet

```gdscript
	# Optional Antigravity visual polish module
	if ResourceLoader.exists("res://scripts/antigravity/environment_polish.gd"):
		var polish_script: GDScript = load("res://scripts/antigravity/environment_polish.gd")
		var polish_node: Node3D = polish_script.new()
		polish_node.name = "AntigravityEnvironmentPolish"
		add_child(polish_node)
		var polish_stats: Dictionary = polish_node.install(self)
		print("ANTIGRAVITY_POLISH_READY: ", polish_stats.get("installed", false))
```

### Integration Safety Attributes
1. **Defensive Existence Check**: If `environment_polish.gd` is missing, the game initializes normally without error.
2. **Post-Batching Execution**: Runs after `CampusRuntime.build()` and `CampusOcclusion.install()`, ensuring all batches are ready for non-destructive overrides.
3. **Zero Gameplay Coupling**: Polish runs strictly as a cosmetic overlay; player locomotion, doors, missions, UI, and terminal interaction remain unaffected.

---

## 4. Resource & Licensing Compliance

In accordance with project policy (`ORIGINAL_REQUEST.md` R3):

1. **Zero External 3D Models Imported**:
   - No `.glb`, `.gltf`, `.obj`, `.fbx`, or `.blend` files were imported.
   - Total 3D assets in repository remains strictly at 6 (the authentic `campus.glb` and 5 approved user models).
2. **Approved User Models Preserved**:
   All 5 GLBs in `assets/user_models/` remain byte-identical with exact matching SHA256 checksums from `tools/approved-asset-hashes.json`:
   - `gamer_setup_pack.glb`: `D90A4653B50A5FB76120BBFC6DE6AF738412F3A2611E1471CFF3B7B5E65AB6D1`
   - `office_chair.glb`: `4CE6D139CE3C91F3CD7595391790F3BE6370551626E3E6D08A3CE2E608163AAB`
   - `office_desk_140x60.glb`: `469D5BD0493F7F6EDB8DFF31B03F05490ED24F24C2552A87923A22388CDAA214`
   - `server_rack.glb`: `9A51530DD19E742454313B8771B2CECEF03C429F3CD998AA24294B9BC2AE7BCE`
   - `server_rack_1.glb`: `56BF9E380BB63FA159681B9591AE8C0E26B76E67BBD7244586119C5D88FFBA34`
3. **Authentic Moroccan Campus Architecture Preserved**:
   - `assets/campus.glb` (`478E15820EC4BD7DA057907CB1E4E33B4E05B0EE7B677F19B87711ED879D4987`, 42,560,584 bytes) is preserved untouched.
4. **Procedural & Injected Nodes**:
   - Canopy Downlight: Native Godot `SpotLight3D` (zero external asset dependency).
   - Entrance Signage: Native Godot `Label3D` nodes using system-rendered vector text `"// ENSA FÈS"` and `"ÉCOLE NATIONALE DES SCIENCES APPLIQUÉES"` (zero texture bitmap imports).

---

## 5. Step-by-Step Validation Instructions

All verification tests run directly with Godot 4.3 stable console:

### 5.1 Unit & Lifecycle Contract Tests
Verifies input validation, idempotency, complete reversibility, and lifecycle safety:
```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --headless -s tools/antigravity/preview_harness.gd --polish-test --report=res://tools/antigravity/polish_test_report.json
```
*Expected Result*: Tests 1 through 8 pass with exit code 0.

### 5.2 Material Contract Test
Verifies material duplication, glass transparency, glazing frame opacity, mapped asset preservation, and unshaded protection:
```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --headless -s tools/polish_material_contract_test.gd
```
*Expected Result*: `POLISH_MATERIAL_CONTRACT {"glass_transparent":true,"glazing_frame_opaque":true,"mapped_asset_preserved":true,"passed":true,"shared_material_cache":true,"unknown_asset_preserved":true}`.

### 5.3 Workstation & Computer Integration Test
Verifies collision boundaries, raycast interaction, unshaded screen shaders, and interactive PC workstation stations across all 5 operational stations:
```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --headless -s tools/computer_integration_test.gd
```
*Expected Result*: `COMPUTER_INTEGRATION {"checks":81,"failures":[],"passed":true,...}`.

### 5.4 Adversarial Stress & Rapid Lifecycle Test
Verifies multi-instance idempotency, 10 back-to-back install/uninstall cycles, memory stability, and batch counts:
```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --headless -s tools/antigravity/challenger_m2_stress_test.gd
```
*Expected Result*: `CHALLENGER M2 STRESS TEST FINISHED: passed=true (Assertions Total: 327 | Passed: 327 | Failed: 0)`.

### 5.5 Warmed-Play Performance Benchmark
Executes a warmed benchmark across all 9 camera locations with GPU rendering active:
```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . -s tools/antigravity/preview_harness.gd --benchmark
```
*Expected Result*: Generates `tools/antigravity/preview_harness_report.json` with baseline and polished metrics for all 9 views, confirming zero performance regressions.

---

## 6. Limitations & Hardware Profile Notes

1. **Renderer**: Built and tuned specifically for the **GL Compatibility renderer** (OpenGL 3.3). Advanced Forward+ features (SSR, SDFGI, volumetric fog) are intentionally avoided to ensure 100% compatibility with Intel Iris Plus integrated graphics.
2. **Light Limits per Mesh**: Under GL Compatibility, Godot enforces a maximum limit of 8 lights per mesh surface. The injected canopy downlight is carefully placed outside interior rooms and uses a bounded radius (6.5 m) to prevent light limit contention.
3. **Shadow Budget**: The canopy downlight has `shadow_enabled = false`, ensuring zero additional shadow map render passes and 0 additional GPU fillrate burden.
4. **Resolution & Anti-Aliasing**: Formally benchmarked at **1280x720** with **2x MSAA** (`Viewport.MSAA_2X`).
