{{/*
HealthCheckPolicy and GCPBackendPolicy for the dashboard-ui Service behind the GKE Gateway. Mirrors
ctl-api.gcpBackend in the ctl-api chart:

  {{- include "dashboard-ui.gcpBackend" (dict "ctx" . "service" (include "common.fullname" .) "port" .Values.ui.port "path" (.Values.ui.readiness_probe | default "/")) }}

The GCPBackendPolicy is always rendered: it sets access logging from gcp.logging and attaches
gcp.securityPolicy when it is set. Resource names
("<service>-hc", "<service>") must not change: Helm would delete and recreate them, leaving the backend
without its Cloud Armor policy in between.
*/}}
{{- define "dashboard-ui.gcpBackend" -}}
{{- $ctx := .ctx }}
{{- $logging := $ctx.Values.gcp.logging | default dict }}
{{- if and $logging.enabled (or (lt ($logging.sampleRate | int) 0) (gt ($logging.sampleRate | int) 1000000)) }}
{{- fail (printf "gcp.logging.sampleRate must be between 0 and 1000000 (got %v)" $logging.sampleRate) }}
{{- end }}
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ .service }}-hc
  namespace: {{ $ctx.Release.Namespace }}
spec:
  default:
    checkIntervalSec: 5
    timeoutSec: 2
    healthyThreshold: 2
    unhealthyThreshold: 2
    config:
      type: HTTP
      httpHealthCheck:
        requestPath: {{ .path }}
        port: {{ .port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ .service }}
---
apiVersion: networking.gke.io/v1
kind: GCPBackendPolicy
metadata:
  name: {{ .service }}
  namespace: {{ $ctx.Release.Namespace }}
spec:
  default:
    {{- with $ctx.Values.gcp.securityPolicy }}
    securityPolicy: {{ . | quote }}
    {{- end }}
    logging:
      {{- if $logging.enabled }}
      enabled: true
      sampleRate: {{ $logging.sampleRate | int }}
      {{- else }}
      enabled: false
      {{- end }}
  targetRef:
    group: ""
    kind: Service
    name: {{ .service }}
{{- end }}
