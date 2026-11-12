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

# --- deploy hooks -------------------------------------------------------------
job() {
  printf '%s\n' "$out" | yq "select(.kind == \"Job\" and .metadata.name == \"$1\") | $2"
}
job_count() {
  printf '%s\n' "$1" | yq 'select(.kind == "Job") | .metadata.name' | grep -c -v -e '^---$' -e '^$' || true
}

[ "$(job_count "$default_out")" = "0" ] || fail "hook Jobs rendered with default values"
[ "$(printf '%s\n' "$default_out" | yq 'select(.kind == "ConfigMap" and .metadata.name == "ctl-api-hooks") | .metadata.name' | grep -c . || true)" = "0" ] || fail "hook version ConfigMap rendered with default values"

job_names="$(printf '%s\n' "$out" | yq 'select(.kind == "Job") | .metadata.name' | grep -v -e '^---$' -e '^$')"
[ "$(printf '%s\n' "$job_names" | grep -c .)" = "3" ] || fail "expected 3 hook Jobs"
[ "$(printf '%s\n' "$job_names" | sort -u | grep -c .)" = "3" ] || fail "hook Job names are not unique"
if printf '%s\n' "$job_names" | grep -Evq '^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$'; then fail "hook Job name is not a DNS label"; fi

[ "$(job ctl-api-hook-0-startup '.metadata.annotations."helm.sh/hook"')" = "pre-install,pre-upgrade" ] || fail "startup hook phase"
[ "$(job ctl-api-hook-1-admin-runners-update '.metadata.annotations."helm.sh/hook"')" = "post-install,post-upgrade" ] || fail "runners update hook phase"
[ "$(job ctl-api-hook-2-admin-post-promotion '.metadata.annotations."helm.sh/hook"')" = "post-install,post-upgrade" ] || fail "post-promotion hook phase"
for i in 0 1 2; do
  name="$(printf '%s\n' "$job_names" | sed -n "$((i + 1))p")"
  [ "$(job "$name" '.metadata.annotations."helm.sh/hook-weight"')" = "$i" ] || fail "$name hook-weight"
  [ "$(job "$name" '.metadata.annotations."helm.sh/hook-weight" | tag')" = "!!str" ] || fail "$name hook-weight must be a string"
  [ "$(job "$name" '.metadata.annotations."helm.sh/hook-delete-policy"')" = "before-hook-creation,hook-succeeded" ] || fail "$name delete policy"
  [ "$(job "$name" '.spec.template.spec.containers[0].command | join(" ")')" = "/bin/service" ] || fail "$name command"
  [ "$(job "$name" '.spec.template.spec.restartPolicy')" = "Never" ] || fail "$name restartPolicy"
  [ "$(job "$name" '.spec.template.spec.containers[0].envFrom')" = "null" ] || fail "$name must inline env, not envFrom"
  [ "$(job "$name" '.spec.template.spec.containers[0].env[] | select(.name == "SERVICE_NAME") | .value')" = "ctl-api" ] || fail "$name missing inlined config-map env"
  [ "$(job "$name" '.spec.template.spec.containers[0].env[] | select(.name == "VERSION") | .value')" = "from-env" ] || fail "$name missing inlined .Values.env"
  [ "$(job "$name" '.spec.template.spec.containers[0].env | length')" = "$(job "$name" '.spec.template.spec.containers[0].env | map(.name) | unique | length')" ] || fail "$name has duplicate env names"
done
[ "$(job ctl-api-hook-0-startup '.spec.template.spec.containers[0].args | join(" ")')" = "startup" ] || fail "startup args"
[ "$(job ctl-api-hook-1-admin-runners-update '.spec.template.spec.containers[0].args | join(" ")')" = "admin runners update" ] || fail "runners update args"
[ "$(job ctl-api-hook-2-admin-post-promotion '.spec.template.spec.containers[0].args | join(" ")')" = "admin post-promotion" ] || fail "post-promotion args"
[ "$(job ctl-api-hook-0-startup '.spec.activeDeadlineSeconds')" = "600" ] || fail "default activeDeadlineSeconds"
[ "$(job ctl-api-hook-0-startup '.spec.backoffLimit')" = "0" ] || fail "default backoffLimit"
[ "$(job ctl-api-hook-2-admin-post-promotion '.spec.activeDeadlineSeconds')" = "120" ] || fail "per-entry activeDeadlineSeconds"
[ "$(job ctl-api-hook-2-admin-post-promotion '.spec.backoffLimit')" = "2" ] || fail "per-entry backoffLimit"
[ "$(job ctl-api-hook-0-startup '.spec.template.spec.containers[0].resources.requests.cpu')" = "500m" ] || fail "default hook resources"

hook_cm='select(.kind == "ConfigMap" and .metadata.name == "ctl-api-hooks") | .data.version'
[ "$(printf '%s\n' "$out" | yq "$hook_cm")" = "v1.2.3" ] || fail "hook version ConfigMap should record image.tag"
[ "$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set image.tag= | yq "$hook_cm")" = "from-env" ] || fail "hook version should fall back to env.VERSION"

