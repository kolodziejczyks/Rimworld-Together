# Join password

The join password is set or cleared from the console. The stored value is a hash, not the word the operator typed.

## Sub-features

- `password-set` writes the SHA-256 of the new password and prints `Password has been changed`.
- `password-clear` writes an empty password and prints `Password has been cleared`.

## How to get to it (user POV)

- Type `setpassword <word>` at the server console.
- Type `clearpassword` at the server console.

## Driving it with rtserver-verify.ps1

Preconditions:

- `doctor` has passed for this instance.
- `Configs/PasswordConfig.json` exists. Launch creates it. Its `Password` field may be empty.

- **Set.** Type `setpassword secret`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "setpassword secret" -Expect "Password has been changed"`. The system log contains `Password has been changed`.
- **Confirm the hash.** Read `Configs/PasswordConfig.json`. `Password` is `2BB80D537B1DA3E38BD30361AA855686BDE0EACD7162FEF6A25FE97BF527A25B`, the uppercase hex SHA-256 of the ASCII string `secret`. It must not be the word `secret`.
- **Clear.** Type `clearpassword`. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 send -CommandText "clearpassword" -Expect "Password has been cleared"`. The system log contains `Password has been cleared` and `Password` in `PasswordConfig.json` is `""`.
- **Proof.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-rtserver/scripts/rtserver-verify.ps1 evidence -Feature password` after the set, and again after the clear if the cleared file is the state you need to keep. The copy is a snapshot of the file at evidence time. Take evidence after set, before clear, when the proof is the hash.

## Gotchas

- `setpassword` requires exactly one parameter. `setpassword secret word` logs `Wrong parameter count for 'setpassword'` and does not change the file.
- `setpassword` with an empty argument is not the clear path. Clear with `clearpassword`, which logs `Password has been cleared`.
- The console line is not the proof of persistence. Read `PasswordConfig.json` after the command.
