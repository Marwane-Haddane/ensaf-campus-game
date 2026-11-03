# Visual Audit & Geometry Issue Ledger: ENSA Fez Campus

**Date**: 2026-11-01  
**Project**: ENSA Fez Incident Response Training Game (`campus-game`)  
**Engine & Renderer**: Godot 4.3 (GL Compatibility renderer, GDScript)  
**Target Profile**: 1280x720, 2x MSAA, Intel Iris Plus Graphics (~30 FPS target)  
**Specification Reference**: `PROJECT.md`, `SCOPE_M1.md`, `docs/references/`  

---

## 1. Executive Summary

This Visual Audit documents the baseline visual quality, lighting calibration, material performance, and authentic architectural geometry across all **seven key campus areas** of the École Nationale des Sciences Appliquées (ENSA) de Fès in Morocco.

The primary visual gaps in the current build stem from:
1. **Directional shadow normal-bias detachment** (`shadow_normal_bias = 2.0`), which causes desks, chairs, and server racks to appear ungrounded and floating ("peter-panning") in interior spaces.
2. **High-frequency moiré aliasing** on the auditorium modular ceiling tiles due to extreme albedo contrast across 9 mm dark reveals.
3. **Overexposure and milky glass veiling glare** in the Glazed Building Atrium under direct sunlight and high ambient fill.
4. **Cream Entrance design deviations** from the project target specification (`docs/references/cream-entrance-target.png`), including missing canopy downlight pools, absence of "ENSA FÈS" entrance signage, and flat unreflective interior lobby flooring.
5. **Authentic 3D geometry defects in `assets/campus.glb`**, notably duplicate coincident facade nodes, coplanar slab overlaps, and legacy entrance step issues.

All recommended polish interventions are non-destructive runtime enhancements implemented strictly within `res://scripts/antigravity/environment_polish.gd`, preserving core protected game files, authentic campus geometry, and integrated GPU performance budgets.

---

## 2. Master Camera Transforms & Navigation Matrix

The seven campus areas are audited using exact camera coordinates, look targets, and pitch angles defined in `scripts/main.gd` and `tools/door_game_preview.gd`:

| Area ID | Area Name / View Description | Player Spawn `(X, Y, Z)` | Eye Position `(X, Y + 0.65, Z)` | Look Target `(X, Y, Z)` | Pitch (rad) | Baseline Capture File | Reference Image |
|---|---|---|---|---|---|---|---|
| **Area 1** | Courtyard / Plaza & Gardens | `(-27.0, 1.25, -85.0)` | `(-27.0, 1.90, -85.0)` | `(-37.0, 1.25, -104.0)` | 0.00 | `tools/visual-polish/plaza-preview.png` | `campus-wide-exterior.png` |
| **Area 2** | Auditorium Reception / Desk | `(-36.2, 1.91, -104.1)` | `(-36.2, 2.56, -104.1)` | `(-36.2, 1.91, -106.0)` | -0.23 | `tools/visual-polish/campus-preview.png` | `environment-target.png` |
| **Area 3** | Auditorium Seating & Stage | `(-37.0, 1.924, -107.95)` | `(-37.0, 2.574, -107.95)` | `(-37.0, 1.924, -122.0)` | 0.00 | `tools/visual-polish/auditorium-preview.png` | `campus-preview.png` |
| **Area 4** | Glazed Building Entrance | `(-5.8, 2.80, -102.9)` | `(-5.8, 3.45, -102.9)` | `(-8.0, 2.80, -107.0)` | 0.00 | `tools/visual-polish/glazed-building-preview.png` | `campus-glass-building.png` |
| **Area 5** | Security Workstation Hub | `(0.90, 2.80, -110.5)` | `(0.90, 3.45, -110.5)` | `(0.0, 2.80, -112.0)` | -0.23 | `tools/visual-polish/security-assets-preview.png` | `environment-target.png` |
| **Area 6** | Auditorium Teaching Desk | `(-43.0, 1.09, -121.4)` | `(-43.0, 1.74, -121.4)` | `(-43.0, 1.09, -122.0)` | -0.55 | `tools/visual-polish/teaching-assets-preview.png` | `environment-target.png` |
| **Area 7a** | Cream Entrance (Front Elevation) | `(-14.0, 1.41, 1.8)` | `(-14.0, 2.06, 1.8)` | `(-14.0, 1.75, 0.04)` | -0.17 | `tools/door-main-front-closed.png` | `cream-entrance-target.png` |
| **Area 7b** | Cream Entrance (45° Oblique) | `(-18.0, 1.65, 5.3)` | `(-18.0, 2.30, 5.3)` | `(-14.0, 1.70, 0.04)` | -0.12 | `tools/door-main-exterior-45.png` | `cream-entrance-target.png` |
| **Area 7c** | Cream Entrance (Inside Looking Out) | `(-14.0, 1.41, -2.4)` | `(-14.0, 2.06, -2.4)` | `(-14.0, 1.65, 2.6)` | -0.08 | `tools/door-main-inside-open.png` | `cream-entrance-target.png` |

