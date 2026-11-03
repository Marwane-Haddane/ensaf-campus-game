# Mission 01 — The borrowed session

**One first-person campus mission, seven actions, about 8–12 minutes.** The learner reaches a marked training console, examines a suspected workstation compromise, records evidence, contains the incident, restores service, and submits a short report. The campus is a visual setting. Every person, device, account, event, and service in the incident is fictional; this does not describe an incident at ENSA Fes.

## Play loop

Walk to the training console → open the case → choose an available response action → read its result and explanation → finish the report. Keep the console reachable from the spawn point and mark it with a visible objective. All seven actions can happen at this one console; extra rooms, NPCs, combat, and inventory are outside this first playable.

Use a visible seven-item checklist, an evidence journal, and a persistent **SIMULATION — no live systems** label. Actions are buttons with optional command-style labels. Commands beginning with `sim` are invented display text; never pass them to a shell, execute a process, resolve a hostname, or make a network request. Data and results come entirely from `incident.json`.

## The case

The fictional machine `lab-ws-07.campus.example` ran an unrecognized app. The same demo session then appeared from two different TEST-NET addresses, including one after the student signed out. The learner can establish suspicious session reuse, but cannot prove how the session was taken. Avoid calling an IP address a person or treating a process name as proof of the entire attack.

The scenario opens with a **paused evidence snapshot and no active spread**. That makes a brief evidence capture before isolation safe within this exercise. The debrief must explain that an active, spreading real incident can require immediate containment before collection; this sequence is a scenario-specific decision.

| # | Learner action | Required result | Immediate teaching feedback |
|---|---|---|---|
| 1 | Inspect the workstation and timeline | Identify the host, session, and suspicious reuse | Check evidence before choosing a response. An alert is a starting point. |
| 2 | Preserve the snapshot | Save logs, session metadata, timestamps, and a simulated integrity fingerprint in the evidence journal | Recovery can replace local evidence. Capture this paused snapshot first. |
| 3 | Isolate the workstation | Block its simulated network access; keep the evidence console available | Isolation limits the workstation. It does not cancel a session already usable elsewhere. |
| 4 | Revoke the stolen demo session | Invalidate `sess-demo-482` across the simulated identity service | Containment must cover both the endpoint and the reused session. |
| 5 | Restore the approved lab image | Apply `CLEAN-LAB-2026.10` while the host stays isolated | An approved image provides a known baseline; a completed restore is not yet proof of recovery. |
| 6 | Verify recovery and reconnect | Pass baseline, local health, old-session rejection, and controlled reconnection checks | Restore first, test while isolated, reconnect under observation, then confirm expected service. |
| 7 | Write and submit the report | Record an evidence-based summary, artifacts, actions, verification, and follow-up | A useful handover distinguishes observations from inference and records what remains unknown. |

Dependencies are enforced in order. A locked action remains visible with one sentence explaining the missing prerequisite. Wrong attempts cause no state change or point loss. Completed actions are read-only and replay their result; they never award points twice. The mission awards 100 points for completion, with no time pressure.

## Console and feedback

- Show the current objective, available action, and recent output together. Offer an expandable evidence journal instead of requiring learners to remember terminal text.
- Pair every success with a plain-language reason. Pair every blocked action with the exact next action. Preserve all text until the learner dismisses it.
- Support keyboard operation and readable text. Use labels/icons as well as color, provide a pause menu, and release first-person mouse capture while the console is open.
- The report has one short written summary, two evidence choices, a finding choice, and a follow-up choice. Populate host, case, capture, actions, and verification automatically. Require accurate choices and at least 20 characters of summary; explain the fields that need correction. A model summary is available as a hint.

## Data contract

`incident.json` is the engine-independent source. `initial_state` contains boolean flags. A step is available only when every flag in `requires` is true. After a successful interaction, show `terminal.output_lines`, apply `on_success.set_state`, append `journal_entry`, and award `points` once. Never advance on a failed or cancelled interaction. `on_success.set_state` also sets that step's completion flag.

Every step uses the single `response_console` interaction target. The final interaction is a form, validated using `report_form`; earlier interactions are action buttons. `evidence` contains self-contained source fixtures and their journal unlock flag. The fingerprint is deliberately labeled a simulation token, not a real cryptographic verification. Restore and verification outputs are authored fixtures, not claims about a real computer.

`requires` and flags govern the story; they do not invoke infrastructure. The controlled reconnect in step 6 is one atomic simulated action: all preflight checks pass before the reconnection result appears. Only this step may set `host_reconnected` and `recovery_verified`. If a future version introduces failing checks, retain isolation and do not set either flag until the checks pass.

`completion_flag` records an action's historical completion. `host_isolated` records the current connection state: step 3 sets it true and step 6 sets it false. Check completion before prerequisites when replaying a completed result; a completed verification must remain readable after reconnection.

The report renderer uses `report_form.prefill` for fixed fields. It must evaluate each field's `validation`, substitute the learner's text and selected option labels in the report, and display the final report before submission. Store answers only in local game state. A console fallback may present the same form as a full-screen overlay.

## Debrief

Completion shows the submitted report and five takeaways: preserve what recovery may replace; contain the endpoint and the identity separately; restore from an approved baseline; verify before normal service resumes; and write a factual handover. Ask the two unscored reflection questions in `debrief` and show their explanations after an answer. Offer replay, which resets only this fictional mission's local flags, points, journal, and report.

**Done when:** the learner can walk to the console, complete all seven actions in order, see helpful explanations for locked actions, submit a report, and replay. No backend, actual log collection, internet access, or external account is required.
