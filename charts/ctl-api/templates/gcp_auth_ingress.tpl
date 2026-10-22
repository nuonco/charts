{{- if and .Values.auth.enabled .Values.gcp.enabled }}
{{- $parents := include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "auth") | trim }}
{{- if $parents }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-auth
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-auth
spec:
  parentRefs:
    {{- $parents | nindent 4 }}
  hostnames:
    - {{ .Values.api.auth.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-auth
          port: 80
{{- end }}
{{- end }}