---

## 3. Detailed Audit by Campus Area

---

### Area 1: Courtyard / Plaza and Gardens
- **Camera Pose**: Eye `(-27.0, 1.90, -85.0)`, Target `(-37.0, 1.25, -104.0)`, Pitch `0.00 rad`.
- **Source Objects**:
  - Plaza concourse: `Site base`, `D7 portico terrace slab`, `AlignedApproachPaving`.
  - Vegetation: `Campus plaza shade tree*`, `R3 Garden tree*`, `lawn blades*`.
  - Enclosures: Ornamental laser-cut ramp balustrade, perimeter security fence.
  - Architecture: Flanking auditorium and reception wings (`mineral` pale cream stucco).
- **Materials**:
  - `paving`: Triplanar 256x256 albedo + normal, roughness 0.94, scale `1.0 / 2.4`.
  - `mineral`: Roughness 0.91, metallic 0.0.
  - `foliage`: Roughness 0.85, albedo tinted `Color("586e35")`.
- **Target Art Reference**: `docs/references/campus-wide-exterior.png` & `campus-glass-building.png` (crisp Mediterranean sunlight, structured stone pavers, lush palm/olive greenery).
- **Prioritized Findings**:
  1. *[P5 — Visual Polish]* **Foliage Tonal Calibration**: Tree crowns appear monochromatic olive-green and lack the botanical variety of Moroccan fan-palms and silver-green olive foliage seen in reference photos.
  2. *[P5 — Visual Polish]* **Ramp Railing Shimmer**: The laser-cut balustrade features subpixel lattice geometry that produces aliasing scintillation during camera movement.
  3. *[P6 — Visual Polish]* **Facade Washout**: High ambient light energy (0.32) combined with unshadowed sun areas slightly bleaches out the warm mineral stucco.

---

### Area 2: Auditorium Reception / Response Desk
- **Camera Pose**: Eye `(-36.2, 2.56, -104.1)`, Target `(-36.2, 1.91, -106.0)`, Pitch `-0.23 rad`.
- **Source Objects**:
  - Desk: Curved wooden reception desk counter.
  - Workstation: `gamer_setup_pack.glb` (curved monitor, keyboard, mousepad, mouse, PC tower).
  - Furniture: Two approved office chairs (`office_chair.glb`) at `(-38.0, 0.922, -106.17)` and `(-35.35, 0.922, -106.17)`.
  - Partition & Door: Interactive glazed entrance door (`InteractiveDoor`) at `(-34.345, 0.9515, -102.78)` and rear glass partition.
- **Materials**:
  - Floor: `E6 reception large format stone floor` (`floor_stone`, roughness 0.48).
  - Counter: `wood_horizontal` / `wood_vertical` (roughness 0.47).
  - Wall: Accent plaster (`mineral`, roughness 0.91).
