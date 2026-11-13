# Operation Blackout — CY-2026-002

Open the cybersecurity workstation, choose Applications → Operation Blackout, or type:

    mission start blackout

Read the briefing with `cat ~/Documents/blackout-briefing.md`. Use `lab status` to track objectives and `lab help` for supported syntax. Hints reduce the final score.

The scenario starts with a disconnected interface on the wrong subnet. The player repairs the analyst address and route, discovers the research segment, enumerates the maintenance endpoint, investigates leaked fictional identity clues, edits a Python permutation generator, validates candidates against the lab account, preserves remote logs, locks the account, closes the legacy service, configures firewall access, and verifies archive availability. The command trail and findings are written to the virtual Reports folder.

Network commands operate a stateful fictional topology; they do not invoke host tools or reach real networks. `audit-auth`, lab keyring authentication, simulated lockout time, and evidence-preservation gates are teaching abstractions. Existing HTTPS firewall access is retained. This is not a complete Linux shell or a containerized network.

The Python exercise uses installed Python 3 on PATH. A bounded AST interpreter implements the documented teaching subset using Python and itertools; arbitrary Python modules, host file operations, and sockets are unavailable. The script output is real generated data consumed by the authentication simulation. No Python runtime or third-party packages are bundled. The runner source is embedded in python_lab_source.gd for export inclusion; keep it synchronized with python_lab_worker.py.

Progress, player code, candidate output and evidence are included in the normal incident-mode save. Starting/restarting Blackout resets its progress. Old incident checkpoints remain compatible.

Validation: 33 end-to-end checks including normal checkpoint write/read/restore; 66 original shell regression checks; 8 Python runner tests. Editor rendered and inspected at 1280×720. Tests cover failed prerequisites, wrong candidates, rate limits, evidence gates, remediation, completion, invalid saves, host access rejection and bounded execution.
