{{- if .Values.api.dashboard_admin.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}-dashboard-admin
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
spec:
  selector:
    {{- include "common.apiSelectorLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
  ports:
    - name: http
      port: 80
      targetPort: http-internal
{{- end }}
