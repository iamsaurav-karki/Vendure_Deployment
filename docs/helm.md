# saurav-shop Helm chart

Deploys the full stack: Postgres, app-server, app-worker.

## Install

Secrets are not stored in values.yaml. They will be passed at install time:

```
    helm install saurav-shop helm/saurav-shop \
      -n saurav-shop --create-namespace \
      --set secrets.postgresUser=<user> \
      --set secrets.postgresPassword='<password>' \
      --set secrets.postgresDb=<dbname> \
      --set secrets.dbUsername=<user> \
      --set secrets.dbPassword='<password>' \
      --set secrets.cookieSecret='<random string>' \
      --set secrets.superadminUsername=<admin username> \
      --set secrets.superadminPassword='<admin password>'
```

Or can put in an untracked values-secret.yaml and run:

```
    helm install saurav-shop helm/saurav-shop \
      -n saurav-shop --create-namespace \
      -f values-secret.yaml

```
## Upgrade (used by CI)

```
    helm upgrade --install saurav-shop helm/saurav-shop \
      -n saurav-shop --create-namespace \
      --set image.repository=ghcr.io/<org>/saurav-shop \
      --set image.tag=<git-sha> \
      -f values-secret.yaml
```

## First deploy: apply the initial migration

The chart does not run migrations automatically on first install (see
docs/kubernetes.md for why — no automated migration job exists yet).
After the first install against a fresh database:

    `kubectl port-forward -n saurav-shop svc/postgres 5432:5432`

In another terminal, from saurav-shop/, temporarily set DB_HOST=localhost
in .env, then:

    `npx vendure migrate`

Select "Run pending migrations". Revert DB_HOST afterward.

## Uninstall

    `helm uninstall saurav-shop -n saurav-shop`
