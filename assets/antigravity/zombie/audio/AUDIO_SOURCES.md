# After Hours audio sources and licences

All After Hours sound effects are generated procedurally at runtime. No audio
files are downloaded or shipped, and no third-party samples are used.

| Sound | Where it is made | Used by | Licence |
|---|---|---|---|
| Player footsteps (walk, sprint), landing | `scripts/antigravity/zombie/zombie_audio.gd` (`_footstep`) | `player_controller.gd`, one per head-bob dip | CC0 1.0 (original work) |
| Player hurt grunt | `zombie_audio.gd` (`_voice`) | `player_controller.gd` `take_damage` | CC0 1.0 |
| Infected idle groan, alert snarl, attack snarl, hurt, death | `zombie_audio.gd` (`_voice`, pitch set per enemy type) | `enemy_controller.gd`, positional `AudioStreamPlayer3D` | CC0 1.0 |
| Infected footsteps, brute/winged lion heavy steps | `zombie_audio.gd` (`_footstep`) | `enemy_controller.gd`, matched to locomotion speed | CC0 1.0 |
| Brute roar | `zombie_audio.gd` (`_voice`) | brute alert, swing and death | CC0 1.0 |
| Pickup chime, ammo clack, medkit chime | `zombie_audio.gd` (`_chime`, `_clack`) | `zombie_game.gd` pickups and medkit use | CC0 1.0 |
| UI click and hover ticks | `zombie_audio.gd` (`_tick`) | every button in `zombie_hud.gd` | CC0 1.0 |
| Level start drone, level clear sting | `zombie_audio.gd` (`_drone`, `_chime`) | `level_director.gd` | CC0 1.0 |
| Weapon fire, shotgun blast, dry-fire/empty click, reload, melee swing, hit tick | `scripts/antigravity/zombie/weapon_controller.gd` (`_play_synth_sound`, from earlier work) | weapons | CC0 1.0 |

The synthesis uses filtered noise, glottal pulse trains through simple formant
filters, and sine partials. Seeds are fixed per sound, so every run sounds the
same. Released under CC0 1.0 Universal:
https://creativecommons.org/publicdomain/zero/1.0/
