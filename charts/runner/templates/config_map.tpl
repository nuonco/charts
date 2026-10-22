---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" . | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
data:
{{- $env := merge (fromYaml (include "common.config-map" .)) (fromYaml (include "common.extra-env" .)) }}
{{- $env | toYaml | nindent 2 }}
