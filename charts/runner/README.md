# Runner Helm Chart

This chart deploys one Nuon runner into a pre-existing namespace. The caller
owns the namespace, ServiceAccount, EKS Pod Identity association, runner token
Secret, networking policy, and admission policy.

The chart requires:

- a runner image reference: either `image.digest` (preferred, immutable) or
  `image.tag`, but not both;
- an existing Secret containing `RUNNER_API_TOKEN`;
- an existing ServiceAccount associated with an EKS Pod Identity role; and
- `config.runnerId` and `config.apiUrl`.

Runner settings the chart models live under `config`. Anything else can be
passed through `extraEnv`, which is rendered into the ConfigMap. `extraEnv`
cannot override chart-managed variables, and names that look like secrets
(`*_TOKEN`, `*_SECRET`, `*_PASSWORD`, `*_API_KEY`, ...) fail the render; the
runner token comes only from `existingSecret`.

The chart does not create Kubernetes RBAC, NetworkPolicies, Istio resources, or
admission policies. The runner obtains deployment access by assuming the
separately managed maintenance role.

```sh
helm upgrade --install runner oci://ghcr.io/nuonco/charts/runner \
  --version 0.1.0 \
  --namespace nuon-runner \
  --values values.example.yaml
```

`node_pool.enabled` and `autoscaling.enabled` default to `false`, so neither
Karpenter nor metrics-server is required. If the optional NodePool is enabled,
the cluster must already contain the referenced `EC2NodeClass`.

Istio and Kyverno must enforce the customer-approved runner egress and image
policy before the release is enabled.

> [!WARNING]
> `podLabels` and `podAnnotations` are rendered onto the pod verbatim. Anyone
> who controls these values can opt the runner out of the controls above, for
> example:
>
> - `sidecar.istio.io/inject: "false"` removes the Istio sidecar entirely;
> - `traffic.sidecar.istio.io/excludeOutboundIPRanges: 0.0.0.0/0` (or
>   `excludeOutboundPorts`) bypasses egress capture;
> - `container.apparmor.security.beta.kubernetes.io/<container>: unconfined`
>   disables AppArmor; and
> - labels matched by Kyverno policy exclusions skip admission checks.
>
> The chart does not filter these keys. Enforce egress and admission policy at
> the cluster level (Kyverno rules rejecting these labels and annotations on
> runner pods, Istio `REGISTRY_ONLY` outbound policy, and a NetworkPolicy that
> does not depend on the sidecar) rather than relying on the rendered pod spec.
