{{- define "common.config-map" -}}
CONTAINER_PLATFORM: "EKS"
SERVICE_NAME: {{ .Chart.Name | quote }}
SERVICE_VERSION: {{ .Chart.Version | quote }}
RUNNER_ID: {{ required "config.runnerId is required" .Values.config.runnerId | quote }}
{{- $apiUrl := required "config.apiUrl is required" .Values.config.apiUrl }}
{{- if not (regexMatch "^https://[^\\s\"]+$" $apiUrl) }}
{{- fail "config.apiUrl must be an https:// URL; the runner token is sent to it" }}
{{- end }}
API_URL: {{ $apiUrl | quote }}
NUON_DEBUG: {{ .Values.config.debug | default false | toString | quote }}
{{- end -}}

{{/*
Env var names the chart sets itself, either in the ConfigMap or directly on
the container. extraEnv may not override them.
*/}}
{{- define "common.reserved-env" -}}
- CONTAINER_PLATFORM
- SERVICE_NAME
- SERVICE_VERSION
- RUNNER_ID
- API_URL
- NUON_DEBUG
- HOST_IP
- HOST_NAME
- POD_NAME
- POD_NAMESPACE
- DEPLOYMENT_NAME
- DELETE_POD_ON_SHUTDOWN
- RUNNER_API_TOKEN
{{- end -}}

{{/*
Secrets must come from existingSecret, never from extraEnv, which is rendered
into a plaintext ConfigMap. Keep in sync with values.schema.json.
*/}}
{{- define "common.secret-env-pattern" -}}
(?i)(^|_)(TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIALS?|API_KEY|ACCESS_KEY|PRIVATE_KEY)(_|$)
{{- end -}}

{{- define "common.extra-env" -}}
{{- $reserved := fromYamlArray (include "common.reserved-env" .) -}}
{{- $secretPattern := include "common.secret-env-pattern" . -}}
{{- $out := dict -}}
{{- range $name, $value := .Values.extraEnv -}}
{{- if has $name $reserved -}}
{{- fail (printf "extraEnv.%s is managed by the chart and cannot be overridden" $name) -}}
{{- end -}}
{{- if regexMatch $secretPattern $name -}}
{{- fail (printf "extraEnv.%s looks like a secret; extraEnv is rendered into a ConfigMap, provide secrets via existingSecret" $name) -}}
{{- end -}}
{{- $_ := set $out $name (toString $value) -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
