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

echo "ctl-api render tests passed"
