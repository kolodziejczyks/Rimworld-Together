# Command help

Command help prints every console command prefix and description.

## Sub-features

- `help-list` prints the command inventory, including `help`, `list`, `chat`, `setpassword`, `clearpassword`, `getversion`, and `quit`.

## How to get to it (user POV)

- Type `help` at the server console.

## Driving it with rtserver-verify.ps1

Preconditions:

- `doctor` has passed for this instance.
- The system log already contains `Type 'help' to get a list of available commands`.

- **Ask for help.** Type `help`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "help" -Expect "List of available commands:"`. The system log then contains `help - Shows a list of all available commands to use`, `list - Shows all connected players`, `chat - Send a message in chat from the Server`, `setpassword - Sets the password to join this server. Leave empty for reset`, and `quit - Quits the server`.
- **Proof.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 evidence -Feature help`. `system-log.txt` contains the header and those prefixes.

## Gotchas

- The bracketed count on the header changes when a command is added. Assert the prefixes above, not the number.
- `help` is also the startup hint. A startup line `Type 'help' to get a list of available commands` is not the inventory. The inventory line is `List of available commands:`.
- In-game `/help` is a chat command (`CMD_Help` under `Commands/Chat`) and is not this console command.
