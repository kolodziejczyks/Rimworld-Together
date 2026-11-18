# Connected players

The connected-player list prints how many clients are in `ServerNetwork` and then each client's IP.

## Sub-features

- `list-empty` prints a zero count when nobody has joined.
- `list-player` prints the count and the IP of a connected player.

## How to get to it (user POV)

- Type `list` at the server console.

## Driving it with rtserver-verify.ps1

Preconditions:

- `doctor` has passed for this instance.
- For `list-player`, a RimWorld client is connected to this instance's `127.0.0.1` port. This harness does not start that client.

- **Empty server.** Type `list`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "list" -Expect "Connected players: [0]"`. The system log contains `Connected players: [0]` and no client IP between the two `----------------------------------------` lines that follow that count.
- **Connected player.** Type `list` after a client has joined. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "list" -Expect "Connected players: ["`. The count is at least `[1]` and a following line is that client's IP.
- **Proof.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 evidence -Feature list`. For `list-empty`, `system-log.txt` contains `Connected players: [0]`. For `list-player`, it contains the count and the IP.

## Gotchas

- `list-player` has no client harness here. Report it as not verified, with the reason that no RimWorld client is connected. Do not treat `Connected players: [0]` as proof of `list-player`.
- `deeplist` lists saved users, not the live connection table. It is a different command.
