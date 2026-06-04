{{/*
Renders the resources block for the ui deployment.

Both `requests` and `limits` are optional — only the sub-blocks that are set
are rendered, so either can be omitted entirely.

Usage:
  {{- include "common.uiResources" .Values.ui.resources | nindent 10 }}
*/}}
{{- define "common.uiResources" -}}
{{- $resources := default (dict) . -}}
resources:
{{- with $resources.requests }}
  requests:
    {{- toYaml . | nindent 4 }}
{{- end }}
{{- with $resources.limits }}
  limits:
    {{- toYaml . | nindent 4 }}
{{- end }}
{{- end -}}
