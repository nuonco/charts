{{- /*
ServiceAccount, Role and RoleBinding for the workloads. One definition, rendered twice:

  include "ctl-api.rbac" (dict "ctx" . "hook" false)   templates/service_account.tpl, the release-owned objects
  include "ctl-api.rbac" (dict "ctx" . "hook" true)    templates/hook_rbac.tpl, pre-hook copies for first installs

A pre Job runs before any release manifest is applied, and the kubelet refuses a pod whose
ServiceAccount does not exist, so on a first install the Job would hang until Helm timed out.
In hook mode each object is emitted only when `lookup` cannot find it, as a pre-install,pre-upgrade
hook at weight -10 (below every command). The copies are deleted with hook-succeeded, which Helm
applies after every hook of the phase has completed, so they outlive the pre Jobs; the release
manifests then create the objects the workloads own.

Not before-hook-creation: that would delete and recreate the ServiceAccount on every upgrade,
changing its UID (invalidating the bound tokens running pods hold) and briefly dropping
serviceAccount.annotations such as the IRSA role ARN. The lookup guard means a healthy upgrade
emits no copy at all.

The copies carry Helm's ownership annotations. If a pre Job fails on a first install the
hook-succeeded cleanup never runs and the copy is left behind untracked; on the next install
`lookup` finds it, no copy is emitted, and without the annotations the release manifest would
fail Helm's "exists and cannot be imported into the current release" check. With them Helm adopts it.
*/ -}}
{{- define "ctl-api.rbac" -}}
{{- $ctx := .ctx }}
{{- $hook := .hook }}
{{- $name := $ctx.Values.serviceAccount.name }}
{{- $ns := $ctx.Release.Namespace }}
{{- $hookAnnotations := dict }}
{{- if $hook }}
{{- $hookAnnotations = dict
      "helm.sh/hook" "pre-install,pre-upgrade"
      "helm.sh/hook-weight" "-10"
      "helm.sh/hook-delete-policy" "hook-succeeded"
      "meta.helm.sh/release-name" $ctx.Release.Name
      "meta.helm.sh/release-namespace" $ns }}
{{- end }}
{{- $render := true }}
{{- if $hook }}{{ $render = not (lookup "v1" "ServiceAccount" $ns $name) }}{{ end }}
{{- if $render }}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $name }}
  namespace: {{ $ns }}
  labels:
    {{- include "common.labels" $ctx | nindent 4 }}
  annotations:
    {{- if $hook }}
    {{- toYaml (merge (deepCopy $hookAnnotations) (default (dict) $ctx.Values.serviceAccount.annotations)) | nindent 4 }}
    {{- else }}
    {{- toYaml $ctx.Values.serviceAccount.annotations | nindent 4 }}
    {{- end }}
{{- end }}
{{- $render = true }}
{{- if $hook }}{{ $render = not (lookup "rbac.authorization.k8s.io/v1" "Role" $ns $name) }}{{ end }}
{{- if $render }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $name }}
  namespace: {{ $ns }}
  labels:
    {{- include "common.labels" $ctx | nindent 4 }}
  {{- if $hook }}
  annotations:
    {{- toYaml $hookAnnotations | nindent 4 }}
  {{- end }}
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
{{- end }}
{{- $render = true }}
{{- if $hook }}{{ $render = not (lookup "rbac.authorization.k8s.io/v1" "RoleBinding" $ns (printf "%s-rolebinding" $name)) }}{{ end }}
{{- if $render }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $name }}-rolebinding
  namespace: {{ $ns }}
  labels:
    {{- include "common.labels" $ctx | nindent 4 }}
  {{- if $hook }}
  annotations:
    {{- toYaml $hookAnnotations | nindent 4 }}
  {{- end }}
roleRef:
  kind: Role
  name: {{ $name }}
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: {{ $name }}
    namespace: {{ $ns }}
{{- end }}
{{- end -}}
