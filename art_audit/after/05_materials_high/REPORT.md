# Milestone 4 — High-preset PBR material kit

Date: 2026-11-18 · Skills: `blender-director` → `realistic-style` → `materials` → `texture-workflow` → `lookdev` → `qa-review`

## Decision

The new materials belong to the **High** preset only ("High = something extra").
- **Medium** keeps the original look.
- **Low** keeps the original small textures for speed.
- High uses Medium geometry plus the new kit, MSAA 4x and 60 m shadows.

## What was made (`tools/material_kit_high.py`, run in Blender 4.3 with numpy)

- 12 seamless kinds at 1024 px, each with albedo + normal (OpenGL / green-up) + roughness: 36 textures in `assets/runtime_surfaces_high/`.
- Deterministic and procedural: fixed seeds, no external images, so licensing is clean.
- Albedo is a near-white multiplier: Godot multiplies it by each source material's colour, so campus colours stay exactly as authored.
- Godot import: VRAM compressed (S3TC) with mipmaps; the normal maps use the normal-map flag. The old textures were lossless with no mipmaps.

| Kind | Repeat | Detail |
| --- | --- | --- |
| paving | 2.4 m | same 4×4 staggered 0.6 m slabs as Medium + joint grooves, per-slab tone/tilt, chipped edges, grime |
| mineral (cream render) | 2.0 m | stipple, trowel marks, soft blotches, light stains |
| limestone | 2.0 m | mottling, pits, faint bedding |
| floor_stone (+ veined) | 2.0 m | honed stone, fine veins, polish variation |
| terrazzo | 1.25 m | 3 sizes of chips |
| slate | 1.6 m | layered cleft relief |
| wood / wood_horizontal / wood_transverse | 1.2 m | 0.4 m boards (0.6 m transverse), grain rings, soft seams |
| asphalt | 1.5 m | aggregate stones |
| carpet | 0.6 m | loop pile |
| fabric | 0.25 m | plain weave |

Not covered (keep the Medium textures): lawn, foliage, bark, soil, metal, glass, simple.

## Runtime (`scripts/campus_materials.gd`)

- `high_detail` is set when the requested preset is `high`; `_apply_high_kit()` adds albedo + normal + roughness maps, with world triplanar mapping at `1 / repeat`.
- The Low/Medium code path is unchanged; the High switch runs before it.

## QA

- **Blender lookdev:** `art_audit/work/04_materials/lookdev_high_kit.png` shows all 12 kinds on cubes and floor tiles (box projection, like Godot).
- **In-game:** `art_audit/after/05_materials_high/` vs `05_materials_medium/`, same camera views.
  - Plaza: slab tone variation, chipped joints, grime. The slab layout matches Medium; it looks denser only because Medium's faint joints and missing mipmaps hide many of them.
  - Reception desk: real wood grain. The first pass used 0.2 m boards, which read like decking, so it was widened to 0.4 m with softer seams.
  - Cream facades and steps: subtle plaster and limestone relief. This is deliberately restrained.
- **Capture harness, High:** `passed=true failures=0`.
- **Launcher test, High:** mission READY; only the same 5 checks fail as on the original code.

## Cost (measured back to back on this machine)

| | Medium | High |
| --- | --- | --- |
| GPU per frame, most views (est. play) | 29–39 ms | 31–44 ms |
| First mission load | 23.6 s | 24.9 s |
| Second load | 11.4 s | 16.4 s |
| Texture memory | ~2.6 MB | about +25 MB (36 × 1024² S3TC with mips) |

High adds 0–25% GPU time per view, including its 4x MSAA and longer shadows. That suits a quality preset for stronger PCs.

## Files

- New: `tools/material_kit_high.py`, `assets/runtime_surfaces_high/` (36 PNG + `.import` + `manifest.json`)
- Changed: `scripts/campus_materials.gd`
- Backup: `art_audit/backups/03_draws_2026-11-18/campus_materials.gd.pre04`
