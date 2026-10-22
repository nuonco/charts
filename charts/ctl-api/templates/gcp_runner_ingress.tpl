{{- if .Values.gcp.enabled }}
{{- $parents := include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "runner") | trim }}
{{- if $parents }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-runner
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-runner
spec:
  parentRefs:
    {{- $parents | nindent 4 }}
  hostnames:
    - {{ .Values.api.runner.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-runner
          port: {{ .Values.api.runner.port }}
{{- end }}
{{- end }}
