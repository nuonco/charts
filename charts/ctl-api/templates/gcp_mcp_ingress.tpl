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
{{- /*
Without this, the GKE Gateway health-checks the mcp NEG with its default
(GET / on the serving port), which api-mcp does not answer 200 on, so the
NEG never goes healthy and the ALB returns "no healthy upstream". Mirrors the
HealthCheckPolicies of the other gateway backends (ctl-api.gcpBackend).
*/}}
{{- include "ctl-api.gcpBackend" (dict "ctx" . "service" (printf "%s-mcp" (include "common.fullname" .)) "port" .Values.api.mcp.port "path" .Values.api.readiness_probe) }}
{{- end }}
