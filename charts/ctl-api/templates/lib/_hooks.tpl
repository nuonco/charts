{{/*
Name of the chart-managed ConfigMap recording the version the hooks last ran for.
A normal release resource (not a hook) so `lookup` can read it on the next upgrade.
*/}}
{{- define "ctl-api.hookVersionConfigMapName" -}}
{{- printf "%s-hooks" (include "common.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Version the hooks run for: image.tag, falling back to env.VERSION. Empty when neither is set.
*/}}
{{- define "ctl-api.hookVersion" -}}
{{- $version := .Values.image.tag | default (dig "VERSION" "" (default (dict) .Values.env)) -}}
{{- if $version }}{{ toString $version }}{{ end -}}
{{- end -}}

{{/*
Version recorded by the previous release, read from the cluster. Empty under `helm template`,
client-side dry runs, Argo CD-style rendering, and before the ConfigMap first exists.
*/}}
{{- define "ctl-api.hookPreviousVersion" -}}
{{- $cm := lookup "v1" "ConfigMap" .Release.Namespace (include "ctl-api.hookVersionConfigMapName" .) -}}
{{- if $cm }}{{ dig "data" "version" "" $cm }}{{ end -}}
{{- end -}}

{{/*
"true" when onVersionChange commands should run: first install, hooks.force, no recorded
version, or a version different from the recorded one. Use as:
  eq (include "ctl-api.hookVersionChanged" .) "true"
*/}}
{{- define "ctl-api.hookVersionChanged" -}}
{{- $current := include "ctl-api.hookVersion" . -}}
{{- $previous := include "ctl-api.hookPreviousVersion" . -}}
{{- if or .Release.IsInstall .Values.hooks.force (not $previous) (ne $current $previous) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
DNS-safe slug for a command's args (takes the list): lowercased, runs of anything but
[a-z0-9] collapsed to "-". (list "admin" "post-promotion" "--force") -> admin-post-promotion-force
*/}}
{{- define "ctl-api.hookSlug" -}}
{{- regexReplaceAll "[^a-z0-9]+" (join "-" . | lower) "-" | trimAll "-" -}}
{{- end -}}

{{/*
Job name for a hook: <fullname>-hook-<index>-<slug>, truncated to 63 chars. The index sits
before the slug so names stay unique even when the slug is truncated or repeated.
Takes a dict: ctx (root context), index (int), args (list).
*/}}
{{- define "ctl-api.hookJobName" -}}
{{- printf "%s-hook-%d-%s" (include "common.fullname" .ctx) (int .index) (include "ctl-api.hookSlug" .args) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
"true" when at least one hooks.commands entry runs in the pre phase. Pre Jobs start before the
release ServiceAccount exists on a first install, so they need the hook copies in hook_rbac.tpl.
*/}}
{{- define "ctl-api.hasPreHook" -}}
{{- $has := false -}}
{{- range .Values.hooks.commands -}}
{{- if and (kindIs "map" .) (eq (.phase | default "post") "pre") -}}
{{- $has = true -}}
{{- end -}}
{{- end -}}
{{- if $has }}true{{ end -}}
{{- end -}}
