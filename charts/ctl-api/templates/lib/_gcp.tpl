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
