# Native workstation desktop — design QA

**Current functional result: PASS — 64 headless checks.** The incident completes through native desktop controls: seven steps, 100 points, submitted report and debrief. The four visual findings below are resolved in the implementation and covered by native-control checks. The final eight Compatibility-renderer captures are awaiting the coordinated GPU slot; the previous capture pass passed 68 checks. No full-campus scene is instantiated by this desktop test. Application source files were not edited by this QA pass.

## What was verified

- Native LineEdit submission for `ls`, `cd Evidence`, and `cat session.log`, using actual mission facts and the virtual filesystem.
- Up/Down history with draft restoration, Tab command/path completion, and Ctrl+L without clearing history.
- Help folder navigation, Tree selection, preview rendering, clickable guide commands, and enforced response prerequisites.
- Title-bar maximize/restore, dragging, resize grip, minimize/task restore, close/reopen, and workspace switching.
- The incident report opens in a native document window, uses the real form controls and preview validation, can be restored from its task button, and submits to the real mission engine.
- Escape and the native Return to campus control close the desktop and emit the mouse-recapture contract. Opening exercises the same `TrainingUI.open_terminal()` API used by E; campus proximity and movement gating remain outside this standalone test.

## Visual comparison

The desktop follows the supplied references closely in its system bars, five-icon left column, dark blue wallpaper, terminal placement, monospace content, colored paths, window controls, and side-by-side Help layout. The command capture uses a resized native terminal to match the reference's wider command window. Evidence text follows the mission fixtures rather than the abbreviated sample facts in the reference image.

The four states were inspected at 1280×720 and a requested 1672×941 window. Godot's fixed 16:9 canvas renders the larger capture at **1672×940**; the one-pixel aspect rounding is recorded in the test JSON. Screenshots are direct native viewport captures without image edits. Each capture follows two process frames and `RenderingServer.force_draw(false)`.

| State | 1280×720 evidence | Larger-window evidence |
|---|---|---|
| Desktop boot | [boot](workstation_desktop_boot_1280x720.png) | [boot](workstation_desktop_boot_1672x941.png) |
| Typed commands | [commands](workstation_desktop_commands_1280x720.png) | [commands](workstation_desktop_commands_1672x941.png) |
| Help and terminal | [Help](workstation_desktop_help_1280x720.png) | [Help](workstation_desktop_help_1672x941.png) |
| Actual incident form | [report](workstation_desktop_report_1280x720.png) | [report](workstation_desktop_report_1672x941.png) |

## Resolved visual findings

| Finding | Current behavior | Verification |
|---|---|---|
| START_HERE selection was outside the visible file rows | START_HERE is pinned first and its preview remains selected | Headless test checks the first native Tree row and selected file |
| Caret sat between the two prompt lines | Header and lower-dollar entry use separate rows; LineEdit aligns to the lower baseline | Native row structure and vertical sizing checked |
| Large blank space separated the welcome text and prompt | The output fits its content; output and entry flow together in the terminal scroll container | Test checks content sizing and the welcome-to-prompt gap |
| Report content touched the window border | Document content has 16px horizontal and 10px vertical inner margins | Native document container margins checked |

These changes retain the tested command history, completion, file navigation, task restoration and actual incident-report submission. Final updated Compatibility captures were generated and inspected after all four refinements; the current native desktop test passes 72 checks, including eight captures and full seven-step/100-point report flow. Final result: passed.

## Reproduction

Run `Godot_v4.3-stable_win64_console.exe --headless --path <campus-game> --script res://tools/workstation_desktop_test.gd` for state and native-control checks. Omit `--headless` and use Compatibility rendering for the eight screenshots. Results are in [workstation_desktop_test.json](workstation_desktop_test.json).

Reference images inspected: `codex-clipboard-bc1b7580-ea26-4dde-b7f8-a66fee37288c.png` (boot), `codex-clipboard-8705581d-c764-4a48-95ea-259182a3af28.png` (commands), and `codex-clipboard-2e92a5b9-27f2-4aae-9100-431410ae744a.png` (Help), from the supplied local clipboard captures.