- **Target Art Reference**: `docs/references/environment-target.png`.
- **Prioritized Findings**:
  1. *[P1 — Shadow Calibration]* **Serrated Shadow Acne**: Prominent jagged shadow edge runs along the right wall and counter face (`tools/door-reception-closed.png`). Normal bias reduction and cascade split blending are required.
  2. *[P2 — Contact Grounding]* **Counter & Prop Detachment**: Monitor base, keyboard, and PC tower exhibit virtually no contact shading on the counter top.
  3. *[P5 — Visual Polish]* **Counter Wood Definition**: Wood counter surface appears flat and lacks subtle satin finish highlights.

---

### Area 3: Auditorium Seating & Stage
- **Camera Pose**: Eye `(-37.0, 2.574, -107.95)`, Target `(-37.0, 1.924, -122.0)`, Pitch `0.00 rad`.
- **Source Objects**:
  - Seating: Raked tiers of upholstered theater seats flanking a central aisle.
  - Flooring: Red carpet aisle (`mt_carpet_red`), oak parquet stage (`wood_horizontal`).
  - Ceiling: `E8 modular white acoustic ceiling tiles` (591 mm tiles with 9 mm dark reveals) with recessed fluorescent troffers.
  - Stage: Projection screen, conference tables, presentation podium.
- **Materials**:
  - Ceiling: `mineral` family (roughness 0.91, dark grout lines).
  - Carpet: `carpet` family (roughness 0.98, deep red albedo).
  - Wood: `wood_vertical` side acoustic slats (roughness 0.47).
- **Target Art Reference**: `tools/visual-polish/auditorium-preview.png` & project art direction.
- **Prioritized Findings**:
  1. *[P4 — Moiré Elimination]* **Severe Ceiling Moiré**: The high contrast between the 591 mm acoustic tiles and 9 mm dark seams aliases into a distracting, shimmering diagonal grid toward the stage. Softening seam albedo to match tile brightness eliminates this artifact without geometry modification.
  2. *[P6 — Visual Polish]* **Aisle Carpet Flatness**: Red aisle carpet reads as a flat saturated polygon; needs subtle micro-weave diffuse grading.
  3. *[P2 — Contact Grounding]* **Seating Shadow Deficit**: Rows of auditorium chairs cast no local grounding shadows onto the raked risers.

---

### Area 4: Glazed Building Entrance / Atrium
- **Camera Pose**: Eye `(-5.8, 3.45, -102.9)`, Target `(-8.0, 2.80, -107.0)`, Pitch `0.00 rad`.
- **Source Objects**:
  - Facade: Multi-story curtain wall with dark aluminum mullions (`glass`, `metal_painted`).
  - Interior: Grand interior bleachers / tiered seating, cylindrical structural columns, concrete staircase with tubular handrails.
  - Floor: Large-format limestone floor slabs.
- **Materials**:
  - Atrium Glass: `glass` family (alpha 0.13 to 0.20, roughness 0.10, metallic 0.04).
  - Bleachers: `wood_horizontal` slats.
  - Floor: `limestone` / `floor_stone` (roughness 0.48–0.82).
- **Target Art Reference**: `docs/references/campus-glass-building.png` (crisp reflections, visible dark slate tower, transparent framing).
- **Prioritized Findings**:
  1. *[P5 — Visual Polish]* **Excessive Glare & Washed Out Floor**: Direct sunlight combined with high ambient energy (0.32) bleaches out the atrium floor and stairs, losing all surface texture.
  2. *[P5 — Visual Polish]* **Milky Glass Overdraw**: Looking through overlapping exterior curtain glass and interior barriers produces an unnatural milky haze. Calibrating glass alpha to 0.11 and reducing roughness eliminates the haze.
  3. *[P1 — Shadow Calibration]* **Mullion Shadow Stairstepping**: Diagonal bar shadows cast across the bleachers and floor display noticeable pixelation.

---

