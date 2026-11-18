# RTServer verification map

This directory is the maintained source for verifying the operator-facing console of the RimWorld Together dedicated server. Read the index before driving the server, then use the matching feature file as the recipe.

## Baseline preconditions

- Launch with `.cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 launch` so the data directory is a new folder under `.verify-runs`.
- The harness binds `127.0.0.1` and turns server-browser discovery and telemetry off.
- Run `doctor` and require version `26.11.2.1 (5)`, the listen line, and the recorded pid.
- Never type commands into a server this run did not start.

## Driving conventions

- Start every recipe from the baseline state unless its preconditions say otherwise.
- Pass console lines through `rtserver-verify.ps1 send`.
- Treat command prefixes and log substrings as literal.
- Copy proof with `rtserver-verify.ps1 evidence -Feature <id>` before cleanup.
- Do not delete the evidence directory during cleanup.

## Proof and skip reporting

- Capture the command and the resulting system-log line, plus any file the command writes.
- Record the feature id in the evidence directory name.
- Report an unreachable path with the attempted command and the unmet precondition.
- Do not report a skipped entry point as verified through a different path. Showing zero connected players does not prove the connected-player list.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the operator-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with rtserver-verify.ps1`
4. `Gotchas`

## Features

- [Command help](./help.md) lists console commands.
- [Connected players](./list.md) shows who is connected. A populated list needs a RimWorld client this harness does not start.
- [Server chat](./chat.md) sends a console chat line and appends it to the chat log.
- [Join password](./password.md) sets and clears the password hash in `PasswordConfig.json`.
- [Server version](./version.md) prints the executable version.
