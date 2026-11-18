# Milestone 7: Over-budget supplied props (Low preset)

Date: 2026-11-19 · Skills: `asset-optimization` → `lod-pipeline` → `qa-review`

## Decision

The lighter props are used on **Low** only. **Medium** and **High** keep the original supplied models.

## What changed (`tools/props_low.py`, Blender 4.3; the originals are untouched)

| Prop | Original | Low | How |
| --- | --- | --- | --- |
| `gamer_setup_pack.glb` (5 parts mounted, ×4 stations in game) | 37 meshes, 14.2k tris, 22 materials | 6 meshes, 3.4k tris, 2 materials (+ screen) | Per part, material colours are baked to vertex colours and the meshes are joined into one object. The body uses `mt_low_body`; the LEDs use `mt_pc_led`, which the game restyles by name. Then decimated to 24%. Node names are kept, including the `sm_monitor_mt_monitor_screen_0` screen. |
| `server_rack_1.glb` | 12 meshes, 74.8k tris | 12 meshes, 5.3k tris | The four 17.5k-tri cable looms are reduced to 4%; buttons and lights to 30%. |

Output files: `assets/user_models/low/gamer_setup_pack_low.glb` and `assets/user_models/low/server_rack_1_low.glb`.

Runtime selection:
- `ComputerProp.asset_path()` and `FurnitureProps` (`low_path`) pick the Low files when the preset is low.
- `source_asset` metadata records the file that was actually used.

## Result (Low, harness, same machine, vs previous Low run)

| View | Tris drawn | Draw calls |
| --- | ---: | ---: |
| Security (rack + PC) | −84k | 828 → 690 |
| Reception | −36k | 776 → 638 |
| Plaza | −30k | 869 → 759 |
| Auditorium teaching | −29k | 517 → 407 |

## QA

- **Capture harness, Low:** `passed=true failures=0`.
- **`tools/computer_integration_test.gd`:** Low 81/81 and Medium 81/81. The test now expects the preset's PC file and its mesh count (Low 6, Medium/High 37) instead of a hard-coded path.
- **Look:**
  - The monitor, keyboard and mouse read the same.
  - The Low tower is opaque: you no longer see the white motherboard through the side glass, so it reads as a dark tower.
  - The rack front (drives, lights) is unchanged.
- **Budget miss:** the roadmap target for the rack was ≤3k tris. It is 5.3k, because the drive and light faces were kept intact.
