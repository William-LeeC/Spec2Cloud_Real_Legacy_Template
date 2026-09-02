# FRD: Core Player Framework & Persistence

**Feature ID:** `core-framework`
**Depends on:** none (foundational)
**Enables:** `frd-currency-system.md`, and every future job/faction/gameplay FRD

## Overview

This is the "blank slate" custom framework everything else is built on. It
covers server bootstrap and shared-library dependencies, the database
schema/connection foundation, and the player/character session lifecycle
(connect → identify → load → play → save → disconnect). It implements **no**
gameplay content — no jobs, no factions, no inventory. Its only job is to
make the platform functional enough for `frd-currency-system.md` (and later,
Increment 2's job resources) to build on.

## Actors

- **Player** — connects to the server, is identified by their FiveM license,
  and has exactly one character (single-character model per the PRD).
- **Server Admin** — needs confidence the framework is healthy (e.g. a way
  to confirm a given player's character data loaded correctly).
- **Other server resources (future)** — the currency system, and later job
  resources, consume this FRD's exports/events rather than touching the
  database directly.

## Functional Requirements

**FR1 — Standard Library Bootstrap**
The server resource declares `ox_lib`, `oxmysql`, and `ox_target` as
dependencies. All future gameplay resources build on these rather than
reimplementing UI, database access, or targeting/interaction primitives.

**FR2 — Database Schema & Connection**
A MySQL/MariaDB-compatible `characters` table exists (see Data Requirements
below). All database access goes through `oxmysql` exclusively — no other
resource opens its own DB connection.

**FR3 — Player Identification**
On connect, the framework resolves the player's FiveM `license:` identifier.
If none is available, the connection is rejected cleanly with a clear
client-facing reason (see Error Handling).

**FR4 — Character Load**
On successful identification, the framework loads the player's existing
character row, or creates one with default values if this is their first
connection.

**FR5 — Character Save**
Character data is saved: (a) on a configurable interval (default: every 5
minutes), (b) immediately on disconnect, and (c) immediately after any
balance-changing transaction (per `frd-currency-system.md`). Each save is
atomic per character row.

**FR6 — Session State API**
The framework exposes a server-side API for other resources to: fetch a
player's loaded character data, check whether a player's character has
finished loading (to prevent races), and subscribe to load/unload events.

**FR7 — Job-Extensibility Placeholder**
The character record includes a `job` field (default `"unemployed"`) and the
framework reserves an event contract for a future job resource to update it.
No job logic is implemented here — this FR only guarantees Increment 2 won't
require a breaking schema change.

## Acceptance Criteria

**AC1 — First connection creates a character**
Given a player with a valid FiveM license identifier connects for the first time
When the framework processes their connection
Then a new character row is created with default cash/bank values and the player is marked "loaded"

**AC2 — Returning player loads existing data**
Given a returning player with an existing character connects
When the framework processes their connection
Then their existing cash, bank, and job values are loaded exactly as last saved

**AC3 — Changes persist within policy**
Given a loaded player's character data changes
When the change occurs
Then the updated value is persisted to the database per the FR5 save policy

**AC4 — Survives restart**
Given the server restarts or crashes unexpectedly
When a previously-connected player reconnects
Then their character data reflects the last successfully saved state

**AC5 — Race protection**
Given another resource calls the session API before a player's character has finished loading
When it requests character data
Then the API returns an explicit "not loaded yet" result — never nil or a partial record

**AC6 — Missing identifier is rejected clearly**
Given a player has no valid license identifier
When they attempt to connect
Then the connection is rejected with a clear, human-readable reason, not a silent drop

## Edge Cases

- Player disconnects mid-creation, before their new character row is
  inserted — must not leave a partial/corrupt row or break subsequent
  connect attempts.
- Two rapid reconnects from the same identifier in quick succession (client
  crash + immediate rejoin) — must not create duplicate rows or race on load.
- Database is unavailable at server start or drops mid-session — must
  surface the failure to admins (console/log) and to affected players
  (clear message), never silently proceed with a broken/unloaded character.
- Planned server shutdown while players are connected — must save all
  connected characters before shutdown completes.

## Error Handling

| Failure | System Behavior | Player-Facing Message | Retry? |
|---|---|---|---|
| No license identifier | Reject connection | "Unable to verify your account. Please restart FiveM and try again." | No — user action required |
| DB unreachable at connect | Reject connection (no phantom in-memory-only character) | "Server is temporarily unavailable. Please try again shortly." | Yes |
| DB write fails during save | Retry once immediately; if it fails again, log critical and keep in-memory state authoritative | None immediately; warn if persistent | Yes — automatic, then alert |
| Duplicate character row for one identifier | Load most recently updated row; log a critical inconsistency for admin review | None | No — admin follow-up |

## Data Requirements (Schema)

```sql
CREATE TABLE IF NOT EXISTS characters (
  identifier   VARCHAR(60)  NOT NULL PRIMARY KEY,        -- FiveM license identifier
  name         VARCHAR(60)  NOT NULL DEFAULT 'Unknown',
  cash         INT          NOT NULL DEFAULT 0,
  bank         INT          NOT NULL DEFAULT 0,
  job          VARCHAR(50)  NOT NULL DEFAULT 'unemployed', -- placeholder for Increment 2
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

Exact types/constraints and default starting cash/bank values are subject to
confirmation during Tech Stack Resolution (see PRD Open Questions).

## Server API (Exports) — Contract for Future Resources

- `GetCharacter(playerId) -> table | nil`
- `IsCharacterLoaded(playerId) -> boolean`
- Event `framework:characterLoaded` (server) — fired once a character finishes loading
- Event `framework:characterUnloaded` (server) — fired on disconnect, after the final save completes

## Non-Functional Requirements

- Character load should complete within ~2s of connection under normal DB
  load (target, to be confirmed during tech-stack resolution).
- No raw SQL string concatenation anywhere — `oxmysql` parameterized queries only.
- Structured logging (resource, identifier, action, result) for all
  connect/load/save events, without leaking sensitive data into
  player-facing output.

## Out of Scope

- Multi-character slots / character selection screen
- Any job, faction, or gameplay content
- Inventory, vehicles, housing, phone
- Anti-cheat implementation (separate tech-stack/infra concern)
