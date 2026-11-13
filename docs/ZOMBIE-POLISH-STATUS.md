# After Hours gameplay polish

The current episode opens unarmed. Reception supplies the emergency pistol and breaker fuse, and encounters activate as the player advances. The loadout includes the Benelli M4 and weapon-specific ammo. The substation accepts the fuse and relay separately. The mission ends after the player drives the extraction truck through the gate.

Codex improved movement, enemy attack timing, persistent XP and upgrade effects. The latest fixes let Tab close the focused journal and hide the weapon HUD during the unarmed opening and extraction drive.

Launch `PLAY.cmd` and select Game Modes > Zombie RPG > After Hours. The six-page storyboard is in `output/pdf/After-Hours-Gameplay-Storyboard.pdf`.

The native episode run passed 55 checks, including the revised opening, combat, armor purchase, grid restoration, survivor dialogue, extraction and checkpoint readback. The launcher regression passed 44 checks, including pause, Continue, cancellation and steering. The native capture uses scripted positions and holds unrelated enemies between shots. It does not measure sustained frame rate or exercise the full optional road loop.
