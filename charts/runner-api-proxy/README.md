# runner-api-proxy

Reverse proxy for white-labeling the Nuon runner API behind your own domain. Deploys an nginx pod that routes traffic to Nuon's backend, keeping Nuon URLs invisible to your customers' infrastructure.

## How it works

| Path | Routed to |
|---|---|
| `/v1/installs/*/phone-home/*` | `upstream.publicAPIURL` (Nuon public API) |
| Everything else | `upstream.runnerAPIURL` (Nuon runner API) |

Once deployed, set both `runner_api_url` and `public_api_url` in your app's `runner.toml` to your proxy domain. All runner traffic — heartbeats, job polling, logs, phone-home callbacks — flows through your domain with no Nuon URLs visible.

## Prerequisites

- Kubernetes cluster with an ingress controller (nginx, ALB, GCE, etc.)
- A domain you control pointing at the cluster's ingress
- TLS certificate (cert-manager recommended)
- Nuon runner API URL and public API URL (provided by Nuon)

## Installation

```bash
helm install runner-api-proxy oci://ghcr.io/nuonco/charts/runner-api-proxy \
  --set upstream.runnerAPIURL=https://runner-api.nuon.co \
  --set upstream.publicAPIURL=https://api.nuon.co \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.host=runner-api.acme.com \
  --set ingress.tls.enabled=true \
  --set ingress.tls.secretName=runner-api-tls
```

Or with a values file:

```yaml
# values.yaml
upstream:
  runnerAPIURL: "https://runner-api.nuon.co"
  publicAPIURL: "https://api.nuon.co"

ingress:
  enabled: true
  className: nginx
  host: runner-api.acme.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    enabled: true
    secretName: runner-api-tls
```

```bash
helm install runner-api-proxy oci://ghcr.io/nuonco/charts/runner-api-proxy -f values.yaml
```

## Nuon app config

In your app's `runner.toml`, set both URLs to your proxy domain:

```toml
runner_type      = "gcp"   # or aws, azure
runner_api_url   = "https://runner-api.acme.com"
public_api_url   = "https://runner-api.acme.com"
```

Both point at the same proxy — the chart's routing rules send each request to the right Nuon backend automatically.

## Values

| Name | Description | Default |
|---|---|---|
| `upstream.runnerAPIURL` | Nuon runner API to proxy to | `https://runner-api.nuon.co` |
| `upstream.publicAPIURL` | Nuon public API to proxy to | `https://api.nuon.co` |
| `replicaCount` | Number of proxy replicas | `2` |
| `image.repository` | nginx image | `nginx` |
| `image.tag` | nginx tag | `1.27-alpine` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Create ingress resource | `false` |
| `ingress.className` | Ingress class | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.host` | Hostname to expose the proxy on | `""` |
| `ingress.tls.enabled` | Enable TLS on the ingress | `false` |
| `ingress.tls.secretName` | TLS secret name | `""` |
| `resources` | Pod resource requests/limits | see values.yaml |

## DNS

Point your domain at the cluster ingress (LoadBalancer IP or hostname). Example with external-dns:

```yaml
ingress:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: runner-api.acme.com
```

Or manually:

```
runner-api.acme.com → CNAME → <ingress-load-balancer-hostname>
```
