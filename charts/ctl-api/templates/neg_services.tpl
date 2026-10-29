{{- if .Values.api.public.neg.enabled }}
{{- include "ctl-api.negService" (dict "ctx" . "svc" "public" "port" .Values.api.public.port "targetPort" "http" "neg" .Values.api.public.neg) }}
{{- end }}
{{- if .Values.api.runner.neg.enabled }}
{{- include "ctl-api.negService" (dict "ctx" . "svc" "runner" "port" .Values.api.runner.port "targetPort" "http-runner" "neg" .Values.api.runner.neg) }}
{{- end }}
{{- if and .Values.auth.enabled .Values.api.auth.neg.enabled }}
{{- include "ctl-api.negService" (dict "ctx" . "svc" "auth" "port" 80 "targetPort" "http-internal" "neg" .Values.api.auth.neg) }}
{{- end }}
{{- if and .Values.api.mcp.enabled .Values.api.mcp.neg.enabled }}
{{- include "ctl-api.negService" (dict "ctx" . "svc" "mcp" "port" 80 "targetPort" "http-internal" "neg" .Values.api.mcp.neg) }}
{{- end }}
{{- if and .Values.api.slack.enabled .Values.api.slack.neg.enabled }}
{{- include "ctl-api.negService" (dict "ctx" . "svc" "slack" "port" 80 "targetPort" "http-internal" "neg" .Values.api.slack.neg) }}
{{- end }}
