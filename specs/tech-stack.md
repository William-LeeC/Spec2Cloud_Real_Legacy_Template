# Tech Stack

## Overview

A custom FiveM roleplay server, hosted on a single Azure VM. Gameplay and
economy logic are first-party (Lua), built on Overextended's standard
low-level libraries (`ox_lib`, `oxmysql`, `ox_target`) rather than a full
framework (QBCore/QBox/ESX) — see `specs/adrs/adr-002-*.md`. Persistence is
MariaDB, co-located on the same VM as FXServer for Increment 1.

Several categories from the standard technology checklist don't apply to a
FiveM game server in their usual web-app sense (frontend framework, REST
API, HTTP auth) — those are noted explicitly as "N/A / built-in" below
rather than silently skipped, per this project's completeness checklist.

## Resolved Technologies

### Game Server Runtime

#### FXServer

- **Purpose:** The core game server process that runs all Lua/JS/C# resources and handles client connections.
- **Choice:** Official Cfx.re FXServer build (Linux artifact).
- **Version:** Pin to a specific numbered build from `runtime.fivem.net` (recommended process, not a fixed version here) rather than tracking `latest` — FiveM artifact builds can introduce breaking changes; a pinned build gives predictable, reproducible deployments. Update deliberately via txAdmin's "Check for Updates," not automatically.
- **Rationale:** Only supported way to run a FiveM server; no alternative exists.
- **Wiring:** Downloaded and managed by txAdmin during initial VM setup.
- **Deployment:** Runs directly on the Azure VM (see Infrastructure section).
- **Key Patterns:** Use txAdmin's recipe/deployer for first-time setup instead of a fully manual install — reduces first-server setup error surface.
- **Anti-patterns:** Do not track the `latest` artifact channel in production; do not skip txAdmin and manage FXServer as a bare process without its process-monitoring/restart-on-crash behavior.
- **Documentation:** https://docs.fivem.net/docs/server-manual/setting-up-a-server/

#### txAdmin

- **Purpose:** Built-in server management panel — process monitoring, restart-on-crash, resource management, admin/permission management, deployer recipes.
- **Choice:** Bundled with FXServer (not a separate install).
- **Rationale:** Standard, official tooling; avoids building a bespoke admin panel for Increment 1's "essential admin tooling from day one" requirement.
- **Wiring:** Configured on first VM boot; web panel on port 40120.
- **Deployment:** Runs on the same VM as FXServer. **Port 40120 must not be exposed publicly** — restrict via NSG to admin IP(s) only, or access via SSH tunnel (see Infrastructure section).
- **Key Patterns:** Use txAdmin's built-in scheduled restart and resource monitor rather than external tooling for Increment 1.
- **Anti-patterns:** Never open port 40120 to `0.0.0.0/0` in the NSG.
- **Documentation:** https://server-guide.fivem.net/

### Data Storage

#### MariaDB

- **Purpose:** Persistent storage for the `characters` table (`frd-core-framework.md`) and all future gameplay data.
- **Choice:** MariaDB 10.11 (LTS) over MySQL Community Server.
- **Alternatives considered:** MySQL Community Server — functionally interchangeable with `oxmysql` (both are MySQL-protocol compatible); MariaDB was chosen because it's the default bundled option in most FiveM/txAdmin community deployment guides, remains fully open-source, and has no practical migration cost if this decision needs to be revisited (`oxmysql`'s connection string is the only thing that would change).
- **Version:** 10.11 LTS.
- **Rationale:** Ecosystem-standard pairing with `oxmysql`; long-term support release for stability.
- **Wiring:** Installed directly on the Azure VM; `oxmysql` connects via a local connection string (`mysql://user:pass@localhost/dbname`) — no network exposure needed since it's co-located.
- **Deployment:** Runs on the same VM as FXServer for Increment 1 (see ADR-001). Data lives on a separate attached data disk, not the OS disk, so it survives VM-level changes more safely and can be resized independently.
- **Key Patterns:** All access through `oxmysql`'s async, parameterized query functions — never raw string-concatenated SQL (per `frd-core-framework.md` non-functional requirements).
- **Anti-patterns:** Do not expose MariaDB's port (3306) beyond `localhost` — no NSG rule should open it externally.
- **Documentation:** https://mariadb.org/documentation/

#### oxmysql

- **Purpose:** Async MySQL/MariaDB driver resource for FiveM — the only sanctioned path to the database for every other resource.
- **Choice:** `overextended/oxmysql` (the canonical repository). Note: a community fork (`CommunityOx/oxmysql`) exists but was archived in April 2026 — use the original Overextended repository, not the archived fork.
- **Version:** Latest tagged release at implementation time; pin the exact tag/commit used in `server.cfg` comments for reproducibility.
- **Rationale:** The de facto standard async DB layer across the FiveM ecosystem (used by QBox, ESX, and standalone resources alike) — mature, well-documented, avoids hand-rolling connection pooling and query escaping.
- **Wiring:** `ensure oxmysql` in `server.cfg`, loaded **before** any resource that queries the database (see load order below). Connection string set via `server.cfg` convar.
- **Deployment:** No separate Azure resource — it's a FiveM resource, not infrastructure.
- **Key Patterns:** Use `exports.oxmysql:execute`/`insert`/`update`/`scalar` with parameterized queries for every character/currency operation.
- **Anti-patterns:** Never construct SQL by string concatenation with user- or client-derived values.
- **Documentation:** https://overextended.dev/docs/oxmysql

