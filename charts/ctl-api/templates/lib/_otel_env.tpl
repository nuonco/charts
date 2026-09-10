{{- define "common.otelEnv" -}}
{{- $attributes := list "service.instance.id=$(POD_UID)" -}}
{{- with .Values.environment -}}
{{- $attributes = append $attributes (printf "deployment.environment.name=%s" .) -}}
{{- end -}}
{{- range $key, $value := .Values.otel.additional_resource_attributes -}}
{{- $attributes = append $attributes (printf "%s=%v" $key $value) -}}
{{- end -}}
- name: POD_UID
  valueFrom:
    fieldRef:
      fieldPath: metadata.uid
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ join "," $attributes | quote }}
{{- if .Values.otel.enabled }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ required "otel.endpoint is required when otel.enabled is true" .Values.otel.endpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "http/protobuf"
{{- end }}
{{- end }}
