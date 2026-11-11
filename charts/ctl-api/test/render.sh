#!/usr/bin/env bash
# Renders the chart with ci/test-values.yaml and checks the standalone NEG Services.
set -euo pipefail

chart="$(cd "$(dirname "$0")/.." && pwd)"
out="$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml")"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

field() {
  printf '%s\n' "$out" | yq "select(.kind == \"Service\" and .metadata.name == \"$1\") | $2"
}

[ "$(field ctl-api-public-neg '.metadata.annotations."cloud.google.com/neg"')" = '{"exposed_ports":{"8080":{"name":"ctl-api-public"}}}' ] || fail "public NEG annotation"
[ "$(field ctl-api-runner-neg '.metadata.annotations."cloud.google.com/neg"')" = '{"exposed_ports":{"8080":{"name":"ctl-api-runner"}}}' ] || fail "runner NEG annotation"
[ "$(field ctl-api-auth-neg '.metadata.annotations."cloud.google.com/neg"')" = '{"exposed_ports":{"80":{"name":"ctl-api-auth"}}}' ] || fail "auth NEG annotation"
[ "$(field ctl-api-mcp-neg '.metadata.annotations."cloud.google.com/neg"')" = '{"exposed_ports":{"80":{"name":"ctl-api-mcp"}}}' ] || fail "mcp NEG annotation"
[ "$(field ctl-api-slack-neg '.metadata.annotations."cloud.google.com/neg"')" = '{"exposed_ports":{"80":{"name":"custom-slack-neg"}}}' ] || fail "slack NEG name override"

for svc in public runner auth mcp slack; do
  [ "$(field "ctl-api-$svc" '.metadata.annotations."cloud.google.com/neg"')" = "null" ] || fail "ctl-api-$svc must not carry a NEG annotation"
  [ "$(field "ctl-api-$svc-neg" '.spec.selector')" = "$(field "ctl-api-$svc" '.spec.selector')" ] || fail "ctl-api-$svc-neg selector differs from ctl-api-$svc"
  [ "$(field "ctl-api-$svc-neg" '.spec.ports')" = "$(field "ctl-api-$svc" '.spec.ports')" ] || fail "ctl-api-$svc-neg ports differ from ctl-api-$svc"
done

default_out="$(helm template ctl-api "$chart")"
neg_count="$(printf '%s\n' "$default_out" | yq 'select(.kind == "Service" and (.metadata.name | test("-neg$"))) | .metadata.name' | grep -c . || true)"
[ "$neg_count" = "0" ] || fail "NEG Services rendered with default values"

ingress_count() {
  printf '%s\n' "$1" | yq 'select(.kind | test("^(Ingress|Gateway|HTTPRoute|HealthCheckPolicy|GCPBackendPolicy|GCPGatewayPolicy)$")) | .kind' | grep -c -v -e '^---$' -e '^$' || true
}

gcp_args=(--set gcp.enabled=true --set gcp.certMap=test --set gcp.psc.enabled=true --set gcp.psc.addressName=test --set "gcp.psc.certificates={test}")

[ "$(ingress_count "$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml")")" != "0" ] || fail "ALB Ingresses missing with default values"
[ "$(ingress_count "$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" "${gcp_args[@]}")")" != "0" ] || fail "GCP ingress resources missing with gcp.enabled"
[ "$(ingress_count "$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set ingress.enabled=false)")" = "0" ] || fail "ALB Ingresses rendered with ingress.enabled=false"
[ "$(ingress_count "$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" "${gcp_args[@]}" --set ingress.enabled=false)")" = "0" ] || fail "GCP ingress resources rendered with ingress.enabled=false"

no_ingress="$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" "${gcp_args[@]}" --set ingress.enabled=false)"
[ "$(printf '%s\n' "$no_ingress" | yq 'select(.kind == "Service" and (.metadata.name | test("-neg$"))) | .metadata.name' | grep -c -- '-neg$')" = "5" ] || fail "NEG Services missing with ingress.enabled=false"

