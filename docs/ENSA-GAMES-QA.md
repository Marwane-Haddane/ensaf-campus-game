# ENSA Games — implementation and QA record

## Current integrated result

Production starts at `scenes/launcher/boot.tscn`. The first rendered UI and interactive home do not request or instantiate the campus. Play opens the mission briefing; Start Mission loads the existing world through real resource/construction stages. Ready enables an explicit Enter transition. Preferences, display confirmation, validated Continue, error recovery, cancellation, pause/settings routing and return-to-launcher are implemented.

Antigravity's delivered home composition is integrated with Codex's layout calibration: dusk campus artwork, left rail, white vector university emblem, large Incident Response heading, Play, active case and locked future Zombie preview. AVAILABLE is removed. Live controls and case data are native UI over clean artwork.

Fixed in the final native pass:

- Physical font/thumbnail sizing was being applied again inside an already scaled design, expanding the layout after navigation/resizing. Home metrics now use a single proportional scale.
- Showing Continue could temporarily expand the root container during text wrapping and leave Quit/case content off-screen. Root resize/minimum-size notifications now restore the intended layout.
- Collision fallback checked an absent legacy metadata key with a null default, producing repeated engine errors. It now tests for the key before reading it; the same collision fallback remains available.

## Evidence

Latest native environment: Godot 4.3 stable, GL Compatibility, Intel Iris Plus Graphics.

| Check | Result | Evidence |
|---|---:|---|
| Integrated home layout and navigation | 39 passed | `tools/launcher/reference-home-test.json`, `home-visual-final.log` |
| Full launcher → real game → save/Continue/recovery | 72 passed | `tools/launcher/native-integration-final.json`, `integration-native-final.log` |
| Final native engine/script error scan | 0 errors | Same native log; one intentional missing-resource warning exercises recovery |
| Five total mode cycles, earlier stress baseline | 82 passed | `tools/launcher/stress-integration-final.json` |
| Native settings and display behavior, earlier baseline | 19 passed | `tools/launcher/settings-test.json` |
| Separate-process preference persistence | 1 passed | `tools/launcher/settings-test-restart.json` |
| White, transparent, path-based SVG | Passed | `tools/launcher/brand-assets-test.json` |

Home coverage: 960×540, 1280×720, 1920×1080, 1280×1024 and 1920×720, real Play/Settings navigation and a schema-valid Continue checkpoint. Native captures are `tools/launcher/reference-home-*.png`; full-flow captures are `tools/launcher/integrated-*.png`.

Earlier preserved gameplay regression: original and derived campus entrance checks 84, PC integration 81, hover 135, desktop 64 headless, shell 66 and smoke. These are baseline runs, not additional reruns after every visual adjustment.

The source campus SHA256 remains:

```text
478E15820EC4BD7DA057907CB1E4E33B4E05B0EE7B677F19B87711ED879D4987
```

## Reproduce focused native checks

From the game directory:

```powershell
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --script res://tools/launcher/home_visual_test.gd
& "C:\Users\marwa\Downloads\Godot_v4.3-stable_win64_console.exe" --path . --script res://tools/launcher/integration_test.gd
```

Run GPU checks sequentially. Test preferences/checkpoints use isolated test paths.

## Practical limits and next ownership

Parallel mode implementation added per-mode services, default mission routing, persistent recent-mode Continue, safe construction draining and shared pause/settings ownership. Focused fixtures pass 37 checks; native cybersecurity regression passes 72 in `integration-parallel-native.log`. Ready now uses tree pause rather than disabling the world, preserving colliders while freezing gameplay. The initial real Zombie run caught Esc-to-resume; Antigravity's updated module now reports 29/29 in the shared real-mode harness. The native capture exposed HUD/viewmodel/lighting work still assigned to Antigravity. Its production metadata is staged with coming_soon; integration logic is implemented but visual acceptance is not claimed.

Engine resource/driver and collision operations can still be atomic. The final full-flow run observed a roughly 1.15-second interactive-menu time and a largest measured frame gap around 0.65 seconds, including test screenshots and transitions. These observations are not universal FPS/startup guarantees. `profile_load.gd` measures native loading separately without capture writes.

The SVG is a real vector recreation of the supplied low-resolution reference, not an official university source master. Prepared builds include imported data; a fresh source copy still requires its one-time editor import.

Zombie RPG remains Coming Soon in production. Antigravity's next assignment is [the complete playable episode build](ANTIGRAVITY-BIG-TASK-ZOMBIE-RPG.md), inside independent mode folders. Codex owns shared launcher registration and lifecycle integration after that module is delivered. No speculative available scene or fake progress is enabled.
