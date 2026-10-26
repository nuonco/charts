{{- if and .Values.api.slack.enabled .Values.gcp.enabled }}
{{- $parents := include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "slack") | trim }}
{{- if $parents }}
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
    {{- $parents | nindent 4 }}
  hostnames:
    - {{ .Values.api.slack.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-slack
          port: 80
{{- end }}
{{- /*
Without this, the GKE Gateway health-checks the slack NEG with its default
(GET / on the serving port), which api-slack does not answer 200 on, so the
NEG never goes healthy and the ALB returns "no healthy upstream". Mirrors the
HealthCheckPolicies of the other gateway backends (ctl-api.gcpBackend).
*/}}
{{- include "ctl-api.gcpBackend" (dict "ctx" . "service" (printf "%s-slack" (include "common.fullname" .)) "port" .Values.api.slack.port "path" .Values.api.readiness_probe) }}
{{- end }}
