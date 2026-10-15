{{- define "common.homeEnv" -}}
{{- with .Values.home }}
- name: HOME
  value: {{ . | quote }}
{{- end }}
{{- end -}}
