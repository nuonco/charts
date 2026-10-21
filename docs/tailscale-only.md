# Tailscale-only BYOC control plane

BYOC control planes can expose the ctl-api public API and dashboard only on the customer's tailnet. The runner API stays on the public load balancer.

## Values

ctl-api chart:

```yaml
api:
  public:
    exposure: both
    tailscale:
      host: api
      proxyGroup: control-plane-ingress
```

dashboard-ui chart:

```yaml
ui:
  exposure: both
  tailscale:
    host: dashboard
    proxyGroup: control-plane-ingress
```

`exposure` accepts `internet` (the default), `both`, or `tailscale`. Any other value fails the Helm render.

## Prerequisites

The customer's cluster needs the Tailscale Kubernetes operator, an IngressClass named `tailscale`, MagicDNS, and HTTPS certificates enabled for the customer's tailnet. The operator OAuth client must be able to create devices and auth keys.

For production, create a Tailscale ingress `ProxyGroup` with at least two replicas and set `proxyGroup` in both charts:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: ProxyGroup
metadata:
  name: control-plane-ingress
spec:
  type: ingress
  replicas: 2
```

Leave `proxyGroup` empty only when a single standalone proxy is acceptable.

The customer must invite approved support identities to their tailnet and grant them access to the `api` and `dashboard` machines in the tailnet policy. The charts do not change the customer's tailnet policy.

## Migration

1. Install the Tailscale operator and meet the prerequisites above.
2. Set both charts to `exposure: both` and upgrade.
3. Wait for both Tailscale Ingresses to have an `ADDRESS`.
4. Confirm the API and dashboard answer at their `https://<host>.<tailnet>.ts.net` addresses from an authorized device.
5. Update ctl-api's `APP_URL` and `PUBLIC_API_URL`, dashboard-ui's `NUON_APP_URL` and `NUON_API_URL`, any frontend API URL built into the dashboard image, CLI profiles, identity-provider callbacks, and any webhook callbacks that use the old public hostnames.
6. Restart ctl-api and dashboard-ui after changing their ConfigMaps. The charts do not automatically restart pods for ConfigMap-only changes.
7. Exercise sign-in, an authenticated API request, and a runner heartbeat. The runner API address must not change.
8. Set both charts to `exposure: tailscale` and upgrade again.
9. Confirm the old public API and dashboard addresses no longer answer.

The operator provisions the `*.ts.net` TLS certificates. The first request can take longer while the certificates are issued.
