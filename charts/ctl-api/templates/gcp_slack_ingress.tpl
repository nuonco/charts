{{- if and .Values.api.slack.enabled .Values.gcp.enabled }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-slack
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-slack
spec:
  parentRefs:
    - kind: Gateway
      name: external-gateway
      sectionName: https
  hostnames:
    - {{ .Values.api.slack.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-slack
          port: 80
---
# Without this, the GKE Gateway health-checks the slack NEG with its default
# (GET / on the serving port), which api-slack does not answer 200 on, so the
# NEG never goes healthy and the ALB returns "no healthy upstream". Mirrors the
# per-service HealthCheckPolicies in gcp_gateway.tpl.
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-slack-hc
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
        port: {{ .Values.api.slack.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-slack
{{- end }}