# helm template cannot exercise `lookup`, so gated Jobs always render here; force must not change the count.
[ "$(job_count "$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set hooks.force=true)")" = "3" ] || fail "hooks.force=true should still render 3 Jobs"

if helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set 'hooks.commands[0].phase=bogus' >/dev/null 2>&1; then fail "phase=bogus must fail rendering"; fi
if helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set 'hooks.commands[2].phase=pre' >/dev/null 2>&1; then fail "a pre entry after a post entry must fail rendering"; fi
if helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set image.tag= --set env.VERSION= >/dev/null 2>&1; then fail "onVersionChange without image.tag or env.VERSION must fail rendering"; fi
if helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set 'hooks.command=null' >/dev/null 2>&1; then fail "empty hooks.command must fail rendering"; fi

# --- first-install RBAC hook copies ---------------------------------------------
pre_hooks() {
  printf '%s\n' "$1" | yq 'select(.kind != "Job" and .metadata.annotations["helm.sh/hook"] == "pre-install,pre-upgrade") | .kind + " " + .metadata.name' | grep -v -e '^---$' -e '^$' || true
}
# ci values set no serviceAccount.name: pre Jobs use the namespace default account, no copies.
[ -z "$(pre_hooks "$out")" ] || fail "RBAC hook copies rendered without serviceAccount.name"
[ -z "$(pre_hooks "$default_out")" ] || fail "RBAC hook copies rendered with default values"

rbac_out="$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" \
  --set serviceAccount.name=ctl-api \
  --set 'serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::123:role/ctl')"
[ "$(pre_hooks "$rbac_out" | sort | tr '\n' ',')" = "Role ctl-api,RoleBinding ctl-api-rolebinding,ServiceAccount ctl-api," ] || fail "expected SA, Role and RoleBinding hook copies"
# helm template cannot lookup, so copies render beside the release objects; the release ones must not be hooks.
rbac() {
  printf '%s\n' "$rbac_out" | yq "select(.kind == \"$1\" and .metadata.name == \"$2\" and (.metadata.annotations[\"helm.sh/hook\"] $3)) | $4"
}
for kind_name in "ServiceAccount ctl-api" "Role ctl-api" "RoleBinding ctl-api-rolebinding"; do
  kind="${kind_name%% *}"; name="${kind_name#* }"
  [ "$(rbac "$kind" "$name" '== null' '.metadata.name')" = "$name" ] || fail "release $kind missing or rendered as a hook"
  [ "$(rbac "$kind" "$name" '!= null' '.metadata.annotations."helm.sh/hook-weight"')" = "-10" ] || fail "$kind copy hook-weight"
  [ "$(rbac "$kind" "$name" '!= null' '.metadata.annotations."helm.sh/hook-weight" | tag')" = "!!str" ] || fail "$kind copy hook-weight must be a string"
  [ "$(rbac "$kind" "$name" '!= null' '.metadata.annotations."helm.sh/hook-delete-policy"')" = "hook-succeeded" ] || fail "$kind copy must use hook-succeeded, never before-hook-creation"
  [ "$(rbac "$kind" "$name" '!= null' '.metadata.annotations."meta.helm.sh/release-name"')" = "ctl-api" ] || fail "$kind copy missing release-name ownership annotation"
  [ "$(rbac "$kind" "$name" '!= null' '.metadata.annotations."meta.helm.sh/release-namespace"')" = "default" ] || fail "$kind copy missing release-namespace ownership annotation"
  [ "$(rbac "$kind" "$name" '!= null' '.metadata.labels."app.kubernetes.io/managed-by"')" = "Helm" ] || fail "$kind copy missing managed-by label"
done
[ "$(rbac ServiceAccount ctl-api '!= null' '.metadata.annotations."eks.amazonaws.com/role-arn"')" = "arn:aws:iam::123:role/ctl" ] || fail "ServiceAccount copy missing serviceAccount.annotations"
[ "$(rbac ServiceAccount ctl-api '== null' '.metadata.annotations."eks.amazonaws.com/role-arn"')" = "arn:aws:iam::123:role/ctl" ] || fail "release ServiceAccount missing serviceAccount.annotations"
[ "$(rbac Role ctl-api '!= null' '.rules')" = "$(rbac Role ctl-api '== null' '.rules')" ] || fail "Role copy rules differ from the release Role"
[ "$(rbac RoleBinding ctl-api-rolebinding '!= null' '.subjects')" = "$(rbac RoleBinding ctl-api-rolebinding '== null' '.subjects')" ] || fail "RoleBinding copy subjects differ from the release RoleBinding"

post_only="$(helm template ctl-api "$chart" -f "$chart/ci/test-values.yaml" --set serviceAccount.name=ctl-api --set 'hooks.commands[0].phase=post')"
[ -z "$(pre_hooks "$post_only")" ] || fail "RBAC hook copies rendered with no pre commands"

echo "ctl-api render tests passed"