### Caching

Not needed for Increment 1. Character session state is held in-memory by
the core framework resource itself (per `frd-core-framework.md`'s Session
State API) — no separate caching layer is warranted at this scale.

### AI / Machine Learning

Not applicable — no AI/ML capability is in scope for Increment 1 or the
current PRD.

### Voice / Speech

Deferred. Proximity voice chat (e.g. `pma-voice`) is a confirmed future
direction (see `specs/prd.md`) but is not required by either Increment 1
FRD — it doesn't block the character/currency walking skeleton and will be
resolved when it's actually scheduled into an increment.

### Authentication & Authorization

#### FiveM Identifier + ACE Permissions

- **Purpose:** Identify players and gate admin/test commands.
- **Choice:** FiveM's built-in `license:` identifier for player identity (see `frd-core-framework.md` FR3); Cfx.re's native ACE permission system for admin command authorization (FR7/FR8 in `frd-currency-system.md`).
- **Rationale:** Built into the platform — no separate auth provider makes sense for a game server where the client is the FiveM game itself, not a browser.
- **Wiring:** `add_ace`/`add_principal` directives in `server.cfg`; permission checks via `IsPlayerAceAllowed` in Lua before executing admin/test commands.
- **Deployment:** Configuration lives in `server.cfg` on the VM.
- **Key Patterns:** Every admin/test command checks ACE permission server-side before acting — never trust a client-side permission check alone.
- **Anti-patterns:** Do not gate admin commands by hardcoded identifier lists in Lua source — use ACE principals so access can change without a code deploy.
- **Documentation:** https://docs.fivem.net/docs/scripting-manual/permissions/

### Real-time Communication

N/A / built-in. FiveM's native client-server event system
(`TriggerEvent`/`TriggerServerEvent`/`TriggerClientEvent`) is the only
communication mechanism between client and server — this is a platform
primitive, not a technology choice to resolve.

### Search

Not applicable — no search capability is in scope.

### File Storage

Not needed for Increment 1 — no user-uploaded media or file handling exists in either FRD.

### Messaging & Events

N/A / built-in — same native event system as Real-time Communication above.

### Observability & Monitoring

#### txAdmin (built-in) + structured console logging

- **Purpose:** Process health, resource monitoring, and debugging visibility.
- **Choice:** txAdmin's built-in monitoring for process/resource health; structured `print`/log statements from the framework and currency resources (resource name, identifier, action, result — per `frd-core-framework.md`'s non-functional requirements) for application-level events.
- **Rationale:** Sufficient for Increment 1's scale; avoids standing up Azure Monitor/Log Analytics for a single VM before there's a real operational need.
- **Wiring:** Console output captured by txAdmin automatically.
- **Deployment:** No additional Azure resource for Increment 1.
- **Anti-patterns:** Do not log raw player identifiers or DB credentials in player-facing or easily-shared logs.
- **Future option:** If/when this VM's logs need centralized retention or alerting, Azure Monitor Agent can be added to the VM without changing the application-level logging approach — not needed now.

### Infrastructure & Deployment

#### Azure VM (IaaS)

- **Purpose:** Hosts FXServer, txAdmin, and MariaDB for Increment 1.
- **Choice:** Single Azure VM — see ADR-001 for the comparison against Container Apps and dedicated game hosting.
- **Size:** `Standard_B2s` (2 vCPU, 4 GiB RAM) as the starting size — a burstable, cost-effective tier appropriate for a first server with no player base yet. Resize vertically (e.g. to `Standard_B4ms`) as player count grows; this requires a VM restart but no application changes.
- **OS:** Ubuntu Server 22.04 LTS — the overwhelmingly standard choice for FiveM hosting; lighter-weight and cheaper than Windows Server for this workload, with the widest base of community troubleshooting documentation.
- **Disks:** OS disk (default) + a separate attached data disk for MariaDB's data directory and FXServer resources, so database growth is isolated from the OS disk.
- **Networking:** See `specs/contracts/infra/resources.yaml` for the exact NSG rules. Summary: port 30120 (TCP+UDP) open publicly for game traffic; port 40120 (TCP, txAdmin) restricted to admin IP(s) only; port 22 (SSH) restricted to admin IP(s) only.
- **Deployment:** Provisioned via Bicep (to be authored during Phase 2 Step 2 — Contracts — for Increment 1; `resources.yaml` is the contract those templates must satisfy).
- **Managed identity:** Not applicable for Increment 1 — the VM doesn't call other Azure services yet. Revisit if a future increment adds e.g. Azure Blob Storage for backups.

### Frontend Libraries — adapted: In-Game UI

