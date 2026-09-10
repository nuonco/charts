{{- define "common.otelEnv" -}}
{{- $attributes := get (default (dict) .Values.env) "OTEL_RESOURCE_ATTRIBUTES" | default "" -}}
{{- if not (kindIs "bool" .Values.otel.enabled) -}}
{{- fail "otel.enabled must be a boolean" -}}
{{- end -}}
{{- $overrides := .Values.envSecrets | default (list) -}}
{{- range $workload := concat (values .Values.api) (.Values.worker.instances | default (list)) -}}
{{- if kindIs "map" $workload -}}
{{- $overrides = concat $overrides (get $workload "extraEnv" | default (list)) -}}
{{- end -}}
{{- end -}}
{{- range $override := $overrides -}}
{{- if has $override.name (list "OTEL_EXPORTER_OTLP_ENDPOINT" "OTEL_EXPORTER_OTLP_PROTOCOL") -}}
{{- fail "OTLP endpoint and protocol are managed by otel values; do not set them in envSecrets or extraEnv" -}}
{{- end -}}
{{- end -}}
{{- $endpoint := "" -}}
{{- if .Values.otel.enabled -}}
{{- $endpoint = required "otel.endpoint is required when otel.enabled is true" .Values.otel.endpoint -}}
{{- if not (regexMatch "^https?://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$" $endpoint) -}}
{{- fail "otel.endpoint must be an HTTP(S) OTLP base URL without credentials, query parameters, or a fragment" -}}
{{- end -}}
{{- end -}}
- name: POD_UID
  valueFrom:
    fieldRef:
      fieldPath: metadata.uid
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.instance.id=$(POD_UID)%s" (ternary (printf ",%s" $attributes) "" (ne $attributes "")) | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $endpoint | quote }}
{{- if .Values.otel.enabled }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "http/protobuf"
{{- end }}
{{- end }}
