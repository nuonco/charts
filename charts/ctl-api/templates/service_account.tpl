{{- /* Release-owned ServiceAccount, Role and RoleBinding. Defined once in lib/_rbac.tpl. */ -}}
{{- include "ctl-api.rbac" (dict "ctx" . "hook" false) }}
