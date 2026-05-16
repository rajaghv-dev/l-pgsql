# Solutions — Transactions and Isolation Levels

**Status: blocked — Docker not accessible in this session**

---

## Exercise 1 solution
Session B uses READ COMMITTED (the default). Under READ COMMITTED, each statement acquires a fresh snapshot. Because Alice's UPDATE had not committed when Session B ran its SELECT, the snapshot didn't include it. After COMMIT, the next SELECT sees the updated value.

Key insight: READ COMMITTED re-takes the snapshot per statement, not per transaction.

---

## Exercise 2 solution
This is a **non-repeatable read**. The same query within one transaction returns a different value because Session A committed between the two reads. Under READ COMMITTED this is expected and allowed. Use REPEATABLE READ to prevent it.

---

## Exercise 3 solution

**READ COMMITTED:** Session B's second COUNT returns 3 because its snapshot was refreshed at the start of the second statement, after Session A's INSERT committed. The new row (Frank) is now visible — a phantom read.

**SERIALIZABLE:** Session B holds its snapshot from the first statement. Frank's row is either invisible (consistent snapshot) or the transaction is aborted with:
```
ERROR:  could not serialize access due to read/write dependencies among transactions
DETAIL:  Process ... waits for ... ; Process ... waits for ...
HINT:   The transaction might succeed if retried.
SQLSTATE: 40001
```
Application code must catch `SQLSTATE 40001` and retry the whole transaction.

---

## Exercise 4 solution
After `ROLLBACK TO SAVEPOINT after_alice`:
- Alice's balance = original - 50 (held)
- Bob's balance = original (Bob's deduction was rolled back)

The outer transaction is still open. `COMMIT` will persist Alice's deduction only.

Savepoints are useful for retry logic within a transaction (e.g., try an INSERT, catch unique violation, update instead) without aborting the entire transaction.

---

## Exercise 5 solution
Correct transfer pattern elements:
1. **REPEATABLE READ** — snapshot doesn't shift mid-transaction
2. **FOR UPDATE** — row-level lock prevents concurrent modifications
3. **ORDER BY id** — always lock lower-id first to prevent deadlock when two concurrent transfers run in opposite directions
4. **Insert into transfers** — audit trail within the same atomic transaction

If Charlie tries to transfer from Alice simultaneously:
- First transaction locks id=1 (Alice), then id=2 (Bob)
- Second transaction also tries to lock id=1 (Alice) first — it blocks
- No deadlock because lock order is consistent

---

## Exercise 6 solution
All three syntax options are equivalent for setting isolation level. `READ ONLY` additionally prevents any data-modifying statements in the transaction — useful for reporting sessions that should never accidentally mutate data.

`pg_default_transaction_isolation` GUC controls the default; most deployments leave it at `read committed`.

---

## Reference table: anomaly behavior by level

| Anomaly | READ COMMITTED | REPEATABLE READ | SERIALIZABLE |
|---|---|---|---|
| Dirty read | Never | Never | Never |
| Non-repeatable read | Possible | Never | Never |
| Phantom read | Possible | Never* | Never |
| Serialization anomaly | Possible | Possible | Never (aborts) |

*PostgreSQL's REPEATABLE READ is stronger than SQL standard requires.
