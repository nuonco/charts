{{- if and .Values.api.dashboard_admin.enabled .Values.api.dashboard_admin.alb.enabled .Values.gcp.enabled }}
{{- $parents := include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "dashboard_admin") | trim }}
{{- if $parents }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-dashboard-admin
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
spec:
  parentRefs:
    {{- $parents | nindent 4 }}
  hostnames:
    - {{ .Values.api.dashboard_admin.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-dashboard-admin
          port: 80
{{- end }}
{{- include "ctl-api.gcpBackend" (dict "ctx" . "service" (printf "%s-dashboard-admin" (include "common.fullname" .)) "port" .Values.api.dashboard_admin.port "path" .Values.api.readiness_probe) }}
{{- end }}
