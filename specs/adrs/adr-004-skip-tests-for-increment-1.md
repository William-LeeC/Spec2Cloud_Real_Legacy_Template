# ADR-004: Skip Automated/Manual Testing for Increment 1 (Deviation from AGENTS.md Test Discipline)

## Status

accepted

## Date

2026-09-02

## Context

`AGENTS.md` §9 ("Test Discipline Gospel") establishes tests as mandatory
proof of spec completion and treats the Tests → Contracts → Implementation
→ Verify pipeline as non-negotiable ("the phase pipeline is sacred... no
exceptions"). The product owner explicitly requested skipping Step 1
(Tests) entirely for Increment 1 (`economic-foundation`) and proceeding
directly to implementation.

Before proceeding, the trade-off was surfaced directly: `frd-currency-system.md`
covers atomic money transactions — the highest-exploit-risk code in any
RP server economy (duplication bugs, negative balances) — and skipping
tests removes the regression safety net for it, including for Increment
2's job resources which will call into this same code later. A
lightweight middle-ground (unit-testing only the transaction logic via
`busted`, skipping Gherkin/e2e ceremony) was offered as an alternative.
The product owner considered this and chose to skip testing entirely
regardless.

## Options Considered

### Option 1: Full test pipeline as AGENTS.md specifies

Gherkin scenarios, step definitions, and unit tests per Step 1, adapted to Lua/FiveM.

- **Pros**: Matches the framework's own discipline; regression safety net for the highest-risk code in the product.
- **Cons**: The framework's default test stack (Cucumber + Playwright + Vitest) doesn't map onto a FiveM Lua resource — no browser to drive, no HTTP API to hit — so this would have required inventing conventions rather than following an established pattern.
- **Rejected because:** explicitly declined by the product owner after the trade-off was explained.

### Option 2: Lightweight — unit-test only the money logic

Plain Lua unit tests (`busted`) for `AddCash`/`RemoveCash`/`Transfer`/insufficient-funds logic only; manual checklist for the connect/load/save flow.

- **Pros**: Low effort (~30–60 min), catches the specific bug class (dupes, negative balances) that matters most.
- **Cons**: Still some effort and some process the product owner wanted to avoid entirely.
- **Rejected because:** offered as a middle ground, but the product owner chose to skip testing entirely rather than this option.

### Option 3: Skip testing entirely

No automated tests, no manual verification checklist. Move straight to implementation.

- **Pros**: Fastest path to working code.
- **Cons**: No regression safety net. A bug in the transaction logic (e.g. a currency duplication exploit) will not be caught until it's discovered in a running server, potentially after Increment 2's job resources already depend on the same code paths.
- **Risk**: Explicitly accepted by the product owner.

## Decision

Increment 1 (`economic-foundation`) proceeds directly from tech-stack
resolution to implementation, with no automated tests and no manual
verification checklist. This is a deliberate, human-approved deviation
from `AGENTS.md` §9, not an oversight.

## Consequences

### Positive

- Fastest possible path to a working Increment 1.

### Negative

- No regression safety net for the currency transaction logic (the highest-risk code in this increment) or the character load/save lifecycle.
- If Increment 2's job resources introduce a regression in shared currency code, there is no automated signal to catch it — it will surface as a live bug (potentially a duplication exploit or lost player balance) instead.
- Future increments inherit no test scaffolding to build on; if testing is adopted later, it starts from zero rather than extending Increment 1's tests.

### Neutral

- This decision is scoped to Increment 1 only. It does not bind Increment 2+ — testing posture can be revisited per-increment.

## References

- `AGENTS.md` §9 — Test Discipline Gospel (the rule being deviated from)
- `specs/frd-currency-system.md` — the FRD whose acceptance criteria (AC1–AC6) are now unverified by any automated or manual process
- `specs/frd-core-framework.md` — the FRD whose acceptance criteria (AC1–AC6) are now unverified by any automated or manual process
