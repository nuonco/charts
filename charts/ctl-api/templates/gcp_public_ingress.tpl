{{- if .Values.gcp.enabled }}
{{- $parents := include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "public") | trim }}
{{- if $parents }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-public
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-public
spec:
  parentRefs:
    {{- $parents | nindent 4 }}
  hostnames:
    - {{ .Values.api.public.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-public
          port: {{ .Values.api.public.port }}
{{- end }}
{{- end }}
