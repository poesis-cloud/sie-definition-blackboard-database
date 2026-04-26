# SIE Definition Blackboard Database deployables

This folder contains ops/runtime assets for the Definition Blackboard Database service.

- `ops/helm/`: Helm chart for Kubernetes deployments (dev/stage/prod depending cluster/context)

## Helm

Chart path:

- `ops/helm`

Install with defaults:

```bash
helm upgrade --install sie-definition-blackboard-database \
  sie/sie-definition-blackboard-database/ops/helm \
  -n sie --create-namespace
```

Environment values:

- `environments/dev/values.yaml`
- `environments/preprod/values.yaml`
- `environments/prod/values.yaml`

Each environment file is self-contained and carries the chart defaults for that
target environment.

Recommended deploy command:

```bash
helm upgrade --install sie-definition-blackboard-database \
  sie/sie-definition-blackboard-database/ops/helm \
  -n sie --create-namespace \
  -f sie/sie-definition-blackboard-database/ops/helm/environments/preprod/values.yaml \
  --set-string secrets.DB_PASSWORD="$DB_PASSWORD"
```

Secrets policy:

- Never commit production secrets in values files.
- Never commit even placeholder database passwords in tracked values files.
- Inject the password at deploy time (`--set-string secrets.DB_PASSWORD=...`) or

  provide `postgres.existingSecret` from a cluster secret manager.

- If `postgres.existingSecret` is not set, the chart requires

  `secrets.DB_PASSWORD` explicitly.

Schema validation:

- Validate the target environment values file directly with `helm lint`.
