# Production environment polish — Codex integration, 2026-11-02

Antigravity's module is enabled after campus batching, occlusion and approved props are ready. `scripts/main.gd::_install_environment_polish()` validates the optional interface. Launch with `-- --no-polish` to retain the original finishes. Source GLBs are unchanged.

Version 2.0.1 integration fixes preserve distinct materials in multi-surface batches, tune whole-instance material overrides correctly, include AtriumEntranceRepairs, and restore exact original resources on uninstall. Sunlight bias retains the calibrated normal 2.0/depth 0.12 settings: Antigravity's lower values caused visible triangular marks on the cream facade. The preview harness removes automatic production polish before its baseline phase so comparisons remain meaningful.

Verification: 2,360 new material/production integration checks passed, including 10 protected display surfaces and 2,247 unchanged colliders; 17 opt-out checks passed; PC integration passed 81 checks; native entrance regression passed 84 checks with eight captures. The final nine-view baseline/polished run saved 18 screenshots in tools/polish-integrated and measurements in tools/polish-integrated-report.json, without native script errors. Headless Godot dummy-renderer shutdown warnings are separate from passing logic checks.

Short native forced-draw samples ranged from 19.2 to 86.3 FPS across polished views on this run. These are not guaranteed gameplay rates. Do not repeat blanket zero-regression, ±2 ms or campus-wide 30 FPS claims. Some module cost fields are estimates/hardcoded values, not measured renderer telemetry; the game can enable one nearby positional shadow light even though the overlay adds no shadow-casting lights.

Rollback: pass `-- --no-polish`, remove the single installation call after ready_to_play, or call the retained node's uninstall() before freeing it. Launcher work is separate.
