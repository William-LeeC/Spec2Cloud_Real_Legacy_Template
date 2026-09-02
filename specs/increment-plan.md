# Increment Plan — Custom FiveM Roleplay Server

Per this project's "walking skeleton first" principle: prove the
architecture end-to-end with minimal content before adding gameplay
variety. Only Increment 1 is concretely scoped right now — it's the only
one with approved FRDs. Increments 2+ are placeholders reflecting the
PRD's stated roadmap and will be planned for real once their FRDs exist.

## Increment 1: Economic Foundation

- **ID:** `economic-foundation`
- **Scope:**
  - Custom framework bootstrap on `ox_lib` / `oxmysql` / `ox_target`
  - Database schema and connection (MariaDB via `oxmysql`)
  - Player identification and single-character session lifecycle (connect → load → save → disconnect)
  - Dual-balance (cash + bank) currency system with atomic, persistent transactions
  - Admin balance-adjustment command and a temporary `/testpay` verification hook
  - Azure VM provisioning (FXServer + txAdmin + co-located MariaDB), NSG, networking
  - Icarus anti-cheat installed (day-one requirement)
- **FRD scope:**
  - `specs/frd-core-framework.md` (full)
  - `specs/frd-currency-system.md` (full)
- **Screens:** None — this product has no web/app screens; player-facing surface is in-game HUD/notifications via `ox_lib` (balance display, per `frd-currency-system.md` FR5).
- **Depends on:** none (this is the walking skeleton)
- **Complexity:** medium
- **Definition of done:** A player can connect to the deployed Azure VM server, have a character created and persisted, earn and spend money via the test/admin commands, and have that balance survive a reconnect and a server restart. No job content exists yet — that's Increment 2.

## Increment 2: Job Variety (placeholder — not yet scoped)

- **ID:** `job-variety`
- **Scope (per PRD roadmap, not yet broken into FRDs):** Multiple job types that pay into the Increment 1 currency system; salary/pay balancing; likely the first real use of the `job` field and job-registration contract reserved in `frd-core-framework.md` FR7.
- **FRD scope:** None yet — to be written once Increment 1 ships and job types are decided (per the PRD's explicit deferral).
- **Depends on:** `economic-foundation`
- **Complexity:** TBD
- **Status:** Not planned in detail — placeholder only, per the PRD's Out of Scope section.

## Increment 3+: Deferred (not yet scoped)

Per the PRD, the following are acknowledged future directions but have no
committed scope, FRDs, or ordering yet: factions/gangs, server theme and
signature mechanics, monetization, multi-character slots, custom
map/MLOs, Discord community integration. These will be planned when the
product owner is ready to decide them — see `specs/prd.md`'s "Out of
Scope / Deferred Decisions" section.

## Dependency Graph

```
economic-foundation
        │
        ▼
   job-variety
        │
        ▼
  (increment 3+, unscoped)
```

No circular dependencies. No parallelism opportunity yet — increments are
strictly sequential because each depends on the currency/framework
contract the previous one established.
