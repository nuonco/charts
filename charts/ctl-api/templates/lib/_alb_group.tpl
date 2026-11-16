{{- define "common.albGroup" -}}
{{- if .group }}
alb.ingress.kubernetes.io/group.name: {{ .group | quote }}
alb.ingress.kubernetes.io/tags: {{ .groupTags | quote }}
{{- else }}
alb.ingress.kubernetes.io/tags: {{ .tags | quote }}
{{- end }}
{{- end }}
