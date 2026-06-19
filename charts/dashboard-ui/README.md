# dashboard-ui

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

A helm chart for deploying the dashboard-ui

## Overview

This chart deploys the ctl-api, which consists of:

- **API servers** — admin, auth, public, and runner endpoints, each behind their own ingress/ALB
- **Workers** — Temporal worker deployments, dynamically created from `worker.instances`

The chart supports both AWS (ALB-based ingress) and GCP (Gateway API) deployments.

## Installing the Chart

```bash
helm install ctl-api oci://ghcr.io/nuonco/charts/ctl-api --version <version>
```

## Environment Variables

The `env` map is passed directly into the ConfigMap consumed by all API and worker pods. The following variables are supported by the ctl-api application:

# dashboard-ui Environment Variables

The `env` map is passed directly into the ConfigMap consumed by all dashboard-ui pods.

| Variable                           | Required | Description                                                      |
| ---------------------------------- | -------- | ---------------------------------------------------------------- |
| **General**                        |          |                                                                  |
| `ENV`                              | yes      | Environment name (e.g. `byoc`, `staging`)                        |
| `HTTP_PORT`                        | no       | HTTP listen port                                                 |
| `NUON_BYOC`                        | no       | Flag indicating a BYOC deployment (`true`/`false`)               |
| `METRICS_TAGS`                     | no       | Comma-separated Datadog metric tags (e.g. `org_id:x,org_name:y`) |
| **API URLs**                       |          |                                                                  |
| `NUON_API_URL`                     | yes      | Server-side Nuon API URL                                         |
| `NEXT_PUBLIC_API_URL`              | yes      | Client-side Nuon API URL                                         |
| `NUON_CTL_API_ADMIN_URL`           | yes      | Internal admin API URL                                           |
| `NUON_TEMPORAL_UI_URL`             | no       | Temporal UI URL                                                  |
| `NUON_APP_URL`                     | yes      | Public URL of the dashboard app                                  |
| **Datadog**                        |          |                                                                  |
| `NEXT_PUBLIC_DATADOG_ENV`          | no       | Datadog environment tag                                          |
| `NEXT_PUBLIC_DATADOG_SITE`         | no       | Datadog site (e.g. `us5.datadoghq.com`)                          |
| `NEXT_PUBLIC_DATADOG_CLIENT_TOKEN` | no       | Datadog RUM client token                                         |
| `NEXT_PUBLIC_DATADOG_APP_ID`       | no       | Datadog RUM application ID                                       |
| **Auth**                           |          |                                                                  |
| `NUON_AUTH_SERVICE_URL`            | no       | Nuon auth service URL; non-empty value enables Nuon auth         |
| `AUTH0_CLIENT_SECRET`              | yes      | Auth0 client secret (via `envSecrets`)                           |
| `AUTH0_SECRET`                     | yes      | Auth0 session secret (via `envSecrets`)                          |
| **GitHub**                         |          |                                                                  |
| `GITHUB_APP_NAME`                  | yes      | GitHub App name                                                  |
| **Feature Flags**                  |          |                                                                  |
| `NUON_CANCEL_JOBS`                 | no       | Enable job cancellation UI (`true`/`false`)                      |
| `NUON_DEPLOY_DATA`                 | no       | Enable deploy data UI (`true`/`false`)                           |
| `NUON_INSTALL_REPROVISION`         | no       | Enable install reprovision UI (`true`/`false`)                   |
| `NUON_INSTALL_UPDATE`              | no       | Enable install update UI (`true`/`false`)                        |
| `NUON_ORG_DASHBOARD`               | no       | Enable org dashboard UI (`true`/`false`)                         |
| `NUON_ORG_RUNNER`                  | no       | Enable org runner UI (`true`/`false`)                            |
| `NUON_ORG_SETTINGS`                | no       | Enable org settings UI (`true`/`false`)                          |
| `NUON_ORG_SUPPORT`                 | no       | Enable org support UI (`true`/`false`)                           |
| `NUON_RUNNERS`                     | no       | Enable runners UI (`true`/`false`)                               |
| `NUON_WORKFLOWS`                   | no       | Enable workflows UI (`true`/`false`)                             |
| **Misc**                           |          |                                                                  |
| `SEGMENT_WRITE_KEY`                | no       | Segment analytics write key (set `false` to disable)             |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| env | object | `{}` | Environment variables set via the ConfigMap (key/value pairs) |
| envSecrets | list | `[]` | Secrets to inject as environment variables |
| environment | string | `""` | Deployment environment name (e.g. `production`, `staging`) |
| fullnameOverride | string | `""` | Override the full release name |
| gcp | object | disabled | GCP-specific configuration. When set, GCP ingress resources are created instead of AWS ALBs. |
| image.repository | string | `""` | Container image repository |
| image.tag | string | `""` | Container image tag |
| nameOverride | string | `""` | Override the chart name |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.enabled | bool | `true` | Whether to create and use a service account |
| serviceAccount.name | string | `""` | Service account name |
| ui.alb.public_domain | string | `""` | Public domain for the ALB |
| ui.alb.public_domain_certificate | string | `""` | TLS certificate ARN (AWS) for the ALB |
| ui.autoscaling.maxReplicas | int | `5` | Maximum replicas |
| ui.autoscaling.minReplicas | int | `2` | Minimum replicas |
| ui.autoscaling.targetCPUUtilizationPercentage | int | `50` | Target CPU utilization for autoscaling |
| ui.autoscaling.targetMemoryUtilizationPercentage | int | `50` | Target memory utilization for autoscaling |
| ui.liveness_probe | string | `"/livez"` | Liveness probe path |
| ui.nodeSelector | object | `{}` | Node selector for UI pods |
| ui.port | int | `4000` | UI container port |
| ui.readiness_probe | string | `"/readyz"` | Readiness probe path |
| ui.resources | object | `{"limits":{"cpu":"1000m","memory":"1024Mi"},"requests":{"cpu":"500m","memory":"512Mi"}}` | Resources for the ui deployment. Both `requests` and `limits` are optional and fully overridable — either sub-block can be omitted entirely. |
| ui.resources.limits.cpu | string | `"1000m"` | CPU limit for UI containers |
| ui.resources.limits.memory | string | `"1024Mi"` | Memory limit for UI containers |
| ui.resources.requests.cpu | string | `"500m"` | CPU request for UI containers |
| ui.resources.requests.memory | string | `"512Mi"` | Memory request for UI containers |
| ui.tolerations | list | `[]` | Tolerations for UI pods |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
