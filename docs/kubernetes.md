# Kubernetes

Deployed and tested locally on kind. Namespace: `saurav-shop`.

## Layout

```
k8s/
├── namespace.yml
├── configmap.yml
├── postgres/
│ ├── deployment.yml
│ ├── service.yml
│ └── pvc.yml
└── saurav-shop-app/
├── server-deployment.yml
├── worker-deployment.yml
└── service.yml

```

## Why server and worker are separate Deployments

Vendure has two runtime processes: the server (handles HTTP/API traffic,
`dist/index.js`) and the worker (background jobs — emails, search
indexing, `dist/index-worker.js`). Locally in Docker Compose these ran
as one process (`vendure dev all`). In Kubernetes they're split into two
Deployments, same image, different `command`.

Reason: they have different scaling needs and different failure impact.
A worker crash shouldn't take down the API, and the API shouldn't need
to scale just because a job queue is backed up. One image, two roles —
`command` picks which one runs.

## Config vs secrets

Non-sensitive values (DB host, port, db name, app env) go in
`configmap.yml`. Credentials, the cookie signing secret, and admin
login go in a Kubernetes Secret, created imperatively — not committed
as YAML:


```
kubectl create namespace saurav-shop

kubectl create secret generic db-secret -n saurav-shop
--from-literal=POSTGRES_USER=sk-vendure
--from-literal=POSTGRES_PASSWORD='sk-vendure-@strongpassword123'
--from-literal=POSTGRES_DB=vendure
--from-literal=DB_USERNAME=sk-vendure
--from-literal=DB_PASSWORD='sk-vendure-@strongpassword123'
--from-literal=COOKIE_SECRET='-yRlVG6-MDFgWxEqWMg7rg'
--from-literal=SUPERADMIN_USERNAME=sauravkarki
--from-literal=SUPERADMIN_PASSWORD='s@vendure123'

```

A committed Secret manifest with even placeholder values is a bad habit
worth avoiding on principle — this way there's nothing to accidentally
leak.

## Postgres

Runs in-cluster as a single-replica Deployment with a PVC for data
persistence and a ClusterIP Service (`postgres`) other pods connect to
by name. Fine for a local/assignment environment.

**This would not be how a real production setup works.** In production
this would be a managed database service (RDS, Cloud SQL, Azure
Database for PostgreSQL, or self hosted postgres instance) — not something running as a pod
in the same cluster as the app. Reasons: backups, point-in-time
recovery, failover, and patching are handled by the provider instead of
by hand; storage and compute for the database scale independently of
the app; and a node failure taking down the app doesn't also take down
the database. The app would just connect to it via a connection string
injected as a Secret, same pattern as now, just pointing outside the
cluster instead of at a `postgres` Service.

## Networking

App connects to Postgres via the Kubernetes Service DNS name
(`postgres`), not an IP or `localhost` — same pattern as the Docker
Compose setup, just at the cluster level instead of the Compose network
level.

`app-server` is exposed via a `NodePort` Service, not `LoadBalancer`.
`LoadBalancer` doesn't provision anything on a local cluster (kind/
minikube) without extra tooling, so NodePort (or port-forward for
testing) is the practical choice locally.

**In production**, this would typically be a `ClusterIP` Service behind
an Ingress controller (or a cloud LoadBalancer), with TLS termination
and a real domain — not a NodePort.

## Health checks

`app-server` uses a `tcpSocket` probe on port 3000 for both readiness
and liveness. Vendure does expose a `/health` endpoint (confirmed in
the server logs — `[RouterExplorer] Mapped {/health, GET} route`), so
this could be tightened to an `httpGet` probe against `/health` instead
of just checking the socket is open. Left as tcpSocket for now since it
already works reliably; noting this as a straightforward follow-up.

`app-worker` has no probes — it doesn't serve HTTP, nothing to check.

Postgres uses an `exec` probe running `pg_isready`.

## Database schema — how it actually got created

The project had no migrations (`src/migrations/` was empty,
`synchronize: false` in `vendure-config.ts`, which is the correct
setting for production — auto-sync against a live schema risks losing
data on a misconfiguration).

Generated the initial migration using Vendure's own CLI:


`npx vendure migrate`

→ "Generate a new migration" → produced
`src/migrations/1786438145237-initial-schema.ts`, which is compiled
into `dist/migrations/` as part of the normal build and ships inside
the `saurav-shop:prod` image.

Generating the file is not the same as applying it. `runMigrations()`
is already called in `src/index.ts` before `bootstrap()`, so migrations
apply automatically every time `app-server`/`app-worker` boot — but
only if the migration is present and the DB connection is reachable.

Applying the first migration against the in-cluster Postgres required
a one-time step from outside the cluster, since the CLI needs a direct
DB connection:


`kubectl port-forward -n saurav-shop svc/postgres 5432:5432`

then, in `saurav-shop/.env`, temporarily set `DB_HOST=localhost`, and:

npx vendure migrate

→ "Run pending migrations". Reverted `DB_HOST` back to `vendure-postgres`
afterward.


## Verified working

kubectl get pods -n saurav-shop

`app-server`, `app-worker`, `postgres` all `1/1 Running`, no restarts.
Server log shows a clean bootstrap — Admin API, Shop API, and Dashboard
routes all mapped, no schema errors.


