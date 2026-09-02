# ADR-003: Icarus as the Launch Anti-Cheat, With a Paid Upgrade Path Reserved

## Status

accepted

## Date

2026-09-02

## Context

The PRD treats admin/anti-cheat tooling as essential from day one, not an
afterthought (direct product decision). Cfx.re (the FiveM platform operator)
deliberately leaves cheat detection to individual server owners rather than
providing it natively, so a third-party or custom anti-cheat resource is
standard practice for any public-facing server. This is a security-relevant
architectural decision worth recording per this project's ADR policy.

A web search of the current (2026) FiveM anti-cheat landscape found both
free and paid credible options; see References.

## Options Considered

### Option 1: Icarus (free, standalone)

A free anti-cheat resource marketed specifically toward FiveM roleplay
servers, with a range of detections.

- **Pros**: No cost, RP-focused (matches this project's genre), standalone (no framework dependency, consistent with ADR-002's custom-framework decision).
- **Cons**: Free tools generally lag paid ones on update cadence against new cheat techniques; smaller support surface than a paid vendor.
- **Risk**: Moderate — free anti-cheats can go stale if maintenance lapses; needs periodic re-evaluation.
- **Cost**: None.

### Option 2: WaveShield (paid)

A widely-adopted paid anti-cheat (15,000+ servers per vendor marketing, ~99.9% claimed detection).

- **Pros**: Large install base, frequent updates, dedicated vendor support.
- **Cons**: Recurring cost with no revenue yet (monetization plan is explicitly undecided per the PRD) — spending on a paid anti-cheat before the server has players or a funding model is premature.
- **Risk**: Low technical risk, but a budget commitment ahead of any validated need.
- **Cost**: Ongoing subscription (moderate-to-high depending on tier).

### Option 3: FiveGuard (paid)

A well-known paid anti-cheat (~45 EUR/month or ~125 EUR lifetime per vendor pricing).

- **Pros**: Established reputation, one-time lifetime pricing option.
- **Cons**: Same premature-spend concern as Option 2 given the undecided monetization plan.
- **Risk**: Low technical risk, budget-timing risk only.
- **Cost**: Recurring or one-time fee.

### Option 4: Build a custom anti-cheat

Consistent with ADR-002's "custom" theme, write detection logic in-house.

- **Pros**: Full control, no vendor dependency.
- **Cons**: Anti-cheat is an adversarial, continuously-evolving problem; building and maintaining detections in-house is a large, ongoing effort disproportionate to a first server with no player base yet.
- **Risk**: High — a custom anti-cheat with a small team is very likely to lag behind known cheat techniques.
- **Cost**: Highest — ongoing engineering effort with no ecosystem leverage.

## Decision

We will launch with **Icarus** (free, standalone, RP-focused) for Increment
1. This satisfies the "essential from day one" requirement at zero cost
while the server has no players and no monetization plan yet. We will
revisit this decision (WaveShield or FiveGuard are the leading paid
candidates) once the server has real player traffic or a funding model,
rather than pre-committing budget now.

## Consequences

### Positive

- Meets the day-one anti-cheat requirement without a budget commitment ahead of any validated need.
- RP-focused detection set matches the project's genre (ADR/PRD: Roleplay).

### Negative

- Likely to need re-evaluation as the server grows — this is an explicitly deferred decision, not a permanent one.
- Smaller vendor support surface than a paid option if a novel cheat technique emerges.

### Neutral

- Swapping anti-cheat resources later does not affect the character/currency data model (`frd-core-framework.md`, `frd-currency-system.md`) — this is an isolated, replaceable component.

## References

- `specs/prd.md` — Non-Functional Requirements (admin/anti-cheat priority)
- Web search, September 2026: FiveM anti-cheat landscape (Icarus, FireAC, Badger Anticheat as free options; FiveGuard, WaveShield, FiniAC, Electron as paid options) — vendor marketing claims (detection rates, install counts) are self-reported and not independently verified; re-confirm before any paid commitment.
