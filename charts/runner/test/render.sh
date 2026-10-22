#!/usr/bin/env bash
set -euo pipefail

chart_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
values="${chart_dir}/values.example.yaml"
rendered=$(mktemp)
trap 'rm -f "${rendered}"' EXIT

helm lint "${chart_dir}" --values "${values}"
helm template runner "${chart_dir}" \
  --namespace nuon-runner \
  --values "${values}" >"${rendered}"

grep -q 'image: "public.ecr.aws/p7e3r5y0/runner@sha256:' "${rendered}"
grep -q 'serviceAccountName: "runner"' "${rendered}"
if grep -Eq 'kind: (Role|RoleBinding|HorizontalPodAutoscaler|NodePool)' "${rendered}"; then
  echo "default render includes an optional or privileged resource" >&2
  exit 1
fi

if helm template runner "${chart_dir}" --namespace nuon-runner >/dev/null 2>&1; then
  echo "chart rendered without required values" >&2
  exit 1
fi

tag_rendered=$(helm template runner "${chart_dir}" \
  --namespace nuon-runner \
  --values "${values}" \
  --set image.digest= \
  --set image.tag=0.1.0)
grep -q 'image: "public.ecr.aws/p7e3r5y0/runner:0.1.0"' <<<"${tag_rendered}"

if helm template runner "${chart_dir}" --namespace nuon-runner \
  --values "${values}" --set image.tag=0.1.0 >/dev/null 2>&1; then
  echo "chart rendered with both image.digest and image.tag" >&2
  exit 1
fi

if helm template runner "${chart_dir}" --namespace nuon-runner \
  --values "${values}" --set image.digest= >/dev/null 2>&1; then
  echo "chart rendered without image.digest or image.tag" >&2
  exit 1
fi

extra_rendered=$(helm template runner "${chart_dir}" \
  --namespace nuon-runner \
  --values "${values}" \
  --set extraEnv.EXTRA_SETTING=enabled)
grep -q 'EXTRA_SETTING: enabled' <<<"${extra_rendered}"

for name in GITHUB_TOKEN HOST_IP RUNNER_ID; do
  for schema_flag in "" --skip-schema-validation; do
    if helm template runner "${chart_dir}" --namespace nuon-runner \
      --values "${values}" ${schema_flag} --set "extraEnv.${name}=x" >/dev/null 2>&1; then
      echo "chart rendered with forbidden extraEnv.${name} ${schema_flag}" >&2
      exit 1
    fi
  done
done

for url in http://runner.example.com "not a url" "https://runner.example.com/ x"; do
  for schema_flag in "" --skip-schema-validation; do
    if helm template runner "${chart_dir}" --namespace nuon-runner \
      --values "${values}" ${schema_flag} --set "config.apiUrl=${url}" >/dev/null 2>&1; then
      echo "chart rendered with non-https config.apiUrl=${url} ${schema_flag}" >&2
      exit 1
    fi
  done
done

# Values containing quotes/newlines must never add fields to the rendered
# manifests. Validated fields fail the render; the rest must stay quoted.
injection=$'x"\n      hostPID: true\n      injected: "x'
for key in podIdentity.existingServiceAccount image.repository; do
  for schema_flag in "" --skip-schema-validation; do
    if helm template runner "${chart_dir}" --namespace nuon-runner \
      --values "${values}" ${schema_flag} --set-string "${key}=${injection}" >/dev/null 2>&1; then
      echo "chart rendered with injected ${key} ${schema_flag}" >&2
      exit 1
    fi
  done
done
if helm template runner "${chart_dir}" --namespace nuon-runner \
  --values "${values}" --skip-schema-validation \
  --set image.digest= --set-string "image.tag=${injection}" >/dev/null 2>&1; then
  echo "chart rendered with injected image.tag" >&2
  exit 1
fi
for key in nameOverride node_pool.node_class_ref.name node_pool.instance_type.name; do
  if helm template runner "${chart_dir}" --namespace nuon-runner \
    --values "${values}" --set node_pool.enabled=true \
    --set-string "${key}=${injection}" >/dev/null 2>&1; then
    echo "chart rendered with schema-invalid ${key}" >&2
    exit 1
  fi
  injected_rendered=$(helm template runner "${chart_dir}" --namespace nuon-runner \
    --values "${values}" --skip-schema-validation --set node_pool.enabled=true \
    --set-string "${key}=${injection}" 2>/dev/null || true)
  if grep -Eq '^\s*(hostPID|injected):' <<<"${injected_rendered}"; then
    echo "${key} injected fields into the rendered manifests" >&2
    exit 1
  fi
done

first=$(shasum -a 256 "${rendered}" | awk '{print $1}')
helm template runner "${chart_dir}" \
  --namespace nuon-runner \
  --values "${values}" >"${rendered}"
second=$(shasum -a 256 "${rendered}" | awk '{print $1}')
test "${first}" = "${second}"
