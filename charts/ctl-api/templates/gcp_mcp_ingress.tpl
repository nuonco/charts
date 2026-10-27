{{- if and .Values.api.mcp.enabled .Values.gcp.enabled }}
{{- include "ctl-api.gcpHTTPRoutes" (dict "ctx" . "route" "mcp" "name" (printf "%s-mcp" (include "common.fullname" .)) "hostname" .Values.api.mcp.domain "port" 80) }}
{{- /*
Without this, the GKE Gateway health-checks the mcp NEG with its default
(GET / on the serving port), which api-mcp does not answer 200 on, so the
NEG never goes healthy and the ALB returns "no healthy upstream". Mirrors the
HealthCheckPolicies of the other gateway backends (ctl-api.gcpBackend).
*/}}
{{- include "ctl-api.gcpBackend" (dict "ctx" . "service" (printf "%s-mcp" (include "common.fullname" .)) "port" .Values.api.mcp.port "path" .Values.api.readiness_probe) }}
{{- end }}
