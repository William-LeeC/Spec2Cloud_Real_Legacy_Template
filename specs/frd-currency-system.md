# FRD: Currency System (Cash & Bank)

**Feature ID:** `currency-system`
**Depends on:** `frd-core-framework.md` (character load/save API, DB schema, session events)
**Enables:** all future job/economy FRDs (Increment 2+)

## Overview

The persistent, dual-balance (cash + bank) currency system that Increment
2's job resources will pay into. This FRD does **not** implement any job,
paycheck, or income-generating gameplay — it only builds the safe,
atomic transaction primitives and proves the earn → persist → reload loop
works end-to-end, using a temporary test command in place of a real job.

## Actors

- **Player** — holds cash and bank balances; can be paid or charged by other resources.
- **Server Admin** — can adjust a player's balance for support purposes (e.g. correcting a bug-caused loss).
- **Other resources (future)** — job, shop, and economy resources not built in this FRD, but which will call this FRD's exported API.

## Functional Requirements

**FR1 — Dual Balance Model**
Each character has two independent, non-negative integer balances: `cash`
(physical, on-hand) and `bank` (digital, in an account). No fractional units.

**FR2 — Transaction Primitives**
Exposed atomic operations: `AddCash`, `RemoveCash`, `AddBank`, `RemoveBank`,
`Transfer` (cash→bank or bank→cash). Every mutating operation is atomic
against concurrent calls for the same character — no lost updates.

**FR3 — Insufficient Funds Protection**
`RemoveCash` / `RemoveBank` / `Transfer` fail cleanly (return false) if the
result would go negative. A balance must never go below zero.

**FR4 — Persistence**
Every balance-changing operation immediately triggers a save of the
affected character's `cash`/`bank` fields (via `frd-core-framework.md` FR5),
so a crash immediately after a transaction loses at most that one in-flight
write.

**FR5 — Balance Display**
Players can see their current cash and bank balance in-game via an
`ox_lib`-based UI element (HUD element or a command showing both balances).

**FR6 — Starting Balance**
New characters are created with a configurable starting cash/bank amount
(not hardcoded — a config value). Exact default is TBD; recommend a small
placeholder (e.g. 500 cash / 0 bank) pending confirmation.

**FR7 — Admin Adjustment Command**
A permission-gated admin command adds/removes cash or bank for a specified
online player, for support/testing. Every use is logged (admin identifier,
target, amount, reason).

**FR8 — Test/Verification Hook (Walking Skeleton Proof)**
Since no real job exists yet, a minimal admin/dev-only command (e.g.
`/testpay <amount>`) exercises the full earn → persist → reconnect → verify
loop, proving the architecture end-to-end. This is temporary scaffolding —
expected to be removed or locked down once Increment 2 delivers real jobs.

## Acceptance Criteria

**AC1 — Basic add**
Given a loaded character with cash = 100
When `AddCash(50)` is called
Then their cash becomes 150 and the new value is persisted

**AC2 — Insufficient funds rejected**
Given a loaded character with bank = 200
When `RemoveBank(300)` is called
Then the operation fails, the balance remains 200, and the caller receives an explicit failure result

**AC3 — Atomic transfer**
Given a loaded character with cash = 100
When `Transfer(cashToBank, 100)` is called
Then cash becomes 0 and bank increases by 100 as a single atomic operation — never a state where one side applied without the other

**AC4 — Concurrent calls don't lose updates**
Given two concurrent calls modify the same character's cash near-simultaneously (e.g. `AddCash(10)` and `RemoveCash(5)`)
When both are processed
Then the final balance reflects both operations correctly — sequenced, not overwritten

**AC5 — Test command proves persistence**
Given a player runs `/testpay 50`
When it executes
Then their cash increases by 50, persists to the database, and survives a reconnect

**AC6 — Admin adjustment is audited**
Given an admin runs the balance-adjustment command on an online player
When it completes
Then the target's balance updates, persists, and an audit log line records admin id, target, amount, and reason

## Edge Cases

- A balance-changing call arrives for a character that hasn't finished
  loading yet (race with `frd-core-framework.md`'s load flow) — must be
  rejected, never applied to a partially-initialized record.
- Transfer amount of 0 — a no-op that still returns success, not an error.
- Extremely large or malformed transaction amount (e.g. an exploited
  client sending a bogus value) — validated server-side; never trust a
  client-supplied amount without a sanity check.
- Admin adjustment targeting an offline player — **out of scope for
  Increment 1** (online players only); document this limitation explicitly.
- Rapid repeated calls to `/testpay` — must go through the same
  insufficient-funds/validation logic as any real transaction, no bypass.

## Error Handling

| Failure | System Behavior | Player-Facing Message | Retry? |
|---|---|---|---|
| Insufficient funds for Remove/Transfer | Reject, no state change | "You don't have enough cash / money in your bank." | Yes |
| Operation called on unloaded character | Reject, log warning | Silent (integration bug, not a player error) | No — developer fix required |
| DB save fails after a successful in-memory transaction | Retry once; if still failing, log critical, keep in-memory value authoritative until next successful save | None immediate | Yes — automatic |
| Negative or non-numeric amount passed to Add/Remove | Reject at the API boundary before any mutation | N/A | No |

## API Contract (Exports) — For Future Job/Economy Resources

- `AddCash(playerId, amount) -> boolean`
- `RemoveCash(playerId, amount) -> boolean`
- `AddBank(playerId, amount) -> boolean`
- `RemoveBank(playerId, amount) -> boolean`
- `Transfer(playerId, direction, amount) -> boolean` — `direction` is `"cashToBank"` or `"bankToCash"`
- `GetBalances(playerId) -> { cash: number, bank: number }`
- Event `currency:balanceChanged` (server, forwarded to the owning client) — payload `{ cash, bank, reason }`, so future UI/HUD and job resources can react without polling

## Non-Functional Requirements

- All transaction functions must be safe to call from any other
  server-side resource — this is the primary integration point Increment
  2's job variety will use, and must be usable by a future job-resource
  author without reading this FRD's internals.
- No interleaving of concurrent calls may ever produce a negative balance.
- Test/admin commands (FR7, FR8) must be permission-gated (ACE
  permissions) so regular players cannot access them.

## Out of Scope

- Any real job, paycheck, or income-generating gameplay loop (Increment 2+)
- Player-to-player trading/giving money
- Robbery/theft mechanics
- Interest, taxes, or bank fees
- Offline player balance adjustment
