{{- define "common.labels" -}}
app: {{ .Release.Name | quote }}
helm.sh/chart: {{ include "common.chart" . | quote }}
{{ include "common.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{- define "common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end }}
