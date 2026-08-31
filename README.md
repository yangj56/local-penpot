# Penpot local setup

Local Penpot on Kubernetes: Postgres and Redis run in Docker Compose, the Penpot Helm chart runs the app, and `kubectl port-forward` exposes it at [http://localhost:9001](http://localhost:9001).

## Prerequisites

Install and start these before the first `npm start`:

| Tool | Why |
| --- | --- |
| [Docker](https://docs.docker.com/get-docker/) (Docker Desktop, OrbStack, or Colima) | Runs Postgres, Redis, and the Kind node. |
| [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) | Local Kubernetes cluster. Helm deploys Penpot here. |
| `kubectl` | Talks to the Kind cluster. |
| [Helm 3](https://helm.sh/docs/intro/install/) | Installs the official `penpot/penpot` chart. |
| Node.js / npm | Runs the scripts in `package.json`. |

Create a cluster once if you do not have one:

```bash
kind create cluster
kubectl config use-context kind-kind
```

Check:

```bash
docker info
kubectl cluster-info
helm version
```

`values.yaml` points Postgres/Redis at `host.docker.internal` so Kind pods can reach Compose on the host. That works on Docker Desktop and OrbStack on macOS.

## First-time Helm repo

Add the official chart repo once (or whenever you want the latest index):

```bash
npm run helm:repo
```

That runs:

```bash
helm repo add penpot https://helm.penpot.app --force-update
helm repo update penpot
```

`npm start` does **not** add the repo. If `helm upgrade` fails with `chart "penpot/penpot" not found`, run `npm run helm:repo` and try again.

## Start

```bash
npm start
```

This:

1. Starts Postgres (`localhost:5432`) and Redis (`localhost:6380`) with Docker Compose
2. Installs or upgrades Helm release `my-release` from `penpot/penpot` using `values.yaml`
3. Waits for frontend, backend, exporter, and mcp deployments
4. Port-forwards `svc/my-release-penpot` `9001 → 8080`
5. Opens [http://localhost:9001](http://localhost:9001)

Leave that terminal running. Stop with `Ctrl+C`, then:

```bash
npm stop
```

That uninstalls the Helm release and stops Compose. Postgres data stays in the `penpot_postgres_data` volume until you remove it.

## Seed login users

Registration is off (`disable-registration` in `values.yaml`). Create accounts from `users.txt` in a **second** terminal while `npm start` is running:

```bash
npm run seed
```

Format (`users.txt`):

```text
# email[,fullname[,password]]
alice@example.com,Alice Example,penpot1234
bob@example.com,Bob Example
```

Password must be at least 8 characters. If omitted, the default is `penpot1234` (override with `PENPOT_SEED_PASSWORD`).

Then log in at [http://localhost:9001](http://localhost:9001) with that email and password.

Seeding needs `enable-prepl-server` (already set) and a running backend.

## Helm values (`values.yaml`)

Passed to the chart as `-f values.yaml`. The important keys:

| Key | This repo | Notes |
| --- | --- | --- |
| `config.publicUri` | `http://localhost:9001` | Must match the URL in the browser. The chart default is `http://penpot.example.com`, which does not resolve locally. |
| `config.flags` | see file | `disable-registration`, password login, no email verification, PREPL (for seed), MCP, `disable-secure-session-cookies` (required for HTTP). |
| `config.postgresql` | `host.docker.internal:5432` | Chart talks to Compose Postgres, not an in-cluster database. |
| `config.redis` | `host.docker.internal:6380` | Redis is mapped to **6380** on the host so it does not clash with a local Redis on 6379. |

After you change `values.yaml`, restart `npm start` (it runs `helm upgrade --install`).

Official chart reference: [penpot/penpot-helm](https://github.com/penpot/penpot-helm).

## npm scripts

| Script | What it does |
| --- | --- |
| `npm start` | Compose up, Helm install/upgrade, wait, port-forward `:9001` |
| `npm stop` | `helm uninstall my-release` and Compose down |
| `npm run status` | Compose ps, Helm status, pods |
| `npm run helm:repo` | Add/update the `penpot` Helm repo |
| `npm run helm:install` | `helm upgrade --install my-release penpot/penpot -f values.yaml` |
| `npm run helm:uninstall` | Remove the release |
| `npm run seed` | Create profiles from `users.txt` |

## Layout

```text
values.yaml           Helm overrides for the Penpot chart
docker-compose.yml    Postgres 15 + Redis 7.2
scripts/start.sh      Full local bring-up
scripts/seed.sh       create-profile via backend PREPL
users.txt             Seed accounts
```

## Troubleshooting

**Blank dark page in Chrome, but the cursor still hits the login form**  
The app loaded; Chrome did not paint it. Try Incognito, disable extensions (Dark Reader, ad blockers), or turn off hardware acceleration. A pending Chrome **Relaunch to update** can cause the same thing.

**`net::ERR_NAME_NOT_RESOLVED` for `penpot.example.com`**  
The frontend is using a stale `/js/config.js` (nginx caches it for 7 days). The live file should set `penpotPublicURI` to `http://localhost:9001`. Hard reload with **Cmd+Shift+R**, or use Incognito. Confirm with `http://localhost:9001/js/config.js`.

**Pods cannot reach Postgres/Redis**  
`host.docker.internal` must resolve inside the cluster. That is normal on Docker Desktop and OrbStack. On Linux you may need extra host aliases.

**`chart "penpot/penpot" not found`**  
Run `npm run helm:repo`.

**Seed: PREPL is not reachable**  
Keep `npm start` running and keep `enable-prepl-server` in `config.flags`.
