# Milestone 3b — Glass/cream profile and real-play FPS

Date: 2026-11-18

## Finding: the old benchmark under-reported FPS by about 2×

`tools/antigravity/preview_harness.gd` timed frames with an engine frame **plus** `RenderingServer.force_draw()` each loop, so every timed frame rendered twice. It also forced MSAA 2x for every preset, while Low really uses MSAA off.

The harness now also records, per view:
- `natural_frame_ms`: normal frames only
- `gpu_ms` / `render_cpu_ms`: Godot's measured render time
- `est_play_fps`: 1000 / max(gpu, cpu), i.e. uncapped

MSAA now follows the preset: low off, medium 2x, high 4x. The old `fps` field is unchanged, for history.

## Glass/cream profile (`tools/frame_profile.gd`, Low, MSAA 2x)

| View | GPU ms | Half resolution | MSAA off | Glass hidden | Game scripts off |
| --- | ---: | ---: | ---: | ---: | ---: |
| Glazed entrance | 15.1 | 14.3 | **10.2** | 11.2 | 13.5 |
| Security | 13.3 | 12.2 | 12.6 | 13.8 | 14.2 |
| Cream front | 17.7 | 14.0 | 17.7 | **14.6** | 16.8 |
| Cream 45° | 15.5 | 10.3 | **11.2** | 14.9 | 14.9 |
| Plaza | 11.8 | 7.3 | **6.8** | 12.3 | 12.1 |

- MSAA is the biggest remaining GPU cost, and the Low preset already turns it off.
- Glass costs ~3 ms in the cream front view.
- Game scripts and post effects cost almost nothing; glow/fog/SSAO are already off.

## Real-play FPS (preset MSAA applied, uncapped estimate)

| View | Medium | Low |
| --- | ---: | ---: |
| Plaza | 46 | **113** |
| Reception | 27 | **87** |
| Auditorium rear | 33 | **85** |
| Glazed entrance | 32 | **78** |
| Security | 32 | **73** |
| Auditorium teaching | 53 | **144** |
| Cream front | 24 | **68** |
| Cream 45° | 41 | **93** |
| Cream inside-out | 78 | **138** |

The game caps at 60 FPS (frame cap / vsync), so **Low holds the 60 FPS cap in every measured view**. Medium (the original look) runs at 24–53 FPS in most views.

These numbers are from this development machine. Weaker PCs scale down from here.

## Files

- Changed: `tools/antigravity/preview_harness.gd` (real-play metrics, preset MSAA)
- New: `tools/frame_profile.gd`
- Data:
  - `art_audit/work/03_draws/frame_profile_low.json`, `frame_profile_medium.json`
  - `art_audit/after/04_real_fps_low/`, `04_real_fps_medium/` (`harness_report.json`)
