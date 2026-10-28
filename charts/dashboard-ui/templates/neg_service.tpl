{{- if .Values.neg.enabled }}
{{- $name := include "common.fullname" . }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}-neg
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  annotations:
    cloud.google.com/neg: {{ dict "exposed_ports" (dict (toString .Values.ui.port) (dict "name" (.Values.neg.name | default $name))) | toJson | quote }}
spec:
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  type: ClusterIP
  ports:
    - name: http
      port: {{ .Values.ui.port }}
      targetPort: http
{{- end }}
