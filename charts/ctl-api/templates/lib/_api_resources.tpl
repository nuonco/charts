{{/*
Renders the resources block for an api deployment.

Deep-merges the service-specific resources (e.g. .Values.api.public.resources)
with the api.resources fallback. Both `requests` and `limits` are optional —
only the sub-blocks that are set are rendered, so limits can be omitted
globally or on a per-service basis.

Usage:
  {{- include "common.apiResources" (dict "service" .Values.api.public "fallback" .Values.api.resources) | nindent 10 }}
*/}}
{{- define "common.apiResources" -}}
{{- $resources := merge (default (dict) .service.resources) (default (dict) .fallback) -}}
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
