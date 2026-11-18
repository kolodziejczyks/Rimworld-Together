------------------------------ MODULE MarketBuy ------------------------------
\* Model of PM_Market.OnBuy when two buyers' listener tasks interleave.
\* One step here is one step in that method:
\*   lookup  = Entries.FirstOrDefault, outside FL_Market's semaphore
\*   remove  = FL_Market.RemoveEntry (semaphore covers only List.Remove)
\*   pay     = GiveMoneyToSeller, which OnBuy calls even if this caller
\*             removed nothing
EXTENDS Integers

CONSTANTS Buyers

VARIABLES listing, paid, pc

vars == <<listing, paid, pc>>

Init ==
    /\ listing = TRUE
    /\ paid = 0
    /\ pc = [b \in Buyers |-> "lookup"]

Lookup(b) ==
    /\ pc[b] = "lookup"
    /\ IF listing
       THEN pc' = [pc EXCEPT ![b] = "remove"]
       ELSE pc' = [pc EXCEPT ![b] = "done"]
    /\ UNCHANGED <<listing, paid>>

Remove(b) ==
    /\ pc[b] = "remove"
    /\ listing' = FALSE
    /\ pc' = [pc EXCEPT ![b] = "pay"]
    /\ UNCHANGED paid

Pay(b) ==
    /\ pc[b] = "pay"
    /\ paid' = paid + 1
    /\ pc' = [pc EXCEPT ![b] = "done"]
    /\ UNCHANGED listing

Next == \E b \in Buyers : Lookup(b) \/ Remove(b) \/ Pay(b)

Spec == Init /\ [][Next]_vars

SoldAtMostOnce == paid <= 1

=============================================================================
