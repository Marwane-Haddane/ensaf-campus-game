# Antigravity — final visual QA against the integrated launcher

Give this to Antigravity. Your second-pass handoff has been received. Codex is validating it and removing redundant adapter logic. Continue preserving the existing version-1 contract and file ownership from the prior briefs.

## Remaining work with concrete evidence

The earlier native integrated captures revealed three visual issues that fixture/intent pass counts did not detect. These images were taken before your latest handoff, so first reproduce against your latest code with the native view directly and the current core. If fixed already, prove it with fresh captures and geometry assertions; do not reintroduce a workaround unnecessarily.

Evidence:

```text
tools/launcher/integrated-home.png
tools/launcher/integrated-settings.png
tools/launcher/integrated-loading.png
tools/launcher/integrated-ready.png
```

1. **Baked gameplay HUD in artwork.** The campus background and both mode-card images visibly contain the gameplay case panels, crosshair, prompts and controls. They remain visible beneath the launcher UI because they are pixels in the image, not live HUD nodes. Replace those assets with clean native scene captures with all gameplay CanvasLayers/markers/interaction outlines hidden before capturing. Do not crop out architecture, paint over it, flatten the user's storyboard into the background, or add another live 3D world behind the menu. Retain source/provenance and licence notes.
2. **Settings content collapsed.** The earlier native Settings screenshot showed its tabs and action bar, but the panel containing the actual settings was only a thin empty horizontal strip. Ensure the content region receives real expanding height and each tab ScrollContainer fills its parent. Check real `size`, global rectangles and clipping after layout, rather than only minimum sizes. Every graphics/audio/control/accessibility option must be reachable and visible with scrolling where needed.
3. **Loading/ready panel alignment.** The earlier loading panel was at the upper-left, rather than centered, despite using a CenterContainer. Verify the page root and its center/container descendants fill their parent after they enter the tree. Centering should remain correct after navigating between pages and resizing.

## Exact acceptance checks

- Native, settled captures at 1280×720 and 1920×1080 for Home, all four Settings tabs, Loading and Ready. Include a compact/wider window check.
- Screenshots contain no old case HUD or crosshair baked into launcher artwork.
- In Settings, assert the scroll-content region is meaningfully tall (roughly >250 logical pixels at 720p) and option controls have nonzero visible rectangles inside the page; then actually inspect each captured tab. All action buttons remain on-screen.
- Loading and Ready panels center relative to the viewport; no top-left placement or clipping. Check both null and measured progress.
- Fresh native captures after normal page transitions and after rapid interrupted transitions. Do not capture a half-transparent initial tween as the final result.
- Keyboard traversal reaches options inside scrolling content, and confirmation scrims retain focus/mouse blocking.
- Keep real progress and model/intent semantics unchanged. Do not reimplement settings services, saves, loader state, world initialization or cancellation.

## Ownership and coordination

Edit only your `scripts/scenes/assets/shaders/tools/antigravity/launcher` folders and `antigravity/launcher` handoff files. The new core loader is actively changing under `scripts/launcher`, `scripts/main.gd` and `scripts/campus_runtime.gd`; read them if needed, but do not edit them or run simultaneous GPU tests.

Codex's core responsibilities continue: loading stalls, resource ownership, incremental world construction/cleanup, real settings persistence/display rollback, saves/Continue, and gameplay regression. Your responsibility is presentation layout/artwork and real visual evidence.

If the combined harness is temporarily unavailable because core changes are in progress, use your standalone native harness for layout, then record the exact integrated capture/rectangle check Codex should run. Do not claim a full integrated pass from fixture tests alone.

Update `antigravity/launcher/STATUS.md` and `INTEGRATION.md` with actual changed paths, screenshots, resolution/rectangle checks, remaining limits and any core request. Preserve current public scene/API names. No new models or playable Zombie RPG work is needed.
