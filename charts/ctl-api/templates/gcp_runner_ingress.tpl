{{- if .Values.gcp.enabled }}
{{- include "ctl-api.gcpHTTPRoutes" (dict "ctx" . "route" "runner" "name" (printf "%s-runner" (include "common.fullname" .)) "hostname" .Values.api.runner.domain "port" .Values.api.runner.port) }}
{{- end }}
