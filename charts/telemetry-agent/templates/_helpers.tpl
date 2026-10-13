{{- define "telemetry-agent.fullname" -}}
{{- printf "%s-agent" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "telemetry-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}