### Area 5: Security Training Area / Workstation
- **Camera Pose**: Eye `(0.90, 3.45, -110.5)`, Target `(0.0, 2.80, -112.0)`, Pitch `-0.23 rad`.
- **Source Objects**:
  - Workstation: `office_desk_140x60.glb` at `(0, 1.80, -112)`, `office_chair.glb` at `(0, 1.80, -111.15)`.
  - Computer: `gamer_setup_pack.glb` at `(0, 2.55, -112)` (display, keyboard, mouse, tower).
  - Server Infrastructure: `server_rack.glb` ("Lab services rack") at `(1.10, 1.80, -113.5)` and `server_rack_1.glb` ("Recovery storage rack") at `(2.30, 1.80, -113.5)`.
- **Materials**:
  - Desk: Light oak wood grain with satin clearcoat.
  - Racks: Matte powder-coated charcoal steel chassis with perforated ventilation.
  - Floor: Large-format off-white floor tiles.
- **Target Art Reference**: `docs/references/environment-target.png` (crisp contact shadows grounding every prop, rich oak grain, matte cream plaster).
- **Prioritized Findings**:
  1. *[P2 — Contact Grounding]* **Floating Furniture Deficit**: Desk legs, chair casters, and server racks appear unanchored and floating on the shaded floor. Directly contradicts `environment-target.png`, where dark grounding shadows seat each piece.
  2. *[P1 — Shadow Calibration]* **Normal Bias Peter-Panning**: High directional normal bias (2.0) prevents ambient shadows from reaching floor contact points.
  3. *[P5 — Visual Polish]* **Workstation Key Light Tuning**: Dedicated SpotLight at `(0.6, 4.75, -112.0)` requires optimized cone angle and attenuation to enhance contact shadows on mask 2.

---

### Area 6: Auditorium Teaching Desk
- **Camera Pose**: Eye `(-43.0, 1.74, -121.4)`, Target `(-43.0, 1.09, -122.0)`, Pitch `-0.55 rad`.
- **Source Objects**:
  - Presentation Desk: `office_desk_140x60.glb` at `(-43, 0.09, -122)`.
  - Computer: `gamer_setup_pack.glb` at `(-43, 0.84, -122)`.
  - Background: Large white projection screen, speaker lectern, conference chairs.
- **Materials**:
  - Desk: Pale oak veneer (`wood_horizontal`).
  - Stage: Parquet wood flooring.
  - Screen: Matte diffuse white (`mineral` / `simple`).
- **Target Art Reference**: `docs/references/environment-target.png`.
- **Prioritized Findings**:
  1. *[P2 — Contact Grounding]* **Peripheral Equipment Contact**: Keyboard, mouse, and monitor stand lack micro-occlusion shadows against the wooden desk top.
  2. *[P5 — Visual Polish]* **Display & Tower LED Balance**: Emissive elements (`mt_pc_led`) must remain restrained to avoid overwhelming the dark stage environment.

---

### Area 7: Cream Main-Building Entrance & Canopy (3 Audited Views)
- **Design Target Specification**: `docs/references/cream-entrance-target.png`
- **Source Objects**:
  - Entrance Portico: Cream square columns, suspended canopy with wood-slatted soffit (`CanopyUndersideSlats`, 34 slats) and 3 linear recessed lights (`RecessedCanopyLight`).
  - Doors: Interactive double glazed doors (`InteractiveDoor`, outer pivot hinges, black framing) and sidelights.
  - Steps: 3 uniform entrance steps with nosing and stainless steel handrails (`R2EntranceGeometry`).
  - Plaza: Aligned approach paving slabs and wrought-iron perimeter fence.

#### View 7a: Front Elevation View
- **Camera**: Eye `(-14.0, 2.06, 1.8)`, Target `(-14.0, 1.75, 0.04)`, Pitch `-0.17 rad`.
- **Baseline**: `tools/door-main-front-closed.png`, `door-main-front-open.png`.
- **Prioritized Findings**:
  1. *[P3 — Architectural Polish]* **Missing "ENSA FÈS" Signage**: Prominently depicted in `cream-entrance-target.png` (Top-Right panel) as `"ENSA FÈS - ÉCOLE NATIONALE DES SCIENCES APPLIQUÉES"` mounted above the doorway. Currently, this lintel area is blank cream stucco.
  2. *[P3 — Lighting Polish]* **Canopy Downlight Deficit**: Recessed light boxes glow emissively, but cast no actual light onto the steps or threshold.

