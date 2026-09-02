---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}-mcp
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-mcp
spec:
  selector:
    {{- include "common.apiSelectorLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-mcp
  ports:
    - name: http
      port: 80
      targetPort: http-internal
