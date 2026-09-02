# WilliamProgress — FiveM RP Server, Session Log & Replication Runbook

This document exists so a second person (and their own AI coding tool) can
pick up exactly where this session left off, in their **own** local
environment. It has two parts:

1. **The decision trail** — what got decided, why, and where it's written down in this repo.
2. **The local-testing runbook** — the exact commands and gotchas needed to get FXServer running locally, since none of that existed anywhere until this session.

If you're handing this to an AI coding assistant, the short version is:
*"Read `WilliamProgress.md`, then `AGENTS.md`, then everything under `specs/`, then follow the Local Testing Runbook below to get your own local FXServer running."*

---

## Part 1 — What This Project Is

This repo uses the **spec2cloud** framework (`AGENTS.md` = orchestrator
instructions, `.github/skills/` = the procedures it follows,
`.spec2cloud/state.json` = current progress, `.spec2cloud/audit.log` =
full history of what happened). `CLAUDE.md` at the repo root is a
one-line `@AGENTS.md` import, so any Claude Code session in this repo
auto-loads the orchestrator instructions on startup.

The product being built: **a custom FiveM roleplay (RP) server** — not
built on QBCore, QBox, or ESX. Custom gameplay/economy conventions, built
on top of standard low-level libraries (`ox_lib`, `oxmysql`, `ox_target`)
instead of a full framework.

### Key decisions made (full detail in the ADRs linked below)

| Decision | Choice | Why |
|---|---|---|
| Genre | Roleplay | Most common FiveM server type, most resource/tutorial support |
| Framework | Custom, on `ox_lib`/`oxmysql`/`ox_target` | Wanted fully custom jobs/economy, but didn't want to reinvent solved plumbing (DB access, UI, targeting) |
| Hosting (eventual) | Azure VM (IaaS) | Container Apps doesn't support raw UDP; a VM does. See `specs/adrs/adr-001-azure-vm-for-fivem-hosting.md` |
| Database | MariaDB via `oxmysql` | Ecosystem standard, interchangeable with MySQL |
| Anti-cheat | Icarus (free) for now | No player base/revenue yet to justify a paid option. See `specs/adrs/adr-003-icarus-anticheat-for-launch.md` |
| Character model | Single character per account | Simplest for a "blank slate" MVP |
| Currency model | Cash + Bank split | Universal RP convention, cheap to add now, expensive to retrofit |
| **Increment 1 scope** | Framework + DB + architecture + a **working, persistent** currency system. **No job content yet.** | Walking-skeleton-first: prove the architecture before adding gameplay variety |
| Testing | **Skipped entirely for Increment 1** | Explicit, human-directed deviation from this framework's own test discipline. See `specs/adrs/adr-004-skip-tests-for-increment-1.md` — read this one, it documents the real trade-off being accepted |

### Where everything is written down

Read these in this order for full context — this file is a summary, not a replacement:

1. `specs/prd.md` — product vision, scope, what's deliberately deferred (jobs, factions, theme, monetization, timeline — none of that is decided yet, don't assume it)
2. `specs/frd-core-framework.md` — the "blank slate": bootstrap, DB schema, player identification, character session lifecycle
3. `specs/frd-currency-system.md` — cash/bank dual-balance transactions, atomicity guarantees, admin/test commands
4. `specs/tech-stack.md` — every technology decision resolved, with rationale, plus a **corrected** `server.cfg` load order (see the note in there about `cfx-server-data` being archived and `sessionmanager`/`hardcap`/`rconlog` no longer existing — that correction came from live debugging, not from any doc)
5. `specs/contracts/infra/resources.yaml` — the (not-yet-provisioned) Azure VM infra contract
6. `specs/increment-plan.md` — Increment 1 fully scoped, Increment 2+ deliberately left as placeholders
7. `specs/adrs/adr-001` through `adr-004` — the reasoning behind each major call above
8. `.spec2cloud/state.json` — machine-readable current status (what's approved, what's in progress)

### What's actually implemented (real code, not just specs)

