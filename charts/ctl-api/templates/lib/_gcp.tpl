{{/*
Route keys that may attach to the external and/or PSC gateway.
*/}}
{{- define "ctl-api.gcpRouteKeys" -}}
public runner auth mcp slack dashboard_admin
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
{{- $external := $gcp.externalRoutes | default list }}
{{- $psc := list }}
{{- if $gcp.psc.enabled }}
{{- $psc = $gcp.psc.routes | default list }}
{{- end }}
{{- range (concat $external $psc) }}
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
