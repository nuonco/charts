{{- if and .Values.ingress.enabled .Values.api.dashboard_admin.enabled .Values.api.dashboard_admin.alb.enabled .Values.gcp.enabled }}
{{- include "ctl-api.gcpHTTPRoutes" (dict "ctx" . "route" "dashboard_admin" "name" (printf "%s-dashboard-admin" (include "common.fullname" .)) "hostname" .Values.api.dashboard_admin.domain "port" 80) }}
{{- include "ctl-api.gcpBackend" (dict "ctx" . "service" (printf "%s-dashboard-admin" (include "common.fullname" .)) "port" .Values.api.dashboard_admin.port "path" .Values.api.readiness_probe) }}
{{- end }}
