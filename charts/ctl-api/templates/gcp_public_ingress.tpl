{{- if .Values.gcp.enabled }}
{{- include "ctl-api.gcpHTTPRoutes" (dict "ctx" . "route" "public" "name" (printf "%s-public" (include "common.fullname" .)) "hostname" .Values.api.public.domain "port" .Values.api.public.port) }}
{{- end }}
