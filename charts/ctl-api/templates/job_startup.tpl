{{- if .Values.startup.enabled }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "common.fullname" . }}-startup-hook
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
  annotations:
    # This is what defines this resource as a hook. Without this line, the
    # job is considered part of the release.
    # pre-rollback gates `helm rollback` too: rollback replays the target
    # revision's stored hooks, so a revision whose migrations cannot complete
    # will fail the hook and abort before any manifests are applied.
    "helm.sh/hook": pre-install,pre-upgrade,pre-rollback
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" . | nindent 8 }}
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"startup"}'
    spec:
      restartPolicy: Never
      serviceAccountName: {{ .Values.serviceAccount.name }}
      automountServiceAccountToken: true

      # start: NodePool Selection
      {{- with .Values.api.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.api.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      # end: NodePool Selection

      containers:
        - name: {{ include "common.fullname" . }}-startup-hook
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - /bin/service
            - startup
          {{- include "common.apiResources" (dict "service" .Values.startup "fallback" .Values.api.resources) | nindent 10 }}
          env:
          # Hook pods run before the release manifests are applied, so the
          # ConfigMap may not exist yet. Inline the same values instead of
          # using envFrom.
          {{- range $key, $value := merge .Values.env (fromYaml (include "common.config-map" .)) }}
            - name: {{ $key }}
              value: {{ $value | quote }}
          {{- end }}
          {{- range $envSecret := .Values.envSecrets }}
            - name: {{ $envSecret.name }}
              valueFrom:
                secretKeyRef:
                  name: {{ $envSecret.valueFrom.name }}
                  key: {{ $envSecret.valueFrom.key }}
                  optional: {{ $envSecret.optional | default false }}
          {{- end}}
            - name: HOST_IP
              valueFrom:
                  fieldRef:
                      fieldPath: status.hostIP
            - name: HOST_NAME
              valueFrom:
                  fieldRef:
                      fieldPath: spec.nodeName
            - name: SERVICE_TYPE
              value: startup
{{- end }}
