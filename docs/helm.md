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

## Verified


```
  kubectl get pods -n saurav-shop -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'
app-server-5566f8cdf9-9mwtt     {"app":"app-server","pod-template-hash":"5566f8cdf9"}
app-worker-7b7dff4884-8x7fd     {"app":"app-worker","pod-template-hash":"7b7dff4884"}
postgres-89bcb5fc4-tmkwt        {"app":"postgres","pod-template-hash":"89bcb5fc4"}

  helm list -A
NAME            NAMESPACE       REVISION        UPDATED                                         STATUS          CHART                   APP VERSION
saurav-shop     saurav-shop     1               2026-08-11 16:20:52.306336619 +0545 +0545       deployed        saurav-shop-0.1.0       3.7.2

  helm status saurav-shop -n saurav-shop
NAME: saurav-shop
LAST DEPLOYED: Tue Aug 11 16:20:52 2026
NAMESPACE: saurav-shop
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
RESOURCES:
==> v1/Pod(related)
NAME                       READY   STATUS    RESTARTS   AGE
postgres-89bcb5fc4-tmkwt   1/1     Running   0          5m44s
app-server-5566f8cdf9-9mwtt   1/1   Running   0     4m47s
app-worker-7b7dff4884-8x7fd   1/1   Running   0     4m47s

==> v1/Namespace
NAME          STATUS   AGE
saurav-shop   Active   5m44s

==> v1/Secret
NAME        TYPE     DATA   AGE
db-secret   Opaque   8      5m44s

==> v1/ConfigMap
NAME         DATA   AGE
app-config   6      5m44s

==> v1/PersistentVolumeClaim
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
postgres-pvc   Bound    pvc-d3fd5fc0-6708-4939-87a4-b100bc66e769   1Gi        RWO            standard       <unset>                 5m44s

==> v1/Service
NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
app-server   NodePort   10.96.148.130   <none>        3000:31962/TCP   5m44s
postgres   ClusterIP   10.96.38.168   <none>   5432/TCP   5m44s

==> v1/Deployment
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
postgres   1/1     1            1           5m44s
app-server   1/1   1     1     5m44s
app-worker   1/1   1     1     5m44s


TEST SUITE: None
NOTES:
Saurav Shop deployed.

Check status:
  kubectl get pods -n saurav-shop

Access the app locally:
  kubectl port-forward -n saurav-shop svc/app-server 3000:3000
  open http://localhost:3000/dashboard
```
## Uninstall

    `helm uninstall saurav-shop -n saurav-shop`
