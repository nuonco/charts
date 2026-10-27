{{- if and .Values.auth.enabled .Values.gcp.enabled }}
{{- include "ctl-api.gcpHTTPRoutes" (dict "ctx" . "route" "auth" "name" (printf "%s-auth" (include "common.fullname" .)) "hostname" .Values.api.auth.domain "port" 80) }}
{{- end }}
