---
name: verify-market-sale
description: Check that a RimWorld Together market listing is credited to its seller at most once when two buyers purchase it together. Use when changing PM_Market.OnBuy, GiveMoneyToSeller, FL_Market.RemoveEntry, or the per-client listener task.
---

# Market sale is credited once

A market listing is credited to its seller at most once. If that fails, two players can both be told they bought the same listing and the seller's pending payment increases twice.

The check is a TLA+ model of `PM_Market.OnBuy`, explored with TLC. Read every TLC result with `/statechart`. Do not copy `/statechart` flags or paths into this skill; they change between releases.

## When a change touches this

Re-read the model against the code when any of these change:

- `Source/Server/PacketManagers/PM_Market.cs`, methods `OnBuy` and `GiveMoneyToSeller`
- `FL_Market.RemoveEntry` in `Source/Assemblies/RTShared.dll` (`RTShared.Files.Marketplace.FL_Market`)
- `Listener.RunAllListenerTasks` in `Source/Assemblies/RTNetwork.dll` (`RTNetwork.Components.Listener`), which starts one task per client and calls `OnRead` on that task

The assemblies are binaries. Decompile those two methods before deciding the model still matches. Move the sync commit below forward only after that comparison says the model still describes the code at the new commit.

Sync commit: `37852e3145b53c74baea6a13d23f27da72d4e941`

At that commit, `OnBuy` looks up the listing with `Entries.FirstOrDefault` outside `FL_Market`'s semaphore, then calls `RemoveEntry`, then calls `GiveMoneyToSeller` once. `RemoveEntry` holds the semaphore only around `List.Remove` and `OnBuy` ignores whether this caller removed the entry. Each client has its own listener task, so two buys interleave between those steps.

## Run

From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor/skills/verify-market-sale/scripts/run-market-buy.ps1
```

The script runs Java on `.verify-tools/tla/tla2tools.jar`. TLC's banner at the last confirmation was `TLC2 Version 2026.11.15.002146`. The jar was downloaded from `https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar`. Java was Eclipse Adoptium 17.0.21 (`-XX:+UseParallelGC`). If `.verify-tools/java/jdk-17.0.21+9-jre/bin/java.exe` is missing, the script uses `java` on `PATH`. A missing jar is a setup failure, not a market bug.

The run writes `.cursor/skills/verify-market-sale/runs/tlc-<timestamp>.txt` and exits with TLC's status. Exit `12` is an invariant violation. Exit `0` means `SoldAtMostOnce` held for every interleaving of the model.

## Known finding

This is a finding in the current code, not a passing check. Do not weaken `SoldAtMostOnce` or hide the gap between lookup and pay to make TLC exit `0`.

`/statechart` should show this shortest path. Buyer names `a` and `b` are the two listener tasks:

1. Both buyers are about to look up the same listing. The listing is present. `paid` is `0`.
2. Buyer `a` looks the listing up and finds it (`OnBuy`'s `FirstOrDefault`).
3. Buyer `b` looks the listing up and also finds it, before either removal.
4. Buyer `a` runs `RemoveEntry`. The listing is gone.
5. Buyer `a` runs `GiveMoneyToSeller`. `paid` is `1`.
6. Buyer `b` runs `RemoveEntry`. The list removal removes nothing. `OnBuy` still continues.
7. Buyer `b` runs `GiveMoneyToSeller`. `paid` is `2`.

Both buyers reached `done`. The seller was credited twice for one listing.

## Tell a new bug from a modeling error

- The trace above, with `paid` increasing by `1` on each `Pay` and both buyers passing `Lookup` while `listing` is still true, is the known finding.
- A trace where one `Pay` adds more than `1`, or where one buyer reaches `paid = 2` while the other is still on `lookup`, means `OnBuy` credits the seller more than once per buy, or the model was changed to do that. That is a new break. A scratch that called `GiveMoneyToSeller` twice after `RemoveEntry`, with `Pay` adding `2`, produced a 4-state trace: `a` looks up, `a` removes, `a` pays, `paid = 2`, and `b` is still on `lookup`.
- Exit `0` on this model means the model no longer has a separate lookup and pay. Re-read `OnBuy` before treating that as a fix. Update the model to a single step from lookup through `GiveMoneyToSeller` only after the code holds one lock across that whole stretch. Then a pass describes the new code. Until that re-read, a pass is a modeling error.
- A TLC parse error or a missing jar is a broken check, not a cleared listing.

## Scope

Checked: every interleaving of lookup, remove, and one pay for two buyers and one listing that starts present.

Not checked: price math in `CalculateEntryPrice`, the market cooldown, disk errors inside `RemoveEntry`, more than two buyers, `OnAdd` / `OnRemove` / `OnPayment`, or any other packet. Two buyers are enough to show the double credit; the same gap exists for more buyers. `GiveMoneyToSeller` credits either the connected seller or the saved player file, and both paths add once per call, so the model counts calls rather than which branch ran.

A close second target, not checked here, is two logins of the same username on two listener tasks in `PM_Login.RemoveOldClientSessions`.
