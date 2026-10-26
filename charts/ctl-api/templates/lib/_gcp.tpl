{{/*
Route keys that may attach to the external and/or PSC gateway.
*/}}
{{- define "ctl-api.gcpRouteKeys" -}}
public runner auth mcp slack dashboard_admin
{{- end }}

{{/*
Route keys that must never attach to external-gateway or psc-gateway. The admin API (ctl-api-admin) is
unauthenticated and only ever routes through internal-gateway. Hardcoded so values can't override it.
*/}}
{{- define "ctl-api.gcpDeniedRouteKeys" -}}
admin api_admin api-admin ctl-api-admin ctl_api_admin
{{- end }}

{{/*
parentRefs for a GCP HTTPRoute. Pass a dict with the root context and the route key:

  {{ include "ctl-api.gcpParentRefs" (dict "ctx" . "route" "public") }}

The route attaches to external-gateway when its key is in gcp.externalRoutes, and to psc-gateway when
gcp.psc.enabled and its key is in gcp.psc.routes. Renders nothing if it attaches to neither, so callers
can skip the HTTPRoute.
*/}}
{{- define "ctl-api.gcpParentRefs" -}}
{{- $gcp := .ctx.Values.gcp }}
{{- $keys := splitList " " (include "ctl-api.gcpRouteKeys" .) }}
{{- $denied := splitList " " (include "ctl-api.gcpDeniedRouteKeys" .) }}
{{- $external := $gcp.externalRoutes | default list }}
{{- $psc := list }}
{{- if $gcp.psc.enabled }}
{{- $psc = $gcp.psc.routes | default list }}
{{- end }}
{{- /* Validate psc.routes even when psc is disabled, so a denied key can't lie dormant until it's enabled. */}}
{{- range (concat $external ($gcp.psc.routes | default list)) }}
{{- if has . $denied }}
{{- fail (printf "GCP route %q is the admin API and must never be listed in gcp.externalRoutes or gcp.psc.routes; it is only served on internal-gateway" .) }}
{{- end }}
{{- if not (has . $keys) }}
{{- fail (printf "unknown GCP route %q in gcp.externalRoutes / gcp.psc.routes (valid: %s)" . (join ", " $keys)) }}
{{- end }}
{{- end }}
{{- if has .route $external }}
- kind: Gateway
  name: external-gateway
  sectionName: https
{{- end }}
{{- if has .route $psc }}
- kind: Gateway
  name: psc-gateway
  sectionName: https
{{- end }}
{{- end }}

{{/*
HealthCheckPolicy and GCPBackendPolicy for a Service behind external-gateway or psc-gateway. Every such
backend renders through this, so none can exist without a GCPBackendPolicy. Pass the root context, the
Service name, its port and the health check path:

  {{- include "ctl-api.gcpBackend" (dict "ctx" . "service" (printf "%s-public" (include "common.fullname" .)) "port" .Values.api.public.port "path" .Values.api.readiness_probe) }}

The GCPBackendPolicy is always rendered: it sets access logging from gcp.logging and attaches
gcp.securityPolicy when it is set. Resource names
("<service>-hc", "<service>") must not change: Helm would delete and recreate them, leaving the backend
without its Cloud Armor policy in between.
*/}}
{{- define "ctl-api.gcpBackend" -}}
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
