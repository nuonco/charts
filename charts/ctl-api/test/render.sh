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

# ALB grouping. Members of one group must agree on every load-balancer annotation,
# and each needs its own host, or the controller rejects the group.
group_file="$(mktemp)"
ui_file="$(mktemp)"
trap 'rm -f "$group_file" "$ui_file" "$rendered"' EXIT
cat >"$group_file" <<'EOF'
env:
  ENV: prod
  ROOT_DOMAIN: example.com
auth:
  enabled: false
api:
  admin:
    enabled: true
    domain: admin.internal.example.com
  public:
    domain: api.example.com
    domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
  runner:
    domain: runner.example.com
    domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
  auth:
    domain: auth.example.com
    domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
  slack:
    enabled: false
    domain: slack.example.com
    domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
  mcp:
    enabled: true
    domain: mcp.example.com
    domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
  dashboard_admin:
    enabled: false
    alb:
      enabled: false
      domain: admin.example.com
      domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
ingressGroups:
  public:
    name: nuon-public
    tags: service=nuon-public,service_type=shared
EOF
cat >"$ui_file" <<'EOF'
env:
  ENV: prod
ui:
  alb:
    public_domain: app.example.com
    public_domain_certificate: arn:aws:acm:us-east-1:000000000000:certificate/wild
    group_name: nuon-public
    group_tags: service=nuon-public,service_type=shared
EOF

ui_chart="$(cd "$chart/../dashboard-ui" && pwd)"
rendered="$(mktemp)"

ann() {
  yq "select(.kind == \"Ingress\" and .metadata.annotations.\"alb.ingress.kubernetes.io/group.name\" == \"nuon-public\") | .metadata.annotations.\"alb.ingress.kubernetes.io/$1\"" "$rendered" | grep -v -e '^---$' -e '^$' || true
}

assert_group() {
  local want="$1" n schemes tags policies ports types certs hosts admin_scheme admin_group
  n="$(ann scheme | grep -c . || true)"
  [ "$n" = "$want" ] || fail "public group has $n members, want $want"
  schemes="$(ann scheme | sort -u)"
  tags="$(ann tags | sort -u)"
  policies="$(ann ssl-policy | sort -u)"
  ports="$(ann listen-ports | sort -u)"
  types="$(ann target-type | sort -u)"
  certs="$(ann certificate-arn | sort -u)"
  hosts="$(yq 'select(.kind == "Ingress" and .metadata.annotations."alb.ingress.kubernetes.io/group.name" == "nuon-public") | .spec.rules[0].host' "$rendered" | grep -v -e '^---$' -e '^$' || true)"
  [ "$schemes" = "internet-facing" ] || fail "public group scheme is [$schemes]"
  [ "$tags" = "service=nuon-public,service_type=shared" ] || fail "public group tags are [$tags]"
  [ "$policies" = "ELBSecurityPolicy-TLS13-1-2-FIPS-2023-04" ] || fail "public group ssl-policy is [$policies]"
  [ "$ports" = '[{"HTTPS":443}]' ] || fail "public group listen-ports are [$ports]"
  [ "$types" = "ip" ] || fail "public group target-type is [$types]"
  [ "$certs" = "arn:aws:acm:us-east-1:000000000000:certificate/wild" ] || fail "public group certificate-arn is [$certs]"
  [ "$(printf '%s\n' "$hosts" | grep -c -v '^null$' || true)" = "$want" ] || fail "a grouped ingress has no host"
  [ "$(printf '%s\n' "$hosts" | sort -u | grep -c . || true)" = "$want" ] || fail "grouped hosts are not unique: $hosts"
  admin_scheme="$(yq 'select(.kind == "Ingress" and .metadata.name == "ctl-api-admin") | .metadata.annotations."alb.ingress.kubernetes.io/scheme"' "$rendered")"
  admin_group="$(yq 'select(.kind == "Ingress" and .metadata.name == "ctl-api-admin") | .metadata.annotations."alb.ingress.kubernetes.io/group.name"' "$rendered")"
  [ "$admin_scheme" = "internal" ] || fail "admin scheme is [$admin_scheme]"
  [ "$admin_group" = "null" ] || fail "admin joined a group [$admin_group]"
}

