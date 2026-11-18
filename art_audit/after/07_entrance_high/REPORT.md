# Milestone 6: Cream entrance sign and glazed facade

Date: 2026-11-18 · Skills: `archviz` → `materials` → `texture-workflow` → `qa-review`

## Defect found

The source sign "ÉCOLE NATIONALE / DES SCIENCES APPLIQUÉES" places its second line at 3.45–3.68 m. The entry canopy roof starts at 3.04 m (top 3.30 m) and reaches 3.5 m out from the wall. From the street, the canopy edge therefore hides the second line. Medium shows only "ECOLE NATIONALE" and a sliver of line 2 (`07_entrance_medium/sign_zoom.png`).

## Change per preset

| Preset | Sign | Glass |
| --- | --- | --- |
| Low | The 3 lines of 3D text (63k source tris) become flat images baked in Blender (`tools/sign_decals_low.py` → `assets/runtime_signs_low/`). The two upper lines use the new layout. | unchanged |
| Medium | untouched (original layout) | untouched |
| High | The original 3D letters are kept and moved into the new layout, so the relief stays. | Premultiplied-alpha blending keeps the sky reflection at full strength while the glass body stays clear; specular 0.85. |

New layout: the free wall band runs from the canopy top (3.30 m) to the window sills (4.26 m).
- Line 1 is centred at 4.10 m.
- Line 2 is centred at 3.84 m and scaled to 0.8, so it fits without crowding.

The affiliation line under the canopy stays where it is.

Code:
- `scripts/entrance_sign.gd` is called from `campus_runtime.gd`.
- The glass branch in `scripts/campus_materials.gd` changes on High only.

## QA (`tools/entrance_capture.gd`: street views at 15 m and 25 m, a zoomed sign view, the atrium glass)

- **Sign:** both lines are readable on Low and High (`07_entrance_{low,high}/sign_zoom.png`).
- **Glass:** on High the atrium curtain wall reflects the sky and reads as glass. On Medium it reads as dark panes (`atrium_glass.png`).
- **Capture harness:** High `passed=true failures=0`; Low `passed=true failures=0`.
- **Low triangles:** −5.2k drawn in the cream-front view and −4.8k in the inside-out view; draw calls −3. The saving is small because Godot's automatic LOD had already reduced the distant text.

## Known, not changed

- Polish adds a "// ENSA FÈS" Label3D at 2.86 m. It overlaps the affiliation line "UNIVERSITÉ SIDI MOHAMED BEN ABDELLAH".
- Facade reveals and stone trims were not added. The cream facade already has sills and piers, and the High plaster kit (#4) gives the wall its texture.
