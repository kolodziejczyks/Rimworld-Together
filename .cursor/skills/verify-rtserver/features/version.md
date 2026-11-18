# Server version

The version command prints the executable version constant.

## Sub-features

- `version-print` prints `Your server version is 26.11.2.1`.

## How to get to it (user POV)

- Type `getversion` at the server console.
- Read the startup line `Server version 26.11.2.1 (5)`.

## Driving it with rtserver-verify.ps1

Preconditions:

- `doctor` has passed for this instance.

- **Startup line.** The system log from launch contains `Server version 26.11.2.1 (5)`. That line is written before the command loop.
- **Command.** Type `getversion`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "getversion" -Expect "Your server version is 26.11.2.1"`. The system log contains `Your server version is 26.11.2.1`.
- **Proof.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 evidence -Feature version`. `system-log.txt` contains both the startup line and the command line.

## Gotchas

- The startup line includes the hotfix `(5)`. The `getversion` line does not.
- `CommonValues.ExecutableVersion` is a compile-time constant. A different constant is a different build, and doctor will fail until this map is updated.
