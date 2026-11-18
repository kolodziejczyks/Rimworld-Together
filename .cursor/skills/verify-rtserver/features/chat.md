# Server chat

Server chat sends a line as the console user and appends it to the daily chat log.

## Sub-features

- `chat-send` prints `Sent chat: '<text>'` and appends a `CONSOLE` line to `Logs/Chat/<yyyy-MM-dd>.txt`.

## How to get to it (user POV)

- Type `chat <text>` at the server console. The remainder of the line is the message.

## Driving it with rtserver-verify.ps1

Preconditions:

- `doctor` has passed for this instance.
- The chat log does not already contain `verify-chat-line`.

- **Send.** Type `chat verify-chat-line`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "chat verify-chat-line" -Expect "Sent chat: 'verify-chat-line'"`. The system log contains `Sent chat: 'verify-chat-line'`.
- **Confirm the chat log.** Open `Logs/Chat/<today>.txt` under the instance data directory. A line ends with `[CONSOLE]: verify-chat-line`.
- **Proof.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 evidence -Feature chat`. `system-log.txt` contains the sent line and `chat-log.txt` contains `[CONSOLE]: verify-chat-line`.

## Gotchas

- `chat` with no text throws inside the command and the log shows an error from `Printer.Error`, not `Sent chat:`.
- `DisplayChatInConsole` is false in the harness config, so the chat line is not also printed through `WriteChatInConsole`. The `Sent chat:` title and the chat log are the proof.
- Zero connected players still produces the log line. `SendPacketToAllClients` has nobody to notify. That does not replace the chat-log check.
