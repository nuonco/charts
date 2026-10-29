#!/usr/bin/env bash
# Renders the chart and checks that ingress.enabled=false drops every ingress resource but keeps the NEG Service.
set -euo pipefail

chart="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

render() {
  helm template dashboard-ui "$chart" -f "$chart/ci/test-values.yaml" "$@"
}

ingress_count() {
  printf '%s\n' "$1" | yq 'select(.kind | test("^(Ingress|HTTPRoute|HealthCheckPolicy|GCPBackendPolicy)$")) | .kind' | grep -c -v -e '^---$' -e '^$' || true
}

[ "$(ingress_count "$(render)")" != "0" ] || fail "ALB Ingress missing with default values"
[ "$(ingress_count "$(render --set gcp.enabled=true)")" != "0" ] || fail "GCP ingress resources missing with gcp.enabled"
[ "$(ingress_count "$(render --set ingress.enabled=false)")" = "0" ] || fail "ALB Ingress rendered with ingress.enabled=false"
[ "$(ingress_count "$(render --set gcp.enabled=true --set ingress.enabled=false)")" = "0" ] || fail "GCP ingress resources rendered with ingress.enabled=false"

no_ingress="$(render --set gcp.enabled=true --set ingress.enabled=false)"
[ "$(printf '%s\n' "$no_ingress" | yq 'select(.kind == "Service" and .metadata.name == "dashboard-ui-neg") | .metadata.name')" = "dashboard-ui-neg" ] || fail "NEG Service missing with ingress.enabled=false"

echo "dashboard-ui render tests passed"
