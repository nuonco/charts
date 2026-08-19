# ctl-api

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.0.1](https://img.shields.io/badge/AppVersion-0.0.1-informational?style=flat-square)

A helm chart for deploying the ctl-api (api and workers).

## Overview

This chart deploys the ctl-api, which consists of:

- **API servers** — admin, auth, public, and runner endpoints, each behind their own ingress/ALB
- **Workers** — Temporal worker deployments, dynamically created from `worker.instances`
- **Consumers** — Kafka consumer deployments, dynamically created from `consumer.instances`

The chart supports both AWS (ALB-based ingress) and GCP (Gateway API) deployments.

## Installing the Chart

```bash
helm install ctl-api oci://ghcr.io/nuonco/charts/ctl-api --version <version>
```

## Environment Variables

The `env` map is passed directly into the ConfigMap consumed by all API and worker pods. The following variables are supported by the ctl-api application:

| Variable                                          | Required | Description                                         |
| ------------------------------------------------- | -------- | --------------------------------------------------- |
| **General**                                       |          |                                                     |
| `ENV`                                             | yes      | Environment name (e.g. `prod`, `staging`)           |
| `LOG_LEVEL`                                       | no       | Log level (`DEBUG`, `INFO`, `WARN`, `ERROR`)        |
| `GIN_MODE`                                        | no       | Gin framework mode (`release`, `debug`)             |
| `ROOT_DOMAIN`                                     | yes      | Root domain for the deployment                      |
| `APP_URL`                                         | yes      | Full URL of the dashboard UI                        |
| `PUBLIC_API_URL`                                  | yes      | Full URL of the public API                          |
| `RUNNER_API_URL`                                  | yes      | Full URL of the runner API                          |
| `ADMIN_API_URL`                                   | yes      | Full URL of the admin API                           |
| **HTTP**                                          |          |                                                     |
| `HTTP_PORT`                                       | no       | Public API listen port                              |
| `INTERNAL_HTTP_PORT`                              | no       | Internal/admin API listen port                      |
| `RUNNER_HTTP_PORT`                                | no       | Runner API listen port                              |
| `GRACEFUL_SHUTDOWN_TIMEOUT`                       | no       | Graceful shutdown duration (e.g. `10s`)             |
| `MIDDLEWARES`                                     | yes      | Comma-separated middleware chain for the public API |
| `RUNNER_MIDDLEWARES`                              | yes      | Comma-separated middleware chain for the runner API |
| `INTERNAL_MIDDLEWARES`                            | yes      | Comma-separated middleware chain for the admin API  |
| **Database (PostgreSQL)**                         |          |                                                     |
| `DB_HOST`                                         | yes      | PostgreSQL host                                     |
| `DB_NAME`                                         | yes      | PostgreSQL database name                            |
| `DB_USER`                                         | yes      | PostgreSQL user                                     |
| `DB_REGION`                                       | yes      | AWS region for IAM auth                             |
| `DB_USE_SSL`                                      | no       | Enable TLS (`true`/`false`)                         |
| `DB_SSL_MODE`                                     | no       | TLS mode (e.g. `verify-full`)                       |
| `DB_USE_ZAP`                                      | no       | Use Zap logger for DB queries                       |
| `DB_USE_IAM`                                      | no       | Use IAM authentication for RDS                      |
| `DB_MIGRATIONS_PATH`                              | no       | Path to migration files                             |
| **ClickHouse**                                    |          |                                                     |
| `CLICKHOUSE_DB_HOST`                              | yes      | ClickHouse host                                     |
| `CLICKHOUSE_DB_PORT`                              | yes      | ClickHouse native port                              |
| `CLICKHOUSE_DB_NAME`                              | yes      | ClickHouse database name                            |
| `CLICKHOUSE_DB_USER`                              | yes      | ClickHouse user                                     |
| `CLICKHOUSE_DB_PASSWORD`                          | yes      | ClickHouse password (via `envSecrets`)              |
| `CLICKHOUSE_DB_USE_TLS`                           | no       | Enable TLS for ClickHouse                           |
| **Auth / OIDC**                                   |          |                                                     |
| `NUON_AUTH_PROVIDER_TYPE`                         | yes      | Auth provider type (e.g. `google`, `oidc`)          |
| `NUON_AUTH_CLIENT_ID`                             | yes      | OIDC client ID                                      |
| `NUON_AUTH_CLIENT_SECRET`                         | yes      | OIDC client secret (via `envSecrets`)               |
| `NUON_AUTH_ISSUER_URL`                            | yes      | OIDC issuer URL                                     |
| `NUON_AUTH_REDIRECT_URL`                          | yes      | OIDC redirect URL                                   |
| `NUON_AUTH_SESSION_KEY`                           | yes      | Session encryption key (via `envSecrets`)           |
| `NUON_AUTH_ALLOWED_DOMAINS`                       | no       | Comma-separated allowed email domains               |
| `NUON_AUTH_ALLOW_ALL_USERS`                       | no       | Allow any authenticated user (`true`/`false`)       |
| **Temporal**                                      |          |                                                     |
| `TEMPORAL_HOST`                                   | yes      | Temporal frontend address (host:port)               |
| `TEMPORAL_MAX_CONCURRENT_ACTIVITIES`              | no       | Max concurrent Temporal activities                  |
| `TEMPORAL_STICKY_WORKFLOW_CACHE_SIZE`             | no       | Sticky workflow cache size                          |
| `TEMPORAL_UI_URL`                                 | no       | Temporal UI URL                                     |
| `TEMPORAL_WORKFLOW_FAILURE_PANIC`                 | no       | Panic on workflow failure (`true`/`false`)          |
| `SANDBOX_MODE_SLEEP`                              | no       | Sleep duration in sandbox mode                      |
| **Runner**                                        |          |                                                     |
| `RUNNER_CONTAINER_IMAGE_URL`                      | yes      | Container image URL for runners                     |
| `RUNNER_CONTAINER_IMAGE_TAG`                      | yes      | Container image tag for runners                     |
| `APP_REGION`                                      | yes      | AWS region for the application                      |
| **Management / Infrastructure**                   |          |                                                     |
| `MANAGEMENT_ACCOUNT_ID`                           | yes      | AWS account ID for the management account           |
| `MANAGEMENT_ECR_REGISTRY_ARN`                     | yes      | ECR registry ARN                                    |
| `MANAGEMENT_ECR_REGISTRY_ID`                      | yes      | ECR registry ID                                     |
| `MANAGEMENT_IAM_ROLE_ARN`                         | yes      | IAM role ARN for org access                         |
| **DNS**                                           |          |                                                     |
| `DNS_MANAGEMENT_IAM_ROLE_ARN`                     | yes      | IAM role ARN for DNS management                     |
| `DNS_ROOT_DOMAIN`                                 | yes      | Route 53 root domain                                |
| `DNS_ZONE_ID`                                     | yes      | Route 53 hosted zone ID                             |
| **Org Runner (K8s)**                              |          |                                                     |
| `ORG_RUNNER_K8S_CA_DATA`                          | yes      | Cluster CA certificate data                         |
| `ORG_RUNNER_K8S_CLUSTER_ID`                       | yes      | EKS cluster name                                    |
| `ORG_RUNNER_K8S_IAM_ROLE_ARN`                     | yes      | IAM role ARN for cluster access                     |
| `ORG_RUNNER_K8S_PUBLIC_ENDPOINT`                  | yes      | EKS cluster API endpoint                            |
| `ORG_RUNNER_OIDC_PROVIDER_ARN`                    | yes      | EKS OIDC provider ARN                               |
| `ORG_RUNNER_OIDC_PROVIDER_URL`                    | yes      | EKS OIDC provider URL                               |
| `ORG_RUNNER_REGION`                               | yes      | AWS region for the runner cluster                   |
| `ORG_RUNNER_K8S_USE_DEFAULT_CREDS`                | no       | Use default credentials for K8s auth                |
| `ORG_RUNNER_SUPPORT_ROLE_ARN`                     | no       | IAM role ARN for internal support access            |
| `RUNNER_DEFAULT_SUPPORT_IAM_ROLE_ARN`             | no       | Default support IAM role ARN                        |
| **CloudFormation**                                |          |                                                     |
| `AWS_CLOUDFORMATION_STACK_TEMPLATE_BASE_URL`      | yes      | S3 base URL for CloudFormation templates            |
| `AWS_CLOUDFORMATION_STACK_TEMPLATE_BUCKET`        | yes      | S3 bucket name for CloudFormation templates         |
| `AWS_CLOUDFORMATION_STACK_TEMPLATE_BUCKET_REGION` | yes      | S3 bucket region                                    |
| **GitHub**                                        |          |                                                     |
| `GITHUB_APP_ID`                                   | yes      | GitHub App ID                                       |
| `GITHUB_APP_KEY`                                  | yes      | GitHub App private key (via `envSecrets`)           |
| `INTEGRATION_GITHUB_INSTALL_ID`                   | no       | GitHub App installation ID                          |
| **Kafka**                                         |          |                                                     |
| `KAFKA_ENABLED`                                   | no       | Produce to and consume from Kafka. While `false` the producer no-ops and every path it fronts takes its legacy inline ClickHouse write, and the consumers run healthy holding no partitions. |
| `KAFKA_BROKERS`                                   | no       | Bootstrap address, e.g. `nuon-kafka-bootstrap.kafka.svc.cluster.local:9093` |
| `KAFKA_SECURITY_PROTOCOL`                         | no       | `SSL` for mTLS. Not `SASL_SSL` — mTLS is not a SASL mechanism.               |
| `KAFKA_TLS_CA_PATH`                               | no       | Path to `ca.crt`, from the `kafka.certs.caSecret` mount                      |
| `KAFKA_TLS_CERT_PATH`                             | no       | Path to `user.crt`, from the `kafka.certs.userSecret` mount                  |
| `KAFKA_TLS_KEY_PATH`                              | no       | Path to `user.key`, from the `kafka.certs.userSecret` mount                  |
| **Misc**                                          |          |                                                     |
| `EVALUATION_JOURNEY_ENABLED`                      | no       | Enable evaluation journey feature                   |
| `INTERNAL_SLACK_WEBHOOK_URL`                      | no       | Slack webhook URL for internal notifications        |
| `SEGMENT_WRITE_KEY`                               | no       | Segment analytics write key (deprecated)            |
| `LOOPS_API_KEY`                                   | no       | Loops API key                                       |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| api.admin.autoscaling.maxReplicas | int | `3` | Maximum replicas for admin API |
| api.admin.autoscaling.minReplicas | int | `1` | Minimum replicas for admin API |
| api.admin.autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization for admin API autoscaling |
| api.admin.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Target memory utilization for admin API autoscaling |
| api.admin.domain | string | `""` | Admin API domain |
| api.admin.port | int | `8080` | Admin API container port |
| api.auth.autoscaling.maxReplicas | int | `3` | Maximum replicas for auth API |
| api.auth.autoscaling.minReplicas | int | `1` | Minimum replicas for auth API |
| api.auth.autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization for auth API autoscaling |
| api.auth.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Target memory utilization for auth API autoscaling |
| api.auth.domain | string | `""` | Auth API domain |
| api.auth.domain_certificate | string | `""` | Auth API TLS certificate ARN (AWS) or name (GCP) |
| api.auth.port | int | `8080` | Auth API container port |
| api.liveness_probe | object | `{}` | Liveness probe configuration for API deployments |
| api.nodeSelector | object | `{}` | Node selector for API pods |
| api.public.autoscaling.maxReplicas | int | `3` | Maximum replicas for public API |
| api.public.autoscaling.minReplicas | int | `1` | Minimum replicas for public API |
| api.public.autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization for public API autoscaling |
| api.public.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Target memory utilization for public API autoscaling |
| api.public.domain | string | `""` | Public API domain |
| api.public.domain_certificate | string | `""` | Public API TLS certificate ARN (AWS) or name (GCP) |
| api.public.port | int | `8080` | Public API container port |
| api.readiness_probe | object | `{}` | Readiness probe configuration for API deployments |
| api.resources.limits.cpu | string | `"500m"` | CPU limit for API containers |
| api.resources.limits.memory | string | `"512Mi"` | Memory limit for API containers |
| api.resources.requests.cpu | string | `"100m"` | CPU request for API containers |
| api.resources.requests.memory | string | `"128Mi"` | Memory request for API containers |
| api.runner.autoscaling.maxReplicas | int | `3` | Maximum replicas for runner API |
| api.runner.autoscaling.minReplicas | int | `1` | Minimum replicas for runner API |
| api.runner.autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization for runner API autoscaling |
| api.runner.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Target memory utilization for runner API autoscaling |
| api.runner.domain | string | `""` | Runner API domain |
| api.runner.domain_certificate | string | `""` | Runner API TLS certificate ARN (AWS) or name (GCP) |
| api.runner.port | int | `8080` | Runner API container port |
| api.tolerations | list | `[]` | Tolerations for API pods |
| api.topologySpreadConstraints | list | `[]` | Topology spread constraints for API pods (applied to admin, auth, public, runner, startup) |
| auth.enabled | bool | `false` | Enable the auth API endpoint |
| auth.envSecrets | list | `[]` | Secrets specific to the auth API |
| consumer | object | no consumers | Kafka consumer deployments. Each entry creates a Deployment plus a pinned HPA. Named for what they consume rather than where they write; `--name` takes a list, so consumers that should scale and fail together can share a pod. |
| consumer.autoscaling.targetCPUUtilizationPercentage | int | `75` | Target CPU utilization. Inert while every instance has `minReplicas == maxReplicas`; see the header in `consumer_hpas.tpl` before relying on it, and do not add a memory metric. |
| consumer.instances | list | `[]` | Consumer instance definitions. Each entry creates a separate Deployment. Example: ```yaml instances:   - name: heartbeats     replicas: 4     command: ["/bin/service", "consumer", "--name=heartbeats"]     resources:       requests:         cpu: "200m"         memory: "256Mi" ``` |
| consumer.nodeSelector | object | `{}` | Node selector for consumer pods |
| consumer.resources | object | `{}` | Default resource requests/limits for all consumers (can be overridden per instance) |
| consumer.tolerations | list | `[]` | Tolerations for consumer pods |
| consumer.topologySpreadConstraints | list | `[]` | Topology spread constraints for consumer pods. Scoped per instance, so one consumer's placement never constrains another's. |
| env | object | `{}` | Environment variables set via the ConfigMap (key/value pairs) |
| envSecrets | list | `[]` | Secrets to inject as environment variables Example: ```yaml envSecrets:   - name: SECRET_KEY     valueFrom:       name: my-secret       key: secret-key ``` |
| environment | string | `""` | Deployment environment name (e.g. `production`, `staging`) |
| fullnameOverride | string | `""` | Override the full release name |
| gcp | object | disabled | GCP-specific configuration. When enabled, GCP Gateway/HTTPRoute/HealthCheckPolicy resources are created instead of AWS ALBs. |
| gcp.certMap | string | `""` | GCP certificate map name for the gateway |
| gcp.enabled | bool | `false` | Enable GCP ingress resources (Gateway API). Requires the Gateway API and `networking.gke.io` CRDs to be installed on the cluster. |
| image.repository | string | `""` | Container image repository |
| image.tag | string | `""` | Container image tag |
| kafka | object | - | Kafka client configuration. The connection itself is configured through `env` (`KAFKA_ENABLED`, `KAFKA_BROKERS`, `KAFKA_SECURITY_PROTOCOL` and the `KAFKA_TLS_*` paths); this block only names the cert secrets. The certs are mounted unconditionally into every pod that produces or consumes. Both are mounted `optional: true`, so an install where Kafka has not been provisioned yet — or where Reflector has not mirrored the secrets into this namespace yet — still starts normally; the volumes are simply empty and nothing reads them while `KAFKA_ENABLED` is false. |
| kafka.certs.caSecret | string | `"nuon-cluster-ca-cert"` | Secret holding `ca.crt`, used to verify the brokers. Created by Strimzi in the Kafka namespace as `<cluster>-cluster-ca-cert` and mirrored into this namespace. Derived from the Kafka CR name, so it is the same in every environment. |
| kafka.certs.userSecret | string | `"ctl-api"` | Secret holding `user.crt` and `user.key`, this client's own identity. Created by Strimzi from the `KafkaUser` of the same name and mirrored into this namespace. |
| nameOverride | string | `""` | Override the chart name |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.enabled | bool | `true` | Whether to create and use a service account |
| serviceAccount.name | string | `""` | Service account name |
| worker.autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization for worker autoscaling |
| worker.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Target memory utilization for worker autoscaling |
| worker.instances | list | `[]` | Worker instance definitions. Each entry creates a separate Deployment. Example: ```yaml instances:   - namespace: my-temporal-ns     command: ["./worker", "--namespace", "my-temporal-ns"]     resources:       requests:         cpu: "200m"         memory: "256Mi" ``` |
| worker.nodeSelector | object | `{}` | Node selector for worker pods |
| worker.resources | object | `{}` | Default resource requests/limits for all workers (can be overridden per instance) |
| worker.tolerations | list | `[]` | Tolerations for worker pods |
| worker.topologySpreadConstraints | list | `[]` | Topology spread constraints for worker pods |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
