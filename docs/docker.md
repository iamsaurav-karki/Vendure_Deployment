# Docker

## Images
Two Dockerfiles under `docker/`:
- `dev.Dockerfile` — fast-iteration image, runs `vendure dev all`
  (server, worker, and dashboard dev server together)
- `prod.Dockerfile` — multi-stage production build, final image runs
  as a non-root user

## Local development

    ```
    cd docker
    cp ../db/.env.example ../db/.env   # fill in real values
    docker compose up --build
    ```

App available at http://localhost:3000/dashboard

## Production image size

The production image i build using `docker build -f docker/prod.Dockerfile -t saurav-shop:prod .`(saurav-shop:prod) is approximately 1.1-1.2GB.

### Investigation
Used `docker history saurav-shop:prod --human` to inspect per-layer size,
which showed a single ~860MB layer from the `npm ci --omit=dev` step.
Drilled into `node_modules` with `du -sh` per top-level package and found
the bulk of it is frontend build tooling: vite, @tanstack, @babel,
lightningcss, lucide-react, shadcn, ts-morph, and related packages
totaling several hundred MB.

### Root cause
`@vendure/dashboard` is listed under "dependencies" (not devDependencies)
in package.json, and is imported at runtime in src/vendure-config.ts via
`DashboardPlugin` (from '@vendure/dashboard/plugin'), which serves the
admin UI. Confirmed via `grep -rn "@vendure/dashboard" src/` before
attempting any changes, since removing a runtime-required package would
break the admin dashboard route.

Vendure ships `@vendure/dashboard`'s build toolchain (the React/Vite
frontend used to compile the dashboard) as direct dependencies of the
package, rather than isolating the runtime static-file-serving code
from the tooling used to build it. Installing the package at all pulls
in its full build toolchain, even though the running server only needs
to serve already-built static output.

### Decision

Given that the dashboard's build tooling is a required runtime
dependency in this package's design, ~1.1-1.2GB is treated as the
optimal size for this image as currently structured. The multi-stage
build already discards the separate TypeScript/build-stage artifacts
that aren't needed in the final image; the remaining size is inherent
to the dependencies the running server actually requires


## Networking
The app container connects to Postgres via the Docker network hostname
(the `postgres`/`vendure-postgres` service).

## Postgres version
Using postgres:17-alpine rather than the newly-released 18.x line. 17
is stable, widely deployed in production, and well-tested with
TypeORM/Vendure's query patterns.