- `resources/[core]/core-framework/` — connect/identify/load/save character lifecycle, exports `GetCharacter`/`IsCharacterLoaded`/`SaveCharacter`
- `resources/[economy]/currency-system/` — `AddCash`/`RemoveCash`/`AddBank`/`RemoveBank`/`Transfer`/`GetBalances` exports, `/testpay` and `/setmoney` commands, `currency:balanceChanged` event, ox_lib balance notifications
- `server/server.cfg.example` — deployment-ready config template with full commentary

**Important:** none of this code has automated tests (see ADR-004). It's implemented to spec but unverified beyond the manual local-testing pass described below. The atomicity guarantee for money transactions relies on a specific invariant documented inline as a comment in `resources/[economy]/currency-system/server/main.lua` — read that comment before modifying those functions.

---

## Part 2 — Local Testing Runbook

This is the part that took the most trial and error this session, because
almost nothing about it was written down anywhere beforehand. Follow it
in order. Commands below assume a Debian/Ubuntu-based Linux environment
(this session ran inside a WSL2-based devcontainer) — adjust package
manager commands if you're on something else.

### Prerequisite you cannot skip: a Cfx.re account + license key

**FXServer refuses to boot at all without a valid server license key —
this is true even for purely local testing, there is no exemption.**
Getting one is free but requires your own Cfx.re account. Do this early;
everything else can be prepped without it, but you can't actually launch
without it.

1. Create/sign into a Cfx.re account at `forum.cfx.re` (Discord/Steam/email signup all work).
2. Get a free server key at `https://keymaster.fivem.net` → "Register New Server". Keys look like `cfxk_XXXXXXXXXXXXXXXXXXXX_XXXXXX`.
3. **Do not commit this key to git or share it in a repo.** It's a per-account secret. Everyone replicating this setup needs their *own* key — you cannot reuse someone else's.

### Step 1 — Install and start MariaDB

```bash
sudo apt-get update -qq && sudo apt-get install -y mariadb-server
sudo service mariadb start   # no systemd in most containers — use `service`, not `systemctl`
```

### Step 2 — Create the database and load the schema

```bash
sudo mysql -e "
CREATE DATABASE IF NOT EXISTS fivem_rp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'fivem'@'localhost' IDENTIFIED BY 'CHOOSE-YOUR-OWN-PASSWORD';
GRANT ALL PRIVILEGES ON fivem_rp.* TO 'fivem'@'localhost';
FLUSH PRIVILEGES;
"
mysql -u fivem -p'CHOOSE-YOUR-OWN-PASSWORD' fivem_rp \
  < "resources/[core]/core-framework/sql/install.sql"
```

### Step 3 — Download FXServer (Linux build)

**Gotcha we hit:** the build folder listing at `runtime.fivem.net` is
NOT numerically sorted when read as text — a naive `sort | tail` picks a
build number like `9956` when builds like `35805` already exist,
because string-sort puts `"9..."` after `"3..."`. Sort numerically:

```bash
mkdir -p ~/fxserver
curl -sL "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/" -o /tmp/fx_index.html
LATEST_BUILD=$(grep -oE '[0-9]{4,6}-[a-f0-9]{7,}' /tmp/fx_index.html | sed -E 's/^([0-9]+)-.*/\1 &/' | sort -n | tail -1 | awk '{print $2}')
echo "Latest build: $LATEST_BUILD"
curl -sL -o ~/fxserver/fx.tar.xz "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${LATEST_BUILD}/fx.tar.xz"
cd ~/fxserver && tar xf fx.tar.xz && rm fx.tar.xz
```

**Second gotcha:** `oxmysql` (the DB library, see below) requires a
minimum FXServer build number. If you see this error at boot:

```
Resource 'oxmysql' can't run: server needs to be 12913 or higher
```

...it means your build is too old. Always grab the numerically-latest
build using the method above, not an old cached one.

### Step 4 — Get the default "spawn" resources