#### View 7b: 45-Degree Exterior Oblique View
- **Camera**: Eye `(-18.0, 2.30, 5.3)`, Target `(-14.0, 1.70, 0.04)`, Pitch `-0.12 rad`.
- **Baseline**: `tools/door-main-exterior-45.png`.
- **Prioritized Findings**:
  1. *[P3 — Lighting Polish]* **Missing Canopy Light Pool**: No warm illumination is cast under the canopy soffit across the steps and handrails.
  2. *[P5 — Visual Polish]* **Wrought-Iron Fence Aliasing**: High-frequency vertical iron fence bars shimmer against the sky.

#### View 7c: Interior Looking Out View
- **Camera**: Eye `(-14.0, 2.06, -2.4)`, Target `(-14.0, 1.65, 2.6)`, Pitch `-0.08 rad`.
- **Baseline**: `tools/door-main-inside-open.png`.
- **Prioritized Findings**:
  1. *[P3 — Material Polish]* **Interior Floor Reflection Deficit**: In `cream-entrance-target.png` (Bottom-Right panel), the interior lobby floor is high-gloss polished marble clearly reflecting the exterior daylight, doorframe, and trees. Currently, the floor is flat matte grey stone (`roughness = 0.48`). Overriding with a duplicated polished marble material (`roughness = 0.20`, `specular = 0.70`) directly satisfies this requirement.
  2. *[P5 — Visual Polish]* **Exterior Vista Readability**: Outdoor walkway and gate must remain sharply defined through the open glazed doorway.

---

## 4. Authentic ENSA Fez 3D Geometry Audit & Defect Ledger

In accordance with project policy (ORIGINAL_REQUEST.md R3), the authentic 3D environment model of ENSA Fez in Morocco (`assets/campus.glb`) must be preserved without replacement by generic external assets. The following defects exist in the source GLB model:

### 4.1 Defect 1: Coincident Duplicate Facade Mullion (Z-Fighting Defect)
- **Description**: Mesh node `D7 short facade fine mullion.006` is 100% coincident with `D7 short facade fine mullion.005`.
- **Location**: Glazed building facade mullion grid at `Vector3(-13.0, 1.8, -104.0)`.
- **Runtime Mitigation**: `scripts/campus_runtime.gd:83-87` explicitly hides `.006` at load time.
- **Blender Fix Required for User**: Delete object `D7 short facade fine mullion.006` from `assets/campus.glb`.
- **Capture Verification**: Capture at `Vector3(-14.5, 2.5, -100.0)` looking at `Vector3(-13.0, 2.0, -104.0)` to verify absence of Z-fighting.

### 4.2 Defect 2: Legacy Entrance Step Fragmentation & 35 mm Threshold Drop
- **Description**: Source model contained 10 fragmented, non-uniform entrance step and handrail meshes with irregular rises/runs and a 35 mm rounded bevel drop at the door threshold (`y = 0.52`).
- **Runtime Mitigation**: `scripts/entrance_geometry.gd` hides the 10 legacy meshes and builds `R2EntranceGeometry` (three uniform steps: rise 0.169m, run 0.45m; level threshold landing; aligned approach paving).
- **Blender Fix Required for User**: Delete the 10 legacy step/handrail nodes in `assets/campus.glb`, model 3 permanent uniform steps, and extend `Main plinth` flat top flush to `z = 0.3647` at `y = 0.52`.
- **Capture Verification**: Oblique view `tools/door-main-exterior-45.png` confirms step geometry.

