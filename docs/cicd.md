# CI/CD

GitHub Actions workflow at `.github/workflows/docker-publish.yml`. Two jobs:
`build_push` and `update_manifest`, the second depending on the first via `needs`.

## Trigger

Runs on push to `main`. A merged PR is a push to `main` — GitHub Actions doesn't
distinguish between a direct push and a merge commit landing on the branch, so
no separate `pull_request` trigger is needed to catch merges.


## Job 1: build_push

Builds `docker/prod.Dockerfile`, tags, pushes to `ghcr.io`.

### Tagging strategy

Two tags per push: a short git SHA and `latest`.

- **SHA tag** is what gets deployed. It's immutable — one tag, one specific
  commit, forever. This matters for two things: `values.yaml` actually changing
  between deploys , and being able to redeploy/rollback to a known
  prior commit.
- **`latest`** is a convenience pointer for manual pulls (`docker pull ...:latest`
  to poke around). It's never used for the automated deploy path — a tag that
  gets silently overwritten on every push can't tell you what's actually running,
  and gives Kubernetes no signal that the pod spec changed (see `kubernetes.md`
  probes section for the related principle: things that don't actually change
  shouldn't look like they changed).

The short SHA is computed once, directly, via `git rev-parse --short HEAD`,
rather than trusted from `docker/metadata-action`'s `version` output — that
output picks one tag out of several by internal priority rules and isn't
guaranteed to be the SHA when `latest` is also in the tag list. Computing it
explicitly removes the ambiguity.

### Permissions

`contents: read`, `packages: write` at the job level — this job never writes
back to the repo, only to the registry. Least-privilege per job, not a single
blanket permission block for the whole workflow.

## Job 2: update_manifest

After `build_push` succeeds, this job:
1. Writes the new `image.repository` and `image.tag` into `helm/saurav-shop/values.yaml`
   via `yq`.
2. Commits and pushes that change back to `main`, as `github-actions[bot]`.

This makes `values.yaml` a real audit trail — every deploy is a diffable,
revertible commit showing exactly which SHA was live at that point, not just
a log line in an Actions run that disappears from view.

### The `[skip ci]` guard

The commit this job pushes lands on `main`, which is the trigger branch. Without
`[skip ci]` in the commit message, that push would re-trigger the workflow,
which would push a new commit, which would re-trigger again — an infinite loop.
GitHub Actions honors `[skip ci]` natively and won't fire `push`-triggered
workflows for a commit containing it.

### Permissions

This job needs `contents: write`, scoped to itself only — `build_push` doesn't
get this permission, since it has no reason to write to the repo.

## What this pipeline does not do: deploy to the cluster

`update_manifest` stops at committing the new tag to `values.yaml`. It does not
run `helm upgrade` against the cluster. This is deliberate, not an oversight:
the cluster here is a local `kind` cluster (see `kubernetes.md`), and GitHub's
hosted runners have no network path to a laptop's local cluster — there's no
config fix for that, it's a real reachability constraint.

In a real deployment (cloud-managed cluster, or a self-hosted runner with
cluster access), the natural next step is either:
- a final CI step running `helm upgrade -f values-secret.yaml` directly, or
- a GitOps controller (ArgoCD/Flux) watching this repo and reconciling
  `values.yaml` changes into the cluster automatically — the values.yaml-commit
  pattern above is exactly what GitOps tooling expects to watch.

For this project, the last step is manual: after a merge to `main`, pull the
latest `values.yaml` and run the upgrade command in `helm.md`.

## Getting the pipeline to this state

This was built incrementally on `feat/pipeline`, tested via manual
`workflow_dispatch` runs and direct pushes to that branch before merging.
Real issues hit along the way (worth knowing about if extending this):

- `workflow_dispatch` only appears as a runnable option in the GitHub UI for
  workflow files that exist on the **default branch** — a workflow file that
  only exists on a feature branch is invisible to manual dispatch entirely.
  Testing pre-merge required temporarily adding the feature branch to the
  `push` trigger instead.
- Job outputs don't cross job boundaries implicitly. `update_manifest` needed
  `needs.build_push.outputs.image_tag`, wired explicitly via the `outputs:`
  block on `build_push` — passing data between jobs isn't automatic even
  though they're in the same workflow file.
- Pushing from a job requires `contents: write` explicitly — the default
  `GITHUB_TOKEN` scope, even with `actions/checkout` handling auth, is
  read-only unless the workflow grants more.
