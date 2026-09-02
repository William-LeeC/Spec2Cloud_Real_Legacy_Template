# ADR-001: Azure VM (IaaS) as the FiveM Hosting Target

## Status

accepted

## Date

2026-09-02

## Context

The product is a custom FiveM roleplay server (`specs/prd.md`). FXServer is a
stateful process that holds persistent UDP connections with players and
expects direct control over its own filesystem (resources, server.cfg,
txAdmin's data folder). The team wants to stay inside Azure (per the
project's existing tooling and MCP access) rather than move to a
game-hosting-only provider, but Azure's serverless container platform
(Container Apps) — the default target for other spec2cloud shells — does not
fit this workload.

## Options Considered

### Option 1: Azure Container Apps (the template's default target)

Run FXServer inside a container on Azure Container Apps.

- **Pros**: Consistent with this repo's other tooling; managed scaling; no OS patching.
- **Cons**: Container Apps' ingress model is HTTP/gRPC-oriented; raw UDP ingress (required for FiveM's port 30120) is not supported. Scale-to-zero would drop all player connections. No official Cfx.re container image/support path.
- **Risk**: Likely non-functional for actual gameplay traffic regardless of workaround effort.
- **Cost**: N/A — ruled out on capability grounds before cost was a factor.

### Option 2: Dedicated FiveM game-hosting provider (e.g. Zap-Hosting, Sparked Host)

Use a provider purpose-built for FiveM.

- **Pros**: Purpose-built networking, one-click txAdmin recipes, community support tuned to FiveM specifically, often cheaper at small scale.
- **Cons**: Leaves the Azure ecosystem entirely — no reuse of this project's Azure MCP tooling, no unified billing/monitoring with any future Azure resources, less infrastructure-as-code control.
- **Risk**: Vendor lock-in to a smaller provider; less familiar ops model for a team already working in Azure.
- **Cost**: Often lower at small scale, but less predictable/controllable long-term.

### Option 3: Azure VM (IaaS)

A standard Azure virtual machine running FXServer + txAdmin directly, as any dedicated FiveM host would.

- **Pros**: Full control over networking (raw UDP/TCP), matches the well-documented "install FXServer on a Linux VPS" path the entire FiveM community uses, stays inside Azure for billing/monitoring/IaC consistency, straightforward to co-locate the database (MariaDB) on the same box for Increment 1's small scale.
- **Cons**: Team owns OS patching and VM-level maintenance; no automatic scaling (scaling is vertical resize, or later horizontal via a second VM, not automatic).
- **Risk**: Misconfigured NSG rules could over-expose the VM (mitigated — see `specs/contracts/infra/resources.yaml` and `specs/tech-stack.md` for the specific rules).
- **Cost**: Predictable, pay-for-what-you-provision; can start small (burstable B-series) and resize as the player base grows, matching the PRD's "scale as it grows" capacity decision.

## Decision

We will host on a single Azure VM (IaaS) running Ubuntu Server, with FXServer,
txAdmin, and MariaDB co-located on that VM for Increment 1. This is the only
option of the three that actually supports FiveM's networking requirements
while keeping the project inside Azure.

## Consequences

### Positive

- Full compatibility with FXServer's real networking and filesystem needs.
- Reuses the project's existing Azure tooling/MCP access.
- Matches the vast majority of community documentation and troubleshooting resources (FiveM hosting guides overwhelmingly assume a Linux VM/VPS).

### Negative

- No automatic scaling — capacity growth requires a manual resize or, later, splitting the database onto its own managed service.
- The team owns OS-level security patching (mitigated by using Ubuntu LTS and enabling automatic security updates).

### Neutral

- Co-locating MariaDB on the same VM as FXServer is an Increment 1 simplification; splitting it onto Azure Database for MySQL/MariaDB Flexible Server is a natural future increment if/when player load requires it. This does not require a schema change, only a connection-string change in `oxmysql`'s config.

## References

- `specs/prd.md` — Non-Functional Requirements (hosting), capacity strategy
- `specs/tech-stack.md` — Infrastructure & Deployment section, VM sizing and networking rules
- `specs/contracts/infra/resources.yaml` — concrete resource definitions