[ -z "$(printf '%s\n' "$default_out" | yq 'select(.kind == "Job") | .metadata.name')" ] || fail "startup hook enabled by default"
for cloud in aws gcp; do
  args=(--namespace ctl-api --set startupHook.enabled=true --set serviceAccount.name=ctl-api
    --set image.repository=example.com/ctl-api --set image.tag=target
    --set env.ENV=prod --set env.RELEASE_MARKER=target
    --set 'envSecrets[0].name=DB_PASSWORD' --set 'envSecrets[0].valueFrom.name=db-secret' --set 'envSecrets[0].valueFrom.key=password')
  if [ "$cloud" = aws ]; then
    annotation='eks.amazonaws.com/role-arn'
    identity='arn:aws:iam::123456789012:role/example'
    args+=(--set 'serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::123456789012:role/example')
  else
    annotation='iam.gke.io/gcp-service-account'
    identity='ctl-api@example.iam.gserviceaccount.com'
    args+=(--is-upgrade --set 'serviceAccount.annotations.iam\.gke\.io/gcp-service-account=ctl-api@example.iam.gserviceaccount.com')
  fi
  hook_out="$(helm template ctl-api "$chart" "${args[@]}")"
  job="$(printf '%s\n' "$hook_out" | yq 'select(.kind == "Job")')"
  [ "$(printf '%s\n' "$job" | yq '.metadata.annotations."helm.sh/hook"')" = pre-install,pre-upgrade ] || fail "$cloud hook events"
  [ "$(printf '%s\n' "$job" | yq '.spec.template.spec.containers[0].image')" = example.com/ctl-api:target ] || fail "$cloud target image"
  [ "$(printf '%s\n' "$job" | yq '.spec.template.spec.containers[0].command | join(" ")')" = '/bin/service startup' ] || fail "$cloud startup command"
  [ "$(printf '%s\n' "$job" | yq '.spec.template.spec.containers[0].envFrom')" = null ] || fail "$cloud depends on application ConfigMap"
  for key in ENV RELEASE_MARKER; do
    expected=target; [ "$key" != ENV ] || expected=prod
    [ "$(printf '%s\n' "$job" | yq ".spec.template.spec.containers[0].env[] | select(.name == \"$key\") | .value")" = "$expected" ] || fail "$cloud target $key"
  done
  [ "$(printf '%s\n' "$job" | yq '.spec.template.spec.containers[0].env[] | select(.name == "DB_PASSWORD") | .valueFrom.secretKeyRef.name')" = db-secret ] || fail "$cloud secret reference"
  [ "$(printf '%s\n' "$job" | yq '.spec.template.spec.serviceAccountName')" = ctl-api-migrate ] || fail "$cloud hook identity"
  [ "$(printf '%s\n' "$hook_out" | yq "select(.kind == \"ServiceAccount\" and .metadata.name == \"ctl-api-migrate\") | .metadata.annotations.\"$annotation\"")" = "$identity" ] || fail "$cloud cloud identity"
  [ "$(printf '%s\n' "$hook_out" | yq 'select(.kind == "RoleBinding" and .metadata.name == "ctl-api-migrate") | .subjects[0].name')" = ctl-api-migrate ] || fail "$cloud RBAC subject"
  [ "$(printf '%s\n' "$job" | yq '.spec.backoffLimit')" = 0 ] || fail "$cloud startup retries"
  [ "$(printf '%s\n' "$job" | yq '.spec.activeDeadlineSeconds')" = 1200 ] || fail "$cloud deadline"
  for kind in ServiceAccount Role RoleBinding; do
    weight="$(printf '%s\n' "$hook_out" | yq "select(.kind == \"$kind\" and .metadata.name == \"ctl-api-migrate\") | .metadata.annotations.\"helm.sh/hook-weight\"")"
    [ "$weight" -lt 0 ] || fail "$cloud $kind must precede startup"
  done
done

echo "ctl-api render tests passed"