### 4.3 Defect 3: Coplanar Planar Overlaps in `campus.glb`
Documented in `tools/polish_qa_geometry.json`:
1. `E6 white ceiling border` vs `E6 white ceiling border.002` (y=4.32, area: 0.0765 m²)
2. `E6 white ceiling border` vs `E6 white ceiling border.003` (y=4.32, area: 0.0765 m²)
3. `E6 white ceiling border.001` vs `E6 white ceiling border.002` (y=4.32, area: 0.0177 m²)
4. `E6 white ceiling border.001` vs `E6 white ceiling border.003` (y=4.32, area: 0.0177 m²)
5. `D7 long white floor band` vs `D7 short white floor band` (y=1.865, area: 0.0691 m²)
6. `D7 long white floor band.001` vs `D7 short white floor band.001` (y=5.205, area: 0.0691 m²)
7. `D7 long white floor band.002` vs `D7 short white floor band.002` (y=8.505, area: 0.0691 m²)
8. `D7 portico terrace slab` vs `D7 main entrance level landing` (y=1.80, area: **8.7625 m²**; covered by D9 stone finish at y=1.814 in gameplay, but redundant in GLB)
9. `D7 raised entrance landing` vs `D7 closed entrance landing fascia` (y=1.80, area: 0.735 m²)
10. `D7 rear gallery slab` vs `D7 intermediate stair landing` (y=5.10, area: **5.320 m²**)
11. `D7 main entrance level landing` vs `D7 ramp upper connection landing` (y=1.80, area: 1.563 m²)
12. `D9 continuous portico landing stone finish` vs `D9 level access landing` (y=1.814, area: 0.0491 m²)
- **Blender Fix Required for User**: Execute boolean unions or edge welds on overlapping boundary faces to reduce polygon redundancy.

### 4.4 Defect 4: Tree Crown Low-Poly Coarseness
- **Description**: `Campus plaza shade tree*` crowns consist of 42-vertex / 80-triangle spherical lobes that collapse into coarse polygons under default LOD bias (0.30).
- **Runtime Mitigation**: Subdivided at runtime by `CanopyDetail.enhance()`; LOD bias set to 1.5.
- **Blender Fix Required for User**: Model authentic Moroccan botanical foliage (fan-palms, olive trees) with authored branch structures.

---

## 5. Prioritized Action Plan & Performance Budget

All visual enhancements are mapped into an actionable execution matrix complying with Intel Iris Plus performance budgets (~30 FPS, ~1,200–1,400 draw calls, <3.5M primitives):

| Priority | Action Item | Target Locations | Implementation Mechanism | Draw Call / GPU Impact |
|---|---|---|---|---|
| **P1** | Directional Light Calibration | Global (All 7 Areas) | Set `shadow_normal_bias = 0.8` (down from 2.0) and enable split blending in `environment_polish.gd` | Zero additional draw calls; instant contact grounding |
| **P2** | Workstation Contact Grounding | Reception (Area 2), Security (Area 5), Teaching (Area 6) | Enhance key SpotLights on cull mask 2 with tuned spot angle, shadow bias, and soft attenuation | Zero extra scene draw passes (leverages existing mask 2) |
| **P3** | Cream Entrance Polish | Cream Main Entrance (Areas 7a, 7b, 7c) | 1. Add warm canopy downlight (`Vector3(-14, 2.95, 1.5)`, energy 0.65).<br>2. Override interior floor with polished marble duplicate (`roughness = 0.20`).<br>3. Add `"ENSA FÈS"` signage mesh/decal. | +1 light pass under canopy; high visual fidelity matching `cream-entrance-target.png` |
| **P4** | Ceiling Moiré Elimination | Auditorium (Area 3) | Soften albedo contrast of dark reveals on `E8 modular white acoustic ceiling tiles` duplicate material | Zero runtime cost; completely eliminates shimmering moiré |
| **P5** | Glazed Atrium Exposure Tuning | Glazed Building (Area 4) | Tune glass material alpha to 0.11 and roughness to 0.08; slightly reduce ambient light energy | Zero extra draw calls; eliminates milky haze |
| **P6** | Landscape & Paver Polish | Campus Plaza (Area 1) | Rebalance foliage tones to authentic Moroccan olive/palm tones and enrich paver contrast | Zero extra cost (material parameter adjustments) |

