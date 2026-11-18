---
name: verify-rtserver
description: Drive the RimWorld Together dedicated server console (RTServer) and prove operator commands against the system log, chat log, and config files. Use when changing server startup, console commands, the join password, or chat logging. The RimWorld game client is a separate surface and is not driven here.
---

# Verify RTServer

The driveable surface in this repo is the dedicated server console. Players use the RimWorld mod UI, which needs the game and is not launched by this skill. Operator commands are typed into the server process. The same lines are appended to `Logs/System/<yyyy-MM-dd>.txt` under the data directory before they are written to the console.

This harness starts one server, in a disposable data directory, bound to `127.0.0.1` on a free port at or above `25556`. It refuses to launch a second instance while that process is alive. Two servers can bind different ports, but this harness drives only the process it started.

## Launch

From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 launch
```

Launch builds `Source/Server/RTServer.csproj` in Debug when `Source/Server/bin/Debug/net10.0/RTServer.dll` is missing. It uses `.verify-tools/dotnet/dotnet.exe` when that file exists, otherwise `dotnet` on `PATH`. If neither is a .NET 10 SDK, install one into the repo tools directory (do not install it machine-wide from this skill):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .verify-tools/dotnet-install.ps1 -Channel 10.0 -InstallDir .verify-tools/dotnet
```

The install script is the official `https://dot.net/v1/dotnet-install.ps1` saved at that path. If it is missing, download it there first.

Launch writes `Configs/ServerConfig.json` before the process starts, with `IP` `127.0.0.1`, `UseUPnP` false, `EnableServerBrowser` false, and `EnableServerTelemetry` false. `CommonValues.ExecutableVersion` is the constant `26.11.2.1`, so those flags are kept. A build whose version constant equals `dev` forces telemetry and the public browser back on inside `Program.LoadFiles`, and that build is not what this harness drives.

Ready means the system log contains `Type 'help' to get a list of available commands` and `Listening for users at 127.0.0.1:<port>`. The command loop is `CMD_Base.ListenForCommands`, which reads stdin only when `Console.In.Peek()` does not throw and does not return end-of-stream. The supervisor keeps that stdin open. Stdout is not redirected: a redirected console buffer fills during startup and the process blocks inside `Console.WriteLine` before `pid.txt` is written. The system log is the transcript, and it receives the same lines.

Teardown is `cleanup` below. `quit` calls `Environment.Exit(0)`.

## Doctor

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 doctor
```

Doctor is read-only. It passes only when all of these are true:

- `.verify-runs/current.txt` names an instance this harness launched
- that instance's server pid and supervisor pid are both running
- `127.0.0.1:<port>` is in the Listen state and the owning process is that server pid
- the system log contains `Server version 26.11.2.1 (5)` and `Listening for users at 127.0.0.1:<port>`

Run doctor before driving whenever the console looks idle or a command produces no log line.

## Drive

Console commands are one line each. The prefix is the first word, lowercased. `CMD_Base.ParseCommand` requires the parameter count to match, except a command whose `ParameterCount` is `0` or `-1`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send --% <command line>
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "<command line>" -Expect "<log substring>"
```

`--%` stops PowerShell from parsing the rest of the line, which is how a command such as `help` is passed through. `-Expect` waits until that substring appears in the system log after the send.

Stable handles are the command prefixes and the log lines in the feature map, not screen coordinates. Read the feature file before driving. A journey that needs a connected RimWorld client reports a failure; do not replace it with an empty-server observation and call it the same proof.

## Evidence

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 evidence -Feature <feature-id>
```

Evidence is copied to `.cursor/skills/verify-rtserver/evidence/<instance-id>/<feature-id>/`. That directory is not deleted by cleanup.

Proof standards:

- Exercise the console command a server operator types. Do not call `PM_ServerPassword.SetPassword` or any other method in-process.
- Capture the command and the resulting system-log line, not only a later file.
- For a change that writes a file, copy that file into the evidence directory and check its contents. A log line alone is not persistence proof.
- The join password is stored as the uppercase hex SHA-256 of the ASCII password (`Hasher.GetHashFromString`). `secret` is `2BB80D537B1DA3E38BD30361AA855686BDE0EACD7162FEF6A25FE97BF527A25B`.
- There is no dry-run mode. `EnableServerBrowser` and `EnableServerTelemetry` false are real settings: doctor fails if the log says the server is being transmitted to the public browser.

## Cleanup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 cleanup
```

Cleanup sends `quit` to the instance this harness started, waits for that pid to exit, and only then `Stop-Process` on that pid if it is still alive. It also stops the supervisor pid recorded in `instance.json`. It deletes `.verify-runs/<id>` and `.verify-runs/current.txt`. It does not delete `.cursor/skills/verify-rtserver/evidence`. Do not stop processes by the name `dotnet` or `RTServer`.

## Helpers

- `.cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1` is the entry point. Actions are `launch`, `doctor`, `send`, `evidence`, and `cleanup`.
- `.cursor/skills/verify-rtserver/scripts/rtserver-supervisor.ps1` is started by `launch`. It owns the server process and forwards `queue/*.cmd` files to stdin. Do not start it yourself.

## Feature map

Read `.cursor/skills/verify-rtserver/features/README.md` before choosing a journey.
