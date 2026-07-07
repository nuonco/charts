{{- if and .Values.api.dashboard_admin.enabled .Values.gcp.enabled }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-dashboard-admin
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
spec:
  parentRefs:
    - kind: Gateway
      name: external-gateway
      sectionName: https
  hostnames:
    - {{ .Values.api.dashboard_admin.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-dashboard-admin
          port: 80
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-dashboard-admin-hc
  namespace: {{ .Release.Namespace }}
spec:
  default:
    checkIntervalSec: 5
    timeoutSec: 2
    healthyThreshold: 2
    unhealthyThreshold: 2
    config:
      type: HTTP
      httpHealthCheck:
        requestPath: {{ .Values.api.readiness_probe }}
        port: {{ .Values.api.dashboard_admin.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-dashboard-admin
{{- end }}
