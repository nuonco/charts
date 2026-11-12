{{- if .Values.hooks.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "ctl-api.hookVersionConfigMapName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  annotations:
    # The version `lookup` saw when this release was rendered; a debugging aid only.
    app.nuon.co/hook-previous-version: {{ include "ctl-api.hookPreviousVersion" . | quote }}
data:
  # Read back with `lookup` on the next upgrade to decide whether onVersionChange hooks run.
  version: {{ include "ctl-api.hookVersion" . | quote }}
{{- end }}