There is no web frontend in this product. "UI" means in-game elements shown
to the FiveM client.

#### ox_lib

- **Purpose:** Shared UI primitives (notifications, context menus, text input dialogs, progress bars) and server-client callback utilities.
- **Choice:** `overextended/ox_lib`.
- **Rationale:** The de facto standard UI/utility library across the modern FiveM ecosystem; avoids building notification/menu UI from scratch (per ADR-002).
- **Wiring:** `ensure ox_lib` in `server.cfg`, loaded after `oxmysql` and before any resource that uses its exports (see load order below). Lua resources call `lib.notify`, `lib.callback`, etc.
- **Deployment:** FiveM resource, no separate Azure resource.
- **Documentation:** https://overextended.dev/docs/ox_lib

#### ox_target

- **Purpose:** Standalone "third-eye" world-interaction targeting (pointing at objects/peds/entities to see context options) — needed once Increment 2 adds interactable jobs, included in the stack now so the dependency is declared and load-ordered correctly from the start.
- **Choice:** `overextended/ox_target`.
- **Rationale:** Standard interaction primitive; not framework-specific, consistent with ADR-002.
- **Wiring:** `ensure ox_target` in `server.cfg`, loaded after `ox_lib`.
- **Deployment:** FiveM resource, no separate Azure resource.
- **Documentation:** https://overextended.dev/docs/ox_target

### Backend Libraries

#### Lua (resource scripting language)

- **Purpose:** Primary language for all server/client resource logic.
- **Choice:** Lua 5.4 (FXServer's supported runtime).
- **Rationale:** Native FiveM scripting language; required regardless of framework choice.
- **Key Patterns:** Server-authoritative logic for anything that touches currency or persistence — clients never directly decide their own balance.
- **Anti-patterns:** Trusting any client-supplied numeric value (amount, identifier) without server-side validation (see `frd-currency-system.md` Edge Cases).

#### Anti-Cheat: Icarus

- **Purpose:** Detect and act on common cheat behaviors (noclip, fake events, blacklisted spawns) — the PRD's day-one admin/anti-cheat requirement.
- **Choice:** Icarus (free, standalone, RP-focused) — see ADR-003 for the full comparison against paid alternatives (WaveShield, FiveGuard) and the rationale for starting free.
- **Wiring:** `ensure icarus` (exact resource name per its own documentation) in `server.cfg`, independent of the custom framework.
- **Deployment:** FiveM resource, no separate Azure resource.
- **Anti-patterns:** Do not treat anti-cheat as a substitute for server-authoritative validation in the currency system — both layers matter.

### server.cfg Load Order

```
ensure mapmanager          # Cfx.re default - required for players to spawn at all
ensure spawnmanager        # Cfx.re default - required for players to spawn at all
ensure basic-gamemode      # Cfx.re default - required for players to spawn at all
ensure chat                # bundled inside the FXServer artifact itself
ensure monitor             # bundled inside the FXServer artifact itself
ensure oxmysql
ensure ox_lib
ensure icarus
ensure core-framework      # this project's frd-core-framework.md resource
ensure currency-system     # this project's frd-currency-system.md resource
ensure ox_target
```

`mapmanager`/`spawnmanager`/`basic-gamemode` are what actually spawns a
connecting player into the world — neither FRD in this project covers
that, it's stock FXServer behavior. `oxmysql` and `ox_lib` must load
before anything that depends on their exports; the two first-party
resources depend on both.

Note: `cfx-server-data` (the traditional source for `mapmanager`/
`spawnmanager`/`basic-gamemode`) is now archived — Cfx.re is folding its
contents into the FXServer artifact over time. `chat` and `monitor` have
already made that move and ship inside the FXServer build itself, no
separate download needed. The older `sessionmanager`/`hardcap`/`rconlog`
resources referenced in some older guides no longer exist.

## Infrastructure Resources

| Resource | Type | Purpose | First Needed In |
|---|---|---|---|
| fivem-server-vm | Microsoft.Compute/virtualMachines | Runs FXServer, txAdmin, MariaDB | Increment 1 |
| fivem-data-disk | Microsoft.Compute/disks | Isolated storage for MariaDB data + FiveM resources | Increment 1 |
| fivem-public-ip | Microsoft.Network/publicIPAddresses | Public IP for player connections | Increment 1 |
| fivem-nsg | Microsoft.Network/networkSecurityGroups | Firewall rules (30120 public, 40120/22 admin-restricted) | Increment 1 |
| fivem-vnet | Microsoft.Network/virtualNetworks | Network isolation for the VM | Increment 1 |

Full resource definitions: `specs/contracts/infra/resources.yaml`.

## Per-Increment Technology Map

| Increment | Technologies Used |
|---|---|
| economic-foundation (Increment 1) | FXServer, txAdmin, MariaDB, oxmysql, ox_lib, ox_target, Icarus, Azure VM + NSG + disk + public IP |
| job-variety (Increment 2, not yet scoped) | Same foundation — no new infrastructure category expected; specific job resources TBD once Increment 2 is planned |
