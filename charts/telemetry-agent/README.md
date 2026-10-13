# telemetry-agent

Deploys the Nuon telemetry agent for one install. Existing producers send OTLP
logs, metrics, and traces to its cluster-local Service for forwarding to the
install's configured relay. The agent does not scrape Kubernetes or read node logs.

## Prerequisites

- A reachable HTTPS Nuon **runner API**, not the public API.
- An install ID and a Secret in the deployment namespace containing an opaque
  API token for that install's managed telemetry service account. Do not use an
  org-wide runner or administrator token. See the
  [agent bootstrap instructions](https://github.com/nuonco/nuon/tree/main/bins/telemetry-agent#bootstrap-and-deployment)
  for credential requirements.
- An agent image accessible to the cluster. Supply its repository and tag
  explicitly; the chart does not assume an image has been published.

The chart does not create credentials, Secrets, or Kubernetes RBAC grants.

## Configuration and deployment

Create the deployment namespace and bootstrap Secret before installing. Do not
put the token in Helm values, source control, or command-line arguments:

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

| Value | Purpose |
| --- | --- |
| `apiURL` | Required HTTPS runner API base URL. |
| `installID` | Required Nuon install ID. |
| `existingSecret.name` | Required existing Secret in the release namespace. |
| `existingSecret.key` | Credential key within the Secret; defaults to `token`. |
| `image.repository`, `image.tag` | Required agent image and version. |
| `imagePullSecrets` | Existing registry credential Secret references, if needed. |
| `persistence.existingClaim` | Optional dedicated writable PVC to preserve queues across Pod replacement. |
| `persistence.sizeLimit` | Default `emptyDir` limit, `8Gi`; unused with an existing claim. |
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
producers for this install. Do not expose the Service publicly or use it to
aggregate unrelated installs. Outbound relay connections require HTTPS with
certificate verification.

The pod runs as UID/GID 10001 with a read-only root filesystem, dropped
capabilities, and no Kubernetes service-account token mount. Health checks do
not require exposing a public health endpoint or restarting during relay outages.

Rotate credentials by issuing a replacement token, updating the existing Secret,
waiting for the projected update, then revoking the old token. An agent restart
is not required. Do not replace the directory mount with `subPath`, which prevents
projected Secret updates from reaching the agent.

## Queue durability

Disk-backed buffers are bounded to 1 GiB per signal. Size storage for all
three queues, storage overhead, and compaction; queue limits do not cap disk usage.
Queue overflow rejects input. Producers must honor OTLP errors and retry;
permanent relay rejection can discard data, and delivery is not exactly-once.

By default, state uses `emptyDir`, which survives container restarts but not Pod
replacement. Set `persistence.existingClaim` to a dedicated writable PVC for
durability across Pod replacement. The chart uses one replica and `Recreate` to
avoid concurrent queue ownership within the deployment; do not share the claim
with another agent. Protect this volume as sensitive telemetry storage.

## Validation

`ci/test-values.yaml` contains only fictional, non-secret values for chart validation:

```sh
helm lint --strict charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml
helm template test charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml
helm template test charts/telemetry-agent -f charts/telemetry-agent/ci/test-values.yaml \
  --set persistence.existingClaim=telemetry-agent-state
```