render_both() {
  helm template ctl-api "$chart" -f "$group_file" "$@" >"$rendered"
  helm template dashboard-ui "$ui_chart" -f "$ui_file" >>"$rendered"
}

# mcp on, nothing else optional: the common install
render_both
assert_group 4

# every optional public ingress on
render_both \
  --set auth.enabled=true \
  --set api.slack.enabled=true \
  --set api.dashboard_admin.enabled=true \
  --set api.dashboard_admin.alb.enabled=true
assert_group 7
auth_host="$(yq 'select(.kind == "Ingress" and .metadata.name == "ctl-api-auth") | .spec.rules[0].host' "$rendered")"
[ "$auth_host" = "auth.example.com" ] || fail "grouped auth host is [$auth_host]"

# slack and the public admin ingress on, mcp off
render_both \
  --set api.slack.enabled=true \
  --set api.mcp.enabled=false \
  --set api.dashboard_admin.enabled=true \
  --set api.dashboard_admin.alb.enabled=true
assert_group 5

# empty group keeps today's dedicated ALBs: no group, no host rule
ungrouped="$(helm template ctl-api "$chart" -f "$group_file" --set ingressGroups.public.name= --set ingressGroups.public.tags= --set auth.enabled=true --set api.slack.enabled=true --set api.dashboard_admin.enabled=true --set api.dashboard_admin.alb.enabled=true)"
ungrouped_groups="$(printf '%s\n' "$ungrouped" | yq 'select(.kind == "Ingress") | .metadata.annotations."alb.ingress.kubernetes.io/group.name"' | grep -v -e '^---$' -e '^$' | sort -u || true)"
ungrouped_hosts="$(printf '%s\n' "$ungrouped" | yq 'select(.kind == "Ingress") | .spec.rules[0].host' | grep -v -e '^---$' -e '^$' | sort -u || true)"
[ "$ungrouped_groups" = "null" ] || fail "ungrouped ingresses set group.name [$ungrouped_groups]"
[ "$ungrouped_hosts" = "null" ] || fail "ungrouped ingresses set a host [$ungrouped_hosts]"

# gcp app configs turn ingress off and front the NEGs with a load balancer outside the chart.
# Group values must not bring the AWS ALBs back.
gcp_off="$(helm template ctl-api "$chart" -f "$group_file" --set ingress.enabled=false --set gcp.enabled=true --set gcp.certMap=test --set auth.enabled=true --set api.slack.enabled=true)"
gcp_off_ui="$(helm template dashboard-ui "$ui_chart" -f "$ui_file" --set ingress.enabled=false --set gcp.enabled=true)"
[ "$(printf '%s\n%s\n' "$gcp_off" "$gcp_off_ui" | yq 'select(.kind == "Ingress" or .kind == "Gateway" or .kind == "HTTPRoute") | .kind' | grep -c -v -e '^---$' -e '^$' || true)" = "0" ] || fail "ingress.enabled=false still rendered a load balancer"

# chart gcp mode (ingress left on) renders gateways and no AWS ALB
gcp="$(helm template ctl-api "$chart" -f "$group_file" --set gcp.enabled=true --set gcp.certMap=test --set auth.enabled=true --set api.slack.enabled=true)"
gcp_ui="$(helm template dashboard-ui "$ui_chart" -f "$ui_file" --set gcp.enabled=true)"
[ "$(printf '%s\n%s\n' "$gcp" "$gcp_ui" | yq 'select(.kind == "Ingress") | .metadata.name' | grep -c -v -e '^---$' -e '^$' || true)" = "0" ] || fail "gcp render produced an AWS Ingress"
[ "$(printf '%s\n' "$gcp" | yq 'select(.kind == "Gateway") | .metadata.name' | grep -c -v -e '^---$' -e '^$' || true)" != "0" ] || fail "gcp render produced no Gateway"

echo "ctl-api render tests passed"
