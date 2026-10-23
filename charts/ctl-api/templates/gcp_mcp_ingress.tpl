{{- if and .Values.api.mcp.enabled .Values.gcp.enabled }}
{{- $parents := include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "mcp") | trim }}
{{- if $parents }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-mcp
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-mcp
spec:
  parentRefs:
    {{- $parents | nindent 4 }}
  hostnames:
    - {{ .Values.api.mcp.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-mcp
          port: 80
{{- end }}
---
# Without this, the GKE Gateway health-checks the mcp NEG with its default
# (GET / on the serving port), which api-mcp does not answer 200 on, so the
# NEG never goes healthy and the ALB returns "no healthy upstream". Mirrors the
# per-service HealthCheckPolicies in gcp_gateway.tpl.
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-mcp-hc
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
        port: {{ .Values.api.mcp.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-mcp
{{- end }}
