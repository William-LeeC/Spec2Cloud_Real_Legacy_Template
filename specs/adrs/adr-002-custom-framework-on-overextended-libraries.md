# ADR-002: Custom Gameplay Framework Built on Overextended's Low-Level Libraries

## Status

accepted

## Date

2026-09-02

## Context

Every FiveM roleplay server needs a "framework" layer that owns character
data, jobs, and cross-resource conventions. The overwhelming majority of RP
servers adopt an existing framework (QBCore, its actively-maintained fork
QBox, or ESX Legacy) rather than building one, because these frameworks ship
with a mature character/inventory/economy foundation and a huge ecosystem of
compatible community resources.

This project's owner explicitly wants custom-designed gameplay and economy
conventions rather than adopting QBCore/QBox/ESX's conventions, while
acknowledging (via direct discussion) that reinventing low-level plumbing
that every framework already depends on — async database access, UI
primitives, world-interaction targeting — would be wasted effort with no
gameplay benefit.

## Options Considered

### Option 1: Fully from scratch (no shared libraries at all)

Write character/session management, database access, UI, and interaction
targeting entirely in-house.

- **Pros**: Maximum control, zero external dependency risk.
- **Cons**: Reimplements solved problems (async MySQL wrappers, notification/menu UI, "third-eye" targeting) with no gameplay differentiation to show for it. Steep first-server learning curve compounds with a first-server team.
- **Risk**: High — most first-server build time would go to plumbing, not the gameplay this team actually wants to design.
- **Cost**: Highest — largest build surface, longest time to a playable server.

### Option 2: Adopt QBox (or QBCore/ESX) wholesale

Build the server on top of an existing framework's conventions.

- **Pros**: Fastest path to a playable server; huge tutorial/resource ecosystem; battle-tested economy/inventory/job patterns.
- **Cons**: Directly conflicts with the stated goal of custom-designed jobs/economy conventions; server would inherit QBox's data model and idioms rather than the team's own design.
- **Risk**: Low technical risk, but doesn't meet the actual product goal.
- **Cost**: Lowest build cost, but wrong trade-off given the explicit goal.

### Option 3: Custom gameplay/economy conventions built on Overextended's standard low-level libraries (`ox_lib`, `oxmysql`, `ox_target`)

Design our own character/currency/job model and conventions, but use the
same foundational libraries QBox, and increasingly the rest of the FiveM
ecosystem, already rely on for database access, UI, and interaction
targeting.

- **Pros**: Avoids reinventing solved infrastructure problems; `oxmysql` and `ox_lib` are actively maintained, well-documented (see `specs/tech-stack.md` for current status), and framework-agnostic — using them does not pull in QBox/QBCore/ESX conventions. Leaves 100% of the actual gameplay/economy/job design as custom, first-party work.
- **Cons**: Still requires building the character/session/currency layer this project's two FRDs describe — this is "custom" work, not free.
- **Risk**: Low — these libraries are widely depended upon (including by QBox itself), so their long-term maintenance risk is shared with a large part of the ecosystem.
- **Cost**: Moderate — meaningfully less than Option 1, more than Option 2, but the only option that satisfies the actual product goal.

## Decision

We will build a custom framework: our own character/session/currency data
model and conventions (as specified in `specs/frd-core-framework.md` and
`specs/frd-currency-system.md`), implemented on top of `ox_lib`, `oxmysql`,
and `ox_target` rather than reimplementing that plumbing or adopting
QBCore/QBox/ESX's gameplay conventions wholesale.

## Consequences

### Positive

- All gameplay/economy design stays fully custom, meeting the stated product goal.
- Async DB access, UI, and interaction targeting are handled by widely-used, actively-maintained libraries instead of first-party code that would need the same hardening QBox/QBCore/ESX have already accumulated over years of production use.

### Negative

- Unlike Option 2, there is no pre-built job/economy content to start from — every job in Increment 2+ is first-party work with no community resource to drop in.
- Community tutorials assume a framework (QBCore/QBox/ESX); this project's team will need to adapt guidance rather than follow it literally.

### Neutral

- This decision does not preclude selectively adopting individual community resources later (e.g. `ox_inventory` for inventory) if they prove compatible with the custom data model — that would be a future ADR if/when it comes up.

## References

- `specs/frd-core-framework.md` — the resulting character/session framework
- `specs/frd-currency-system.md` — the resulting currency system
- `specs/tech-stack.md` — Backend Libraries section, `ox_lib`/`oxmysql`/`ox_target` details
