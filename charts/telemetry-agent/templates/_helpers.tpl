{{- define "telemetry-agent.fullname" -}}
{{- printf "%s-agent" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "telemetry-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/*
Exactly one credential source is allowed. Messages never include the token.
*/}}
{{- define "telemetry-agent.createBootstrapSecret" -}}
{{- $hasToken := ne (toString (default "" .Values.bootstrapToken)) "" -}}
{{- $hasExisting := ne (toString (default "" .Values.existingSecret.name)) "" -}}
{{- if and $hasToken $hasExisting -}}
{{- fail "set exactly one of bootstrapToken or existingSecret.name, not both" -}}
{{- else if not (or $hasToken $hasExisting) -}}
{{- fail "set exactly one of bootstrapToken or existingSecret.name" -}}
{{- end -}}
{{- if $hasToken -}}true{{- end -}}
{{- end -}}

{{- define "telemetry-agent.bootstrapSecretName" -}}
{{- if include "telemetry-agent.createBootstrapSecret" . -}}
{{- printf "%s-bootstrap" (include "telemetry-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Values.existingSecret.name -}}
{{- end -}}
{{- end -}}

{{- define "telemetry-agent.bootstrapSecretKey" -}}
{{- if include "telemetry-agent.createBootstrapSecret" . -}}
token
{{- else -}}
{{- required "existingSecret.key is required" .Values.existingSecret.key -}}
{{- end -}}
{{- end -}}

{{/*
Returns the state claim name, or empty for emptyDir.
*/}}
{{- define "telemetry-agent.stateClaimName" -}}
{{- if and .Values.persistence.enabled .Values.persistence.existingClaim -}}
{{- fail "set at most one of persistence.enabled or persistence.existingClaim" -}}
{{- else if .Values.persistence.enabled -}}
{{- printf "%s-state" (include "telemetry-agent.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Values.persistence.existingClaim -}}
{{- end -}}
{{- end -}}
