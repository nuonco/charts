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

grouped="$(render \
  --set env.ENV=prod \
  --set ui.alb.public_domain=app.example.com \
  --set ui.alb.public_domain_certificate=arn:aws:acm:us-east-1:000000000000:certificate/wild \
  --set ui.alb.group_name=nuon-public \
  --set-string 'ui.alb.group_tags=service=nuon-public\,service_type=shared')"
[ "$(printf '%s\n' "$grouped" | yq 'select(.kind == "Ingress") | .metadata.annotations."alb.ingress.kubernetes.io/group.name"')" = "nuon-public" ] || fail "grouped dashboard ingress has no group"
[ "$(printf '%s\n' "$grouped" | yq 'select(.kind == "Ingress") | .metadata.annotations."alb.ingress.kubernetes.io/tags"')" = "service=nuon-public,service_type=shared" ] || fail "grouped dashboard tags differ"
[ "$(printf '%s\n' "$grouped" | yq 'select(.kind == "Ingress") | .spec.rules[0].host')" = "app.example.com" ] || fail "grouped dashboard ingress has no host"
[ "$(printf '%s\n' "$grouped" | yq 'select(.kind == "Ingress") | .metadata.annotations."alb.ingress.kubernetes.io/scheme"')" = "internet-facing" ] || fail "grouped dashboard scheme changed"

plain="$(render)"
[ "$(printf '%s\n' "$plain" | yq 'select(.kind == "Ingress") | .metadata.annotations."alb.ingress.kubernetes.io/group.name"')" = "null" ] || fail "default dashboard ingress joined a group"
[ "$(printf '%s\n' "$plain" | yq 'select(.kind == "Ingress") | .spec.rules[0].host')" = "null" ] || fail "default dashboard ingress grew a host rule"

gcp_grouped="$(render --set gcp.enabled=true --set ui.alb.group_name=nuon-public --set-string 'ui.alb.group_tags=service=nuon-public\,service_type=shared')"
[ "$(printf '%s\n' "$gcp_grouped" | yq 'select(.kind == "Ingress") | .metadata.name' | grep -c . || true)" = "0" ] || fail "gcp dashboard render produced an AWS Ingress"

echo "dashboard-ui render tests passed"
