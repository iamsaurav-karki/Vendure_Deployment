README.md

# Saurav Shop — Vendure Deployment Assignment

A Vendure e-commerce application, containerized and deployed to Kubernetes
via a Helm chart, with a CI/CD pipeline that builds, tags, and pushes images
to GitHub Container Registry on every change to `main`.

## Structure
- `saurav-shop/` — Vendure application (via @vendure/create)
- `db/` — local Postgres for development
- `docker/` — Dockerfiles + compose for dev/prod
- `k8s/` — raw Kubernetes manifests
- `helm/` — Helm chart packaging the k8s assets
- `.github/workflows/` — CI/CD pipeline

## Prerequisites
- Node.js (see .nvmrc)
- Docker
- kubectl / Helm (for deployment)


## Stack

- [Vendure](https://vendure.io) — application framework
- PostgreSQL 17 — database
- Docker — containerization (separate dev/prod images)
- Kubernetes (tested on `kind`) — orchestration
- Helm — packaging/deployment
- GitHub Actions — CI/CD, publishing to `ghcr.io`


## Quickstart — local development

1. Start Postgres:

```
       cd db/
       cp .env.example .env   # fill in real values
       docker compose -f postgres-docker-compose.yml up -d

```
2. Apply the initial database schema (one-time, only needed on a fresh
   database). Run this from the host, so DB_HOST must point at
   localhost:
```
       cd ../saurav-shop
       cp .env.example .env   # if not already done
       # In .env, set: DB_HOST=localhost
       npx vendure migrate
```
   Select "Run pending migrations".

3. Run the app in Docker. Since the app now runs inside the Docker
   network, DB_HOST must point at the Postgres container name instead:
```
       # In saurav-shop/.env, change DB_HOST back to: vendure-postgres
       cd ../docker
       docker compose up --build
```
App available at `http://localhost:3000/dashboard`.


## Documentation

Each piece has its own doc with the reasoning behind the decisions, not just
the commands:

- [`docs/docker.md`](docs/docker.md) — image structure, production image size
  investigation, Postgres version choice
- [`docs/kubernetes.md`](docs/kubernetes.md) — manifest layout, why server/worker
  are separate Deployments, config vs. secrets, health checks, migrations
- [`docs/helm.md`](docs/helm.md) — install/upgrade/uninstall, secret handling,
  first-deploy migration step
- [`docs/cicd.md`](docs/ci-cd.md) — pipeline design, tagging strategy, the
  values.yaml audit-trail pattern, what's deliberately out of scope and why

## Deploying

1. Build/push happens automatically via CI on every push to `main`
   (see `docs/ci-cd.md`).
2. Pull the latest `helm/saurav-shop/values.yaml` (CI keeps `image.tag` current).
3. Run the upgrade command in `docs/helm.md`, supplying secrets via
   `values-secret.yaml` (untracked, never committed).
4. On a first-ever install against a fresh database, follow the migration
   step in `docs/helm.md`.

## Design decisions worth knowing up front

- **SHA tags, not `latest`, for deploys** — `latest` is a convenience pointer
  only; every deploy is pinned to an immutable git SHA, both in the registry
  and in `values.yaml`, so the running state is always traceable and revertible.
- **Postgres runs in-cluster for this assignment**, but wouldn't in production
  — see `docs/kubernetes.md` for the managed-database reasoning.
- **No automated cluster deploy from CI** — the assignment's `kind` cluster
  isn't reachable from GitHub's hosted runners. CI stops at updating
  `values.yaml`; the actual `helm upgrade` is a manual step. See `docs/ci-cd.md`.
