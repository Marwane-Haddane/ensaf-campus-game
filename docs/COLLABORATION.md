# Shared work boundaries

Project: C:\1Project\Vr --- cyber\ensaf-campus-v4-project\ENSA-Fes-Campus-v4\campus-game

Codex owns core gameplay, project integration, player physics, desktop/shell/mission/report UI, pause/menu, door controllers, and entrance geometry/collisions. Existing production files remain under Codex ownership while that work is active.

Antigravity owns an isolated campus environment visual-polish module and its own QA assets. Its complete task is docs/ANTIGRAVITY-PROMPT.md. Allowed write areas are scripts/antigravity/, assets/antigravity/, tools/antigravity/, and antigravity/. Proposed changes elsewhere belong in antigravity/INTEGRATION.md for Codex to integrate.

Communicate through antigravity/STATUS.md and INTEGRATION.md, plus the user relaying chat handoffs. There is no assumed direct connection between the two assistants. Do not edit the same production files concurrently, close the user's game, or run simultaneous GPU benchmarks.

New external 3D models require the user's explicit review/approval before download or import. Preserve source campus files and approved model credits.

Codex core-game status and latest entrance changes: [CODEX-STATUS.md](CODEX-STATUS.md). Current entrance regression report: [ENTRANCE-BUGFIXES.md](ENTRANCE-BUGFIXES.md).

ENSA Games launcher collaboration: [Codex task](CODEX-ENSA-GAMES-LAUNCHER.md), [Antigravity task](ANTIGRAVITY-ENSA-GAMES-LAUNCHER.md). These define version-1 presentation methods/signals and separate launcher file ownership. Antigravity's new launcher presentation folders are additional allowed namespaces as listed in its brief; core loading, preferences and integration remain Codex-owned.
