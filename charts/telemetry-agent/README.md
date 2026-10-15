# telemetry-agent

Deploys the Nuon telemetry agent for one install. Existing producers send OTLP
logs, metrics, and traces to its cluster-local Service for forwarding to the
install's configured relay. The agent does not scrape Kubernetes or read node logs.

## Prerequisites

- A reachable HTTPS Nuon **runner API**, not the public API.
- An install ID and an opaque API token for that install's managed telemetry
  service account, supplied either as an existing Secret or as the sensitive
  `bootstrapToken` value. Do not use an org-wide runner or administrator token. See the
  [agent bootstrap instructions](https://github.com/nuonco/nuon/tree/main/bins/telemetry-agent#bootstrap-and-deployment)
  for credential requirements.
- An agent image accessible to the cluster. Supply its repository and tag
  explicitly; the chart does not assume an image has been published.

The chart does not create credentials or Kubernetes RBAC grants. It creates a
bootstrap Secret only when `bootstrapToken` is set.

## Configuration and deployment

Set exactly one credential source; the chart fails if both or neither are set,
without echoing the token.

### Existing Secret (default)

Create the deployment namespace and bootstrap Secret before installing. This keeps
the token out of Helm values and release history. Do not put the token in source
control or command-line arguments:

```sh
kubectl create namespace telemetry
kubectl -n telemetry create secret generic nuon-telemetry-agent-bootstrap \
  --from-file=token=/protected/path/bootstrap-token
```

Remove the local credential file when it is no longer needed. From this repository:

```sh
helm upgrade --install nuon-telemetry charts/telemetry-agent \
  --namespace telemetry \
  --set apiURL=https://runner-api.example.com \
  --set installID=inl_example \
  --set existingSecret.name=nuon-telemetry-agent-bootstrap \
  --set image.repository=registry.example.com/nuon-telemetry-agent \
  --set image.tag=0.1.0
```

### Chart-created Secret

For deployers that deliver the token as a sensitive input (for example, a Nuon
sensitive install input), set `bootstrapToken`. The chart creates
`<release>-agent-bootstrap` with key `token` and mounts it the same way. See
[Security and credential rotation](#security-and-credential-rotation) for the
tradeoff. Supply the value from a protected values file or the deployer's secret
mechanism, never from source control or shell history.

| Value | Purpose |
| --- | --- |
| `apiURL` | Required HTTPS runner API base URL. |
| `installID` | Required Nuon install ID. |
| `bootstrapToken` | Sensitive token; the chart creates the bootstrap Secret. Mutually exclusive with `existingSecret.name`. |
| `existingSecret.name` | Existing Secret in the release namespace. Mutually exclusive with `bootstrapToken`. |
| `existingSecret.key` | Credential key within the existing Secret; defaults to `token`. |
| `image.repository`, `image.tag` | Required agent image and version. |
| `imagePullSecrets` | Existing registry credential Secret references, if needed. |
| `persistence.enabled` | Create a dedicated ReadWriteOnce PVC `<release>-agent-state`, kept on uninstall. Mutually exclusive with `persistence.existingClaim`. |
| `persistence.size` | Chart-created PVC request; defaults to `8Gi`. |
| `persistence.storageClass` | Chart-created PVC StorageClass; empty uses the cluster default. |
| `persistence.existingClaim` | Optional existing dedicated writable PVC. |
| `persistence.sizeLimit` | Default `emptyDir` limit, `8Gi`; unused with a claim. |
| `networkPolicy.enabled` | Create an ingress NetworkPolicy for the agent Pod; default `false`. |
| `networkPolicy.ingress` | `NetworkPolicyIngressRule` list, rendered verbatim. Empty denies all ingress. |
| `resources`, `nodeSelector`, `tolerations` | Pod resource budget and placement. |

Enable forwarding in the install's Nuon telemetry settings. Deploying the agent
or creating its account does not enable telemetry. An intentionally disabled
agent remains healthy, but does not accept new telemetry; producers must retry.

For release `nuon-telemetry` in namespace `telemetry`, configure existing producers
to use `nuon-telemetry-agent.telemetry.svc.cluster.local:4317` (gRPC) or
`http://nuon-telemetry-agent.telemetry.svc.cluster.local:4318` (HTTP). For other
release names or namespaces, use the Service name rendered by Helm.

## Security and credential rotation

**OTLP ingress is unauthenticated.** Apply network policy allowing only trusted
producers for this install, either your own or via `networkPolicy.enabled` with
`networkPolicy.ingress` rules selecting those producers and ports. Enforcement
requires a CNI that supports NetworkPolicy. Do not expose the Service publicly or
use it to aggregate unrelated installs. Outbound relay connections require HTTPS
with certificate verification. For example, to accept only OTLP/HTTP from labeled
producers in the release namespace:

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: api
      ports:
        - protocol: TCP
          port: 4318
```

The pod runs as UID/GID 10001 with a read-only root filesystem, dropped
capabilities, and no Kubernetes service-account token mount. Health checks do
not require exposing a public health endpoint or restarting during relay outages.

**`bootstrapToken` tradeoff.** The token is stored in Helm values and in every
Helm release revision (release Secrets in the namespace), and appears in rendered
output such as `helm get values` or `helm template`. Anyone who can read release
Secrets or run those commands in the namespace can read it. Old revisions retain
superseded tokens until history is pruned (`--history-max`), so revoke replaced
tokens. Use `existingSecret` when the token must stay out of Helm state.

Rotate credentials by issuing a replacement token, updating the Secret (edit the
existing Secret, or upgrade with the new `bootstrapToken`), waiting for the
projected update, then revoking the old token. The Deployment does not change and
an agent restart is not required. Do not replace the directory mount with
`subPath`, which prevents projected Secret updates from reaching the agent.

## Queue durability

Disk-backed buffers are bounded to 1 GiB per signal. Size storage for all
three queues, storage overhead, and compaction; queue limits do not cap disk usage.
Queue overflow rejects input. Producers must honor OTLP errors and retry;
permanent relay rejection can discard data, and delivery is not exactly-once.

By default, state uses `emptyDir`, which survives container restarts but not Pod
replacement. For durability across Pod replacement, set `persistence.enabled` to
create a dedicated claim, or `persistence.existingClaim` to use your own; setting
both fails. The chart uses one replica and `Recreate` to avoid concurrent queue
ownership within the deployment; do not share the claim with another agent.
Protect this volume as sensitive telemetry storage.

The chart-created claim has `helm.sh/resource-policy: keep`, so `helm uninstall`
leaves it and any queued, undelivered telemetry in place. Reinstalling the same
release in the same namespace reuses it. When the data is no longer retained,
delete it explicitly, for example
`kubectl -n telemetry delete pvc nuon-telemetry-agent-state`; the underlying volume
then follows the StorageClass reclaim policy.

## Validation

`ci/test-values.yaml` contains only fictional, non-secret values for chart validation:

```sh
helm lint --strict charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml
helm template test charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml
helm template test charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml \
  --set persistence.existingClaim=telemetry-agent-state
helm template test charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml \
  --set existingSecret.name= --set bootstrapToken=example-not-a-token \
  --set persistence.enabled=true --set networkPolicy.enabled=true
```
