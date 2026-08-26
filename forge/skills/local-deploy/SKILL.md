---
name: local-deploy
description: >
  Stand up the current project fully on this machine — infra containers
  (postgres/redis/etc.), backend, frontend, workers — bound to the network so
  it is reachable over the Tailscale VPN, self-verify every service, and
  return tested tailnet URLs for testing from a phone or another device.
  Discovery-first: infers the stack from the repo, no config required.
  Subcommands: (none) = deploy, "status", "stop", "restart". Use when the
  user wants to try the app on-device, or when an orchestration gate needs a
  human-testable deployment.
---

# local-deploy: Discover → Provision → Run → Verify → Report

Prime rule: **never hand over a URL you have not proven works yourself.**
The deliverable is not "processes started" — it is "I loaded it and it
responded correctly, here's where you do the same."

Parse `$ARGUMENTS`: empty = deploy; `status` | `stop` | `restart`.
`status`/`stop`/`restart` operate from the manifest (below) — if no
manifest exists, say so and stop.

## 0. Prior state

If `.local-deploy.json` exists, a previous deployment may be live. For a
fresh deploy: tear the old one down first (its tmux windows, containers,
PIDs) so nothing stacks. Never kill processes that aren't in the manifest.

## 1. Discover

Build the service graph before starting anything. Evidence, in priority
order:

- `docker-compose.yml` / `compose.yaml` — if present and covers the app,
  PREFER it over inventing your own topology (`docker compose up -d`,
  possibly with an override file for port binding).
- `package.json` scripts (dev/start/build), workspaces/monorepo layout
  (`apps/`, `packages/`, `frontend/`+`backend/`), `Procfile`, `Makefile`,
  framework markers (Next/Vite/Astro; Django/Flask/FastAPI; Rails; Go
  main packages), `.env.example` / `.env.sample` (the dependency
  confession: DATABASE_URL, REDIS_URL, S3 endpoints, API keys).
- Migrations/seeds: `prisma/`, `drizzle/`, `alembic/`, `migrations/`,
  `db/seeds`, or script names containing migrate/seed.

Output of this step (state it to the user before proceeding): the service
graph — e.g. `frontend(next) → api(fastapi) → postgres, redis` — and which
env vars each service needs. If a required secret has no derivable value
(a third-party API key with no default), say so up front and deploy the
rest; a partially-up app with a named gap beats a silent failure.

## 2. Ports

Allocate from the shared registry `~/.forge/ports` (create if missing).
Format: one `project base_port` line each; each project owns a block of 10
from its base (base=frontend, base+1=api, base+2..: extras; infra
containers use their conventional ports remapped into the block if the
defaults are taken). First free block starting at 3100. Reuse the
project's existing line on re-deploy. This keeps multiple simultaneously
deployed projects from colliding.

## 3. Provision infra

Datastores run as containers, never host installs: `docker run -d` (or the
compose file) for postgres/redis/minio/etc., named
`ld-<project>-<service>`, data in named volumes so restarts keep state.
Wait for readiness (`pg_isready`, `redis-cli ping` — poll, don't sleep
blind). Then migrate and seed if the repo has the scripts.

## 4. Configure & run app services

- Write env into `.env.local-deploy` (never overwrite the user's `.env`;
  point services at it, or export inline in the launch command).
- **The VPN-critical detail:** get the tailnet IP via `tailscale ip -4`.
  Any URL the *client browser* will call (frontend's API base URL,
  websocket URLs, OAuth redirect bases) MUST use the tailnet IP, not
  localhost — localhost baked into the frontend is the #1 way a deploy
  works on the box and fails on the phone. Server-to-server URLs
  (api→postgres) stay on localhost/container network.
- Bind every service to `0.0.0.0`.
- Run each service in its own tmux window: session `ld-<project>`,
  windows named by service, command wrapped so logs also tee to
  `.local-deploy/logs/<service>.log`. (Inside a forge tmux session,
  still use the separate `ld-<project>` session — forge and manual
  deploys then behave identically.)
- Build-first frameworks: prefer dev-mode servers for speed unless the
  prompt/gate asks for a production build.

## 5. Verify (the step that earns the report)

For each service, in dependency order:

- infra: readiness probe passed (already done).
- api: curl its health endpoint if one exists, else a known route; expect
  2xx/3xx and sane content. Hit it via the **tailnet IP**, not localhost —
  that also proves the bind and any firewall.
- frontend: curl via tailnet IP; expect HTML that isn't an error page.
- integration: at least one request that crosses the frontend→api
  boundary (the API base URL the frontend was configured with must
  answer from the tailnet address).

Any failure: read the service's log, fix (missing migration, port clash,
env var), retry. If still failing after 2–3 focused attempts, report
exactly what's up, what's down, and the failing log excerpt — a partial
honest report, not a retry spiral.

## 6. Manifest & report

Write `.local-deploy.json` (add to `.gitignore` if not there):

```json
{
  "project": "myapp",
  "deployed": "<iso timestamp>",
  "tailnet_ip": "100.x.y.z",
  "tmux_session": "ld-myapp",
  "services": [
    {"name": "postgres", "kind": "container", "id": "ld-myapp-postgres", "port": 5432},
    {"name": "api", "kind": "tmux", "window": "api", "port": 3101,
     "url": "http://100.x.y.z:3101", "health": "/healthz", "verified": true},
    {"name": "frontend", "kind": "tmux", "window": "frontend", "port": 3100,
     "url": "http://100.x.y.z:3100", "verified": true}
  ]
}
```

Report to the user (or return to the calling skill):

```
✅ myapp deployed — test from your phone:
   app: http://100.x.y.z:3100
   api: http://100.x.y.z:3101/healthz
   running in tmux session ld-myapp · logs in .local-deploy/logs/
   stop with: /local-deploy stop
```

Only services with `verified: true` get the ✅ framing; anything else is
listed under a clearly-marked "not verified / not running" section.

## stop / restart / status

- `stop`: kill manifest tmux session, stop (not rm) containers, report.
- `restart`: stop, then re-run deploy reusing the manifest's ports.
- `status`: re-run the verification probes against the manifest and report
  live/dead per service — don't trust the manifest's stored `verified`.
