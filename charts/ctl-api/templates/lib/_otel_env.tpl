{{- define "common.otelEnv" -}}
{{- $attributes := get (default (dict) .Values.env) "OTEL_RESOURCE_ATTRIBUTES" | default "" -}}
- name: POD_UID
  valueFrom:
    fieldRef:
      fieldPath: metadata.uid
- name: OTEL_RESOURCE_ATTRIBUTES
  value: {{ printf "service.instance.id=$(POD_UID)%s" (ternary (printf ",%s" $attributes) "" (ne $attributes "")) | quote }}
{{- end }}
