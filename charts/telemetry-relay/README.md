# telemetry-relay

Deploys the Nuon authenticated OTLP/HTTP telemetry relay on Kubernetes. The container's baked-in collector configuration is used unchanged.

## Prerequisites

- Existing Kubernetes Secrets containing the backend endpoint and authorization header, plus a reachable public JWKS endpoint served by ctl-api. The private signing key belongs only to ctl-api and must never be given to the relay. This chart never creates keys, credentials, or Secret objects.
- For GCP: an existing GKE Gateway with an HTTPS listener and DNS/TLS configured for `gateway.hostname`. By default, the route attaches to `external-gateway` in namespace `ctl-api`, listener `https`. The Gateway must allow routes from the relay namespace, and any required cross-namespace permissions must already exist.
- For AWS: the AWS Load Balancer Controller, an ACM certificate for `ingress.domain`, and ExternalDNS or equivalent DNS pointing to the ALB. Backend health checks must be able to reach pod port `13133`.

## Configuration

Both `gcp.enabled` and `aws.enabled` default to `false`. With both disabled, the chart creates only cloud-neutral workload resources and a ClusterIP Service; supply your own ingress if needed. Select the cloud integration explicitly in your app values.

```yaml
image:
  repository: registry.example.com/telemetry-relay
  tag: v1.0.0

env:
  NUON_TELEMETRY_ISSUER: https://issuer.example.com
  NUON_TELEMETRY_JWKS_URL: https://issuer.example.com/.well-known/jwks.json

envSecrets:
  - name: VENDOR_OTLP_ENDPOINT
    valueFrom:
      name: telemetry-relay-backend
      key: endpoint
  - name: VENDOR_OTLP_AUTHORIZATION
    valueFrom:
      name: telemetry-relay-backend
      key: authorization
```

`envSecrets` references keys in Secrets that are provisioned separately. Values are exposed only through `secretKeyRef`; do not put credentials or private key material in `values.yaml` or `env`.

For GCP, add:

```yaml
gcp:
  enabled: true
gateway:
  hostname: telemetry.example.com
```

This creates an HTTPRoute, HealthCheckPolicy, and GCPBackendPolicy. `gateway.hostname` is required only when GCP is enabled.

For AWS, add instead:

```yaml
aws:
  enabled: true
ingress:
  domain: telemetry.example.com
  certificateArn: arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000
```

This creates an internet-facing ALB Ingress with an HTTPS-only listener. `ingress.domain` and `ingress.certificateArn` are required only when AWS is enabled. Set `ingress.groupName` to join an existing ALB ingress group if needed.

Both cloud integrations route exactly `/v1/logs`, `/v1/metrics`, and `/v1/traces`. The health endpoint on port `13133` is used by private pod and load-balancer health checks but is not routed publicly.
