# ENSA Games menu assets

- `campus-dusk-reference.png`: generated with the built-in image-generation tool from the user's chosen launcher reference, with all interface content removed. A cinematic menu illustration; it does not replace the playable 3D campus geometry.
- `case-workstation.png`: generated with the same tool/art direction as a clean standalone active-case illustration. No UI, text or HUD is baked into it.
- `ensa-emblem-white.svg`: monochrome vector reconstruction of the user's supplied university emblem (`docs/references/ensa-emblem-source.png`). Real white SVG paths on transparency; no embedded raster or external font dependency. It is a reconstruction from that raster reference, not an official vector master file.

The original user references remain unchanged in docs/references. The deterministic vector tracing utility is tools/launcher/vectorize_emblem.py; it reads the reference's silhouette and emits SVG. Existing Tabler UI icons retain their own licence under assets/ui/icons.

`icons/` contains white-stroke Tabler outline icons from https://github.com/tabler/tabler-icons/tree/main/icons/outline (player-play, layout-grid, settings, book, file-description, power, lock and device-desktop). Their MIT licence is included beside them. Only currentColor was converted to explicit white for predictable native SVG rendering.
