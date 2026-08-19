{{- define "common.consumerLabels" -}}
app: {{ .Release.Name }}-consumer
helm.sh/chart: {{ include "common.chart" . }}
{{ include "common.consumerSelectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "common.consumerSelectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}-consumer
app.kubernetes.io/instance: {{ .Release.Name }}-consumer
{{- end }}
