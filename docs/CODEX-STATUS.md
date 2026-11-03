# Codex current work

The entrance bug fixes are complete. Antigravity polish is now integrated, with Codex corrections to multi-surface material preservation, overrides, atrium repair coverage and facade shadow bias. See [POLISH-INTEGRATION.md](POLISH-INTEGRATION.md). Native entrance regression passes 84 checks and PC integration passes 81 with the overlay enabled. New polish integration passes 2,360 checks; opt-out passes 17.

Current behavior: reception has two central sliding leaves; cream entrance and atrium front have hinged doubles; atrium side has a hinged single opening onto the broad portico. Four entrances total. The side floor gap is closed at y=1.814 with actual tiled geometry/collision and continuous railing. Overlapping terrace steps are trimmed only inside reception frontage. See ENTRANCE-BUGFIXES.md for details and native screenshots.

Protected modules added by Codex: scripts/sliding_door.gd and scripts/atrium_entrance_repair.gd. Production integration remains owned by Codex. Source campus assets are unchanged.

Prior door physics checks pass 39; PC hover checks pass 135. Actual current baseline/polished captures are in tools/polish-integrated. All completed polish test processes have exited.

ENSA Games launcher core and Antigravity presentation are integrated. The production boot is lightweight; campus resources are requested only after mission selection. Preferences, validated Continue, cancellation/error recovery, pause/settings routing and repeated world transitions are implemented. See [LAUNCHER-STATUS.md](LAUNCHER-STATUS.md) and [ENSA-GAMES-ARCHITECTURE.md](ENSA-GAMES-ARCHITECTURE.md). The reference home uses the white vector emblem with no AVAILABLE badge; its latest native layout/navigation verification passes 39 checks.

Next collaboration assignment: Antigravity builds the independent playable Zombie RPG episode described in [ANTIGRAVITY-BIG-TASK-ZOMBIE-RPG.md](ANTIGRAVITY-BIG-TASK-ZOMBIE-RPG.md). Codex owns shared launcher/core integration and cybersecurity regression. Do not replace that implementation task with another verification-only pass.

Parallel implementation is now active. Codex's shared mode services, save isolation, mission routing, pause/settings ownership and safe cancellation draining are implemented (37 focused fixtures; 72 native cyber checks). Antigravity's real mode is connected in the isolated launcher harness; its Esc fix brings that harness to 29/29. Remaining mode-owned HUD/viewmodel/lighting implementation is assigned in [ANTIGRAVITY-ZOMBIE-PLAYABILITY-AND-VISUAL-FINISH.md](ANTIGRAVITY-ZOMBIE-PLAYABILITY-AND-VISUAL-FINISH.md). Shared ownership and handoff details are in [PARALLEL-WORK-CODEX-ANTIGRAVITY.md](PARALLEL-WORK-CODEX-ANTIGRAVITY.md). Production Zombie availability remains gated while those visual issues are finished.