**Gotcha:** the classic answer ("clone `cfx-server-data`, ensure
`mapmanager`/`spawnmanager`/`sessionmanager`/`chat`/`hardcap`/`rconlog`")
is outdated. That repo is now archived. Only `mapmanager`, `spawnmanager`,
and `basic-gamemode` still live there — `sessionmanager`/`hardcap`/
`rconlog` no longer exist as resources at all. `monitor` is injected
automatically by txAdmin itself. `chat` is a known unresolved gap (see
Known Issues below) — it did not work as expected in this session.

```bash
git clone --depth 1 https://github.com/citizenfx/cfx-server-data.git /tmp/cfx-server-data
mkdir -p ~/fxserver/server-data/resources/'[managers]' ~/fxserver/server-data/resources/'[gamemodes]'
cp -r /tmp/cfx-server-data/resources/'[managers]'/spawnmanager /tmp/cfx-server-data/resources/'[managers]'/mapmanager \
  ~/fxserver/server-data/resources/'[managers]'/
cp -r /tmp/cfx-server-data/resources/'[gamemodes]'/basic-gamemode \
  ~/fxserver/server-data/resources/'[gamemodes]'/
```

**Without `mapmanager`/`spawnmanager`/`basic-gamemode`, a connecting
player loads their character and currency correctly but never actually
appears in the world.** Neither of this project's FRDs cover spawning —
it's stock FXServer behavior, easy to forget.

### Step 5 — Get the Overextended libraries (`ox_lib`, `ox_target`, `oxmysql`)

These are external, actively-maintained community resources — not
something to write yourself. Use the GitHub "latest release" redirect,
which always resolves to the current version:

```bash
mkdir -p ~/fxserver/server-data/resources/'[core]'
for repo in ox_lib ox_target oxmysql; do
  curl -sL -o "/tmp/${repo}.zip" "https://github.com/overextended/${repo}/releases/latest/download/${repo}.zip"
  mkdir -p ~/fxserver/server-data/resources/'[core]'/"$repo"
  unzip -oq "/tmp/${repo}.zip" -d ~/fxserver/server-data/resources/'[core]'/"$repo"
  # the zip contains a nested folder matching the repo name - flatten it
  if [ -d ~/fxserver/server-data/resources/'[core]'/"$repo/$repo" ]; then
    mv ~/fxserver/server-data/resources/'[core]'/"$repo/$repo" ~/fxserver/server-data/resources/'[core]'/"${repo}_tmp"
    rmdir ~/fxserver/server-data/resources/'[core]'/"$repo"
    mv ~/fxserver/server-data/resources/'[core]'/"${repo}_tmp" ~/fxserver/server-data/resources/'[core]'/"$repo"
  fi
done
```

Note: a community fork `CommunityOx/oxmysql` exists but was archived
April 2026 — use `overextended/oxmysql` as above, not the fork.

### Step 6 — Link this project's own resources

Symlink rather than copy, so edits in the repo are picked up live:

```bash
mkdir -p ~/fxserver/server-data/resources/'[economy]'
ln -sfn "$(pwd)/resources/[core]/core-framework" ~/fxserver/server-data/resources/'[core]'/core-framework
ln -sfn "$(pwd)/resources/[economy]/currency-system" ~/fxserver/server-data/resources/'[economy]'/currency-system
```

(Run this from the repo root, or replace `$(pwd)` with the absolute repo path.)

### Step 7 — Write `server.cfg`

Copy `server/server.cfg.example` from this repo to
`~/fxserver/server-data/server.cfg` and fill in:
- `sv_licenseKey` — your own key from the prerequisite step above
- `mysql_connection_string` — matching the DB user/password/name you created in Step 2
- `add_principal identifier.license:...` — your own FiveM license identifier (you'll see it in the server console log the first time you connect, or via `getplayeridentifiers` in the F8 console)

The `ensure` list should be (see `specs/tech-stack.md` for the annotated version):
```
ensure mapmanager
ensure spawnmanager
ensure basic-gamemode
ensure baseevents
ensure oxmysql
ensure ox_lib
ensure core-framework
ensure currency-system
ensure ox_target
```
(`chat` and `icarus` are deliberately omitted — see Known Issues.)

### Step 8 — First launch, via txAdmin

```bash
cd ~/fxserver && ./run.sh
```

This starts **txAdmin** (the official management panel) on port `40120`.
First run walks you through a setup wizard:

1. Open `http://localhost:40120` in your browser.
2. It shows a PIN in the terminal (`Use the PIN below to register: XXXX`) — type that exact PIN into the web UI and click "Link Account." This requires (and creates) your Cfx.re-linked admin account for this txAdmin instance.
3. After linking, you land on a dashboard saying "Server not configured — go to the setup page!" Click through to it.
4. Choose deployment type **"📁 Existing Server Data"** — NOT a recipe template (those deploy QBCore/ESX, which conflicts with this project's custom framework). Point it at your `~/fxserver/server-data` folder.
5. Give it a server name, click Finish.
6. It will try to boot and fail if `sv_licenseKey` is still a placeholder — go into `server.cfg` (or txAdmin's Settings → FXServer page, if it has a license key field) and set your real key from the prerequisite step.
7. Click **Restart Server**.

If you see `Server license key authentication succeeded. Welcome!`
followed by each resource starting (`oxmysql`, `ox_lib`,
`core-framework`, `currency-system`, `ox_target`, `mapmanager`,
`spawnmanager`, `basic-gamemode`) and `Database server connection
established!` — you're fully up.

### Step 9 — Connect and test

From the machine with GTA V + the FiveM client installed (this must be a
real graphical machine — it cannot be a headless Linux container):

1. Direct-connect to `localhost:30120` (or `127.0.0.1:30120`).
2. You should load in, get a character created with the starting cash/bank from `resources/[economy]/currency-system/shared/config.lua`, and spawn via `basic-gamemode`'s default spawn point.
3. Test the currency loop: run `/testpay 50` in the in-game console (F8) and confirm your cash increases; disconnect and reconnect to confirm it persisted.

**Networking caveat if this doesn't connect:** if your server runs inside
a devcontainer (nested inside WSL2, inside Docker), UDP port forwarding
from container → WSL2 → Windows host is not guaranteed to work the same
way TCP does — VS Code's built-in port forwarding is TCP-oriented, and
FiveM's game traffic on port 30120 needs UDP. If `localhost:30120` times
out specifically from the Windows FiveM client:
- Check the container/VS Code "Ports" panel for `30120` and try forwarding it explicitly.
- If UDP still doesn't pass through, run FXServer directly under plain WSL2 (no nested devcontainer) — WSL2's own localhost-forwarding feature handles both TCP and UDP transparently, without depending on Docker or VS Code's forwarding at all.

---

## Known Issues / Open Items (as of this writing)

- **`chat` resource not found.** Expected it to be bundled inside FXServer's own `citizen/system_resources/` (alongside `monitor`, which does work that way), but it did not resolve via `ensure chat` in this session. No in-game text chat box currently. Not blocking spawning. Needs further investigation or a replacement chat resource.
- **Icarus anti-cheat not yet installed.** Deferred — not required to test spawning/currency locally, only relevant before any public-facing launch (see ADR-003).
- **Azure infrastructure not provisioned.** `specs/contracts/infra/resources.yaml` is a contract, not a deployed resource. No Bicep templates have been written yet. Not needed for local testing at all.
- **No automated or manual tests exist** for either FRD's acceptance criteria (ADR-004). Everything above is "implemented to spec, manually smoke-tested via the steps in this runbook," not verified against the FRDs' AC1–AC6 lists formally.
- **FiveM client connection from Windows was in progress** when this document was written — the server was confirmed fully booted and listening on the correct ports, but the actual "does a real player spawn in" test had not yet been confirmed successful in this session.

## Suggested Next Steps

1. Confirm the FiveM client can actually connect and a character spawns with the correct starting balance.
2. Resolve the `chat` resource gap.
3. Manually walk through `frd-core-framework.md` and `frd-currency-system.md`'s acceptance criteria (AC1–AC6 in each) to at least manually verify what ADR-004 left unverified — reconnect-persistence, insufficient-funds rejection, the `/setmoney` admin audit log, etc.
4. When ready to move past local testing: Increment 2 (job variety) is intentionally unscoped — see `specs/increment-plan.md` and the PRD's deferred-decisions list for what needs deciding first (specific jobs, salaries, factions).
