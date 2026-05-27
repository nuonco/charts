{{- /*
common.topologySpreadConstraints renders a topologySpreadConstraints list,
merging a deployment-specific labelSelector into each user-supplied entry.

Expects a dict:
  constraints:   list of user-supplied constraints (from values)
  labelSelector: dict to inject as labelSelector on each constraint

If a user-supplied constraint already specifies labelSelector, the user's
value wins (helm `merge` is dest-precedence).
*/ -}}
{{- define "common.topologySpreadConstraints" -}}
{{- $injected := dict "labelSelector" .labelSelector -}}
{{- $items := list -}}
{{- range .constraints -}}
{{- $items = append $items (printf "- %s" (toYaml (merge (deepCopy .) $injected) | nindent 2 | trim)) -}}
{{- end -}}
{{ join "\n" $items }}
{{- end }}