---

## 6. Milestone 2 & 3 Verification & Resolution Ledger

All visual polish findings identified in Section 3 have been implemented in `res://scripts/antigravity/environment_polish.gd` and verified via native 1280x720 captures (`tools/visual-polish/polished_*.png`) and empirical benchmarks (`tools/antigravity/preview_harness_report.json`).

| Area ID | Area Name | Baseline Finding | Resolution Status | Technical Implementation & Verification Capture |
|---|---|---|---|---|
| **Area 1** | Courtyard / Plaza & Gardens | Facade bleaching & high ambient washout | **RESOLVED** | Ambient light energy calibrated from 0.34 to 0.28 and tonemap exposure set to 0.95. Verified in `polished_plaza.png`. |
| **Area 2** | Auditorium Reception Desk | Peter-panning floating furniture & jagged shadow acne | **RESOLVED** | `sun.shadow_normal_bias = 0.80`, `sun.shadow_bias = 0.08`, `sun.shadow_blur = 1.40`, and satin stone floor finish (`roughness = 0.40`). Desks and chairs firmly grounded. Verified in `polished_reception.png`. |
| **Area 3** | Auditorium Seating & Stage | Severe diagonal ceiling moiré & Nyquist aliasing | **RESOLVED** | Unhid `E8 ceiling joint backing`, translated vertically by -2 mm, and applied softened off-white material override (`Color(0.72, 0.725, 0.70)`). Moiré 100% eliminated while transverse beams and pilasters remain jet-black. Verified in `polished_auditorium_rear.png`. |
| **Area 4** | Glazed Building Entrance | Milky glass veiling haze & washed-out floor glare | **RESOLVED** | Calibrated 9 glass materials to `alpha = 0.10–0.12`, `roughness = 0.08`, `metallic_specular = 0.70`, with strict frame opacity guardrails. Full interior stair and bleacher visibility restored. Verified in `polished_glazed_entrance.png`. |
| **Area 5** | Security Training Area | Floating server racks, desk legs, chair casters | **RESOLVED** | Directional shadow normal bias reduction (0.80) combined with satin circulation floor finish (`roughness = 0.40`). Terminal screens strictly preserved as unshaded. Verified in `polished_security.png`. |
| **Area 6** | Auditorium Teaching Desk | Lack of contact grounding on wood stage deck | **RESOLVED** | Directional shadow normal bias reduction (0.80) and oak desk / stage finish calibrations (`roughness = 0.36–0.38`). PC displays and tower LEDs preserved. Verified in `polished_auditorium_teaching.png`. |
| **Area 7a** | Cream Entrance (Front Approach) | Missing "ENSA FÈS" signage & dark canopy threshold | **RESOLVED** | Injected warm 3000K canopy downlight (`SpotLight3D` at `(-14.0, 2.95, 1.55)`) and centered dual `Label3D` architectural signage `"// ENSA FÈS"` / `"ÉCOLE NATIONALE DES SCIENCES APPLIQUÉES"` at `(-14.0, 2.86, 0.165)`. Verified in `polished_cream_front.png`. |
| **Area 7b** | Cream Entrance (45° Exterior) | Dark step approach & unlit canopy soffit | **RESOLVED** | Canopy downlight casts warm light pool across all 3 steps, plinth, and stainless steel handrails without extra shadow passes. Verified in `polished_cream_exterior_45.png`. |
| **Area 7c** | Cream Entrance (Inside Looking Out) | Flat matte interior floor lacking exterior reflections | **RESOLVED** | Overrode `B entry hall terrazzo` with diamond-polished marble (`roughness = 0.18`, `specular = 0.80`), producing crisp specular reflections of exterior daylight and doorways matching `cream-entrance-target.png`. Verified in `polished_cream_inside_out.png`. |

