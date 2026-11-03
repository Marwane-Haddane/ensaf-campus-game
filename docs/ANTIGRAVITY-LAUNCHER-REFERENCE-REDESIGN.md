# Antigravity — latest user-selected home design

This is the latest visual direction, superseding the old two-equal-cards home layout. Continue using the existing Godot version-1 presentation API and ownership boundaries. Codex is implementing/testing core services; you own the native launcher presentation.

## Exact references and ready-to-use assets

- User's selected home screenshot: `docs/references/launcher-final-target.png`.
- User's emblem source: `docs/references/ensa-emblem-source.png`.
- Clean cinematic dusk background, generated to match the selected reference: `res://assets/launcher/campus-dusk-reference.png`.
- Clean workstation case thumbnail, generated to match the reference: `res://assets/launcher/case-workstation.png`.
- Actual white transparent vector recreation of the supplied emblem: `res://assets/launcher/ensa-emblem-white.svg`.

The PNGs are menu illustrations, not claims that the playable campus has been rebuilt to match photorealism. Keep them as still artwork; never instantiate a 3D campus behind the home screen. All buttons, labels, key hints, rules, progress and cards must remain real native Controls, not pixels in a flattened mockup.

## Match the screenshot closely

1. Full-screen dusk campus image. Deep navy/graphite treatment that retains the warm windows, wet courtyard and building composition. Avoid crushing the artwork beneath an overly dark full-screen overlay.
2. Fixed left rail, approximately 17% of the viewport width (about 215–240 logical pixels at a 1280–1426 width). Fine right divider. White emblem centered above ENSA GAMES and the small Campus Operations & Simulation Hub subtitle.
3. White emblem must use the supplied SVG, not the old shield or a blue/red bitmap. Keep aspect ratio and transparent background; do not embed a raster inside another SVG. Use it consistently on boot/home where appropriate.
4. Left navigation: Play, Game Modes, Continue only when a validated save exists, Settings, How to Play, Credits; Quit anchored near the bottom. Real icons from the existing licensed icon set. Selected Play uses the quiet teal horizontal highlight and thin vertical accent seen in the reference.
5. Main content begins around 21% of the width. Large off-white heading on two lines: ENSA Incident / Response. Supporting copy: “Investigate incidents. Find evidence.\nDefend the campus.” Match the reference hierarchy and spacing.
6. **Remove the AVAILABLE badge entirely from home.** Do not reserve an empty badge row or leave a hidden badge's gap. Backend availability checks and mode registry remain unchanged.
7. Prominent teal Play CTA beneath the heading, left aligned, roughly 275–305 px wide at the reference scale; dark bold label and a right chevron. Below it, a quiet outlined Enter keycap and Play label. Enter must have predictable focus/action semantics and never bypass the briefing/loader.
8. Below a fine divider, place the clean workstation thumbnail on the left of an active-case section. Show ACTIVE CASE, IR-2026-001, The borrowed session, real status, a subtle seven-segment progress display, and the objective with a monitor icon. Use actual supplied data; do not invent saved progress.
9. Smaller Zombie RPG Survival preview at lower right, separated by a vertical rule: dusk campus thumbnail, lock icon, COMING SOON badge, title and “Explore. Survive. Protect your resources.” It stays unavailable; no Start action and no heavy zombie-model loading.
10. Full-width fine bottom status strip. Show a calm indicator and **Menu ready** after launcher initialization. Do not copy the reference's “Preparing campus...” / “Loading environment” as permanent home copy: the world loads only after Start Mission. Use actual loading model information on the mission-loading screen.

Keep normal text and key hints legible at 1280×720. Use responsive Containers/anchors and adjust typography/margins to retain the same hierarchy at 1920×1080 and narrower windows. Preserve the screenshot's composition rather than adding unrelated dashboard panels.

## Optional backend fields Codex will supply

Existing `mission`, `continue`, `control_hints`, `loading`, `preferences` and mode data remain valid. Codex is adding optional home metadata:

```text
case_summary: {id, title, status, completed, total, objective}
brand_assets: {logo_path, background_path, case_image_path}
```

Initial case_summary is IR-2026-001 / The borrowed session / Investigation pending / 0 / 7 / Find the marked workstation. Later it reflects the validated saved checkpoint. If absent, use the existing mission and a pending initial case; do not read save files yourself.

Use `continue.available` as the only authority for Continue visibility. Progress is completed authored mission steps, not an invented percentage. The seven-segment bar must tolerate completed values 0 through total, including full completion.

The two Play controls emit the existing `play` intent. The mode card stays COMING SOON. Existing settings/loading/briefing/error/ready behavior must survive the redesign.

## Coordination and verification

Edit only your existing Antigravity launcher presentation/resource/handoff folders. Read the supplied Codex-owned assets without moving/deleting them. No changes to controller, settings store, saves, loader, main.gd, campus_runtime.gd, project entry or gameplay.

Do not regress the fixes from your second integration pass. The prior final visual QA brief still applies to settings content height, loading/ready centering, clean artwork, focus and modal behavior. Keep native screenshots current: the old fixture screenshots no longer represent this requested home design.

Deliver settled native Home screenshots at 1280×720 and 1920×1080, both with no save and a valid Continue summary; verify mouse/keyboard navigation and absent AVAILABLE badge. Update STATUS.md / INTEGRATION.md with exact changed files, screenshot paths, any optional-field usage and remaining gaps. Coordinate native GPU tests so they do not overlap Codex's tests.
