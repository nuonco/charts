{{- /*
One Job per hooks.commands entry. Helm runs the hooks of a phase sorted by hook-weight and
waits for each Job to finish before creating the next, so using the list index as the weight
gives serial, in-order execution within a phase. Env is inlined rather than envFrom because
pre hooks run before the release ConfigMap exists on first install.
*/ -}}
{{- if .Values.hooks.enabled }}
{{- $hooks := .Values.hooks }}
{{- if not (and (kindIs "slice" $hooks.command) $hooks.command) }}
{{- fail "hooks.command must be a non-empty list, e.g. [/bin/service]" }}
{{- end }}
{{- $version := include "ctl-api.hookVersion" . }}
{{- $changed := eq (include "ctl-api.hookVersionChanged" .) "true" }}
{{- /* Same keys as the release ConfigMap, minus the ones common.otelEnv and the fixed env below set themselves. */}}
{{- $env := omit (merge .Values.env (fromYaml (include "common.config-map" .))) "OTEL_RESOURCE_ATTRIBUTES" "DD_SERVICE" }}
{{- if .Values.otel.enabled }}
{{- $env = omit $env "OTEL_EXPORTER_OTLP_ENDPOINT" "OTEL_EXPORTER_OTLP_PROTOCOL" }}
{{- end }}
{{- $seenPost := false }}
{{- range $i, $cmd := $hooks.commands }}
{{- if not (kindIs "map" $cmd) }}
{{- fail (printf "hooks.commands[%d] must be an object with an args list" $i) }}
{{- end }}
{{- if not (and (kindIs "slice" $cmd.args) $cmd.args) }}
{{- fail (printf "hooks.commands[%d].args must be a non-empty list" $i) }}
{{- end }}
{{- $phase := $cmd.phase | default "post" }}
{{- if not (has $phase (list "pre" "post")) }}
{{- fail (printf "hooks.commands[%d].phase must be \"pre\" or \"post\" (got %v)" $i $phase) }}
{{- end }}
{{- if eq $phase "post" }}
{{- $seenPost = true }}
{{- else if $seenPost }}
{{- fail (printf "hooks.commands[%d] is phase \"pre\" but follows a \"post\" entry; pre hooks always run before post hooks, so list them first" $i) }}
{{- end }}
{{- if and $cmd.onVersionChange (not $version) }}
{{- fail (printf "hooks.commands[%d] sets onVersionChange but neither image.tag nor env.VERSION is set" $i) }}
{{- end }}
{{- if or (not $cmd.onVersionChange) $changed }}
{{- $slug := include "ctl-api.hookSlug" $cmd.args }}
{{- $name := include "ctl-api.hookJobName" (dict "ctx" $ "index" $i "args" $cmd.args) }}
{{- $backoffLimit := $hooks.backoffLimit }}
{{- if hasKey $cmd "backoffLimit" }}{{ $backoffLimit = $cmd.backoffLimit }}{{ end }}
{{- $deadline := $hooks.activeDeadlineSeconds }}
{{- if hasKey $cmd "activeDeadlineSeconds" }}{{ $deadline = $cmd.activeDeadlineSeconds }}{{ end }}
{{- $resources := merge (deepCopy (default (dict) $cmd.resources)) (default (dict) $hooks.resources) }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $name }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.apiLabels" $ | nindent 4 }}
    app.nuon.co/name: {{ $name }}
  annotations:
    # These make the Job a hook; without them it would be a regular release resource.
    "helm.sh/hook": {{ ternary "pre-install,pre-upgrade" "post-install,post-upgrade" (eq $phase "pre") }}
    "helm.sh/hook-weight": {{ $i | quote }}
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  backoffLimit: {{ $backoffLimit }}
  {{- with $deadline }}
  activeDeadlineSeconds: {{ . }}
  {{- end }}
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" $ | nindent 8 }}
        app.nuon.co/name: {{ $name }}
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: {{ dict "service_type" "hook" "service_deployment" $slug | toJson | quote }}
    spec:
      restartPolicy: Never
      serviceAccountName: {{ $.Values.serviceAccount.name }}
      automountServiceAccountToken: true
      {{- with $.Values.api.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      tolerations:
        - key: node.kubernetes.io/not-ready
          operator: Exists
          effect: NoExecute
          tolerationSeconds: 60
        - key: node.kubernetes.io/unreachable
          operator: Exists
          effect: NoExecute
          tolerationSeconds: 60
        {{- with $.Values.api.tolerations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      containers:
        - name: hook
          image: "{{ $.Values.image.repository }}:{{ $.Values.image.tag }}"
          command:
          {{- range $hooks.command }}
            - {{ toString . | quote }}
          {{- end }}
          args:
          {{- range $cmd.args }}
            - {{ toString . | quote }}
          {{- end }}
          {{- include "common.apiResources" (dict "service" (dict "resources" $resources) "fallback" $.Values.api.resources) | nindent 10 }}
          env:
            {{- include "common.otelEnv" $ | nindent 12 }}
          {{- range $key, $value := $env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
          {{- end }}
          {{- range $envSecret := $.Values.envSecrets }}
            - name: {{ $envSecret.name }}
              valueFrom:
                secretKeyRef:
                  name: {{ $envSecret.valueFrom.name }}
                  key: {{ $envSecret.valueFrom.key }}
                  optional: {{ $envSecret.optional | default false }}
          {{- end }}
            - name: HOST_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            - name: HOST_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: DD_SERVICE
              value: ctl-api
            - name: SERVICE_TYPE
              value: hook
            - name: SERVICE_DEPLOYMENT
              value: {{ $slug | quote }}
          {{- with $cmd.env }}
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end }}
{{- end }}
{{- end }}
