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

echo "ctl-api render tests passed"
