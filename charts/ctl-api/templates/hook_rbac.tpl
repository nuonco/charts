{{- /*
Pre-hook copies of the ServiceAccount, Role and RoleBinding, so that pre Jobs can run on a first
install before the release manifests exist. See lib/_rbac.tpl for the full rationale. Only
rendered when a pre command is configured and the chart manages a ServiceAccount; with no
serviceAccount.name the Jobs fall back to the namespace default account.
*/ -}}
{{- if and .Values.hooks.enabled .Values.serviceAccount.name (include "ctl-api.hasPreHook" .) }}
{{- include "ctl-api.rbac" (dict "ctx" . "hook" true) }}
{{- end }}
