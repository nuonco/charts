{{- if .Values.startupHook.enabled }}
{{- $name := printf "%s-migrate" (include "common.serviceAccountName" . | trunc 55 | trimSuffix "-") }}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    {{- with .Values.serviceAccount.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-20"
    helm.sh/hook-delete-policy: before-hook-creation
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-20"
    helm.sh/hook-delete-policy: before-hook-creation
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-10"
    helm.sh/hook-delete-policy: before-hook-creation
roleRef:
  kind: Role
  name: {{ $name }}
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: {{ $name }}
    namespace: {{ .Release.Namespace }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "0"
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  backoffLimit: 0
  activeDeadlineSeconds: {{ .Values.startupHook.activeDeadlineSeconds }}
  template:
    metadata:
      labels:
        app.nuon.co/name: {{ $name }}
      annotations:
        karpenter.sh/do-not-disrupt: "true"
    spec:
      serviceAccountName: {{ $name }}
      automountServiceAccountToken: true
      restartPolicy: Never
      {{- with .Values.api.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.api.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: startup
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command: ["/bin/service", "startup"]
          {{- include "common.apiResources" (dict "service" (dict) "fallback" .Values.api.resources) | nindent 10 }}
          env:
            {{- range $key, $value := merge (deepCopy .Values.env) (fromYaml (include "common.config-map" .)) }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- include "common.otelEnv" . | nindent 12 }}
            {{- range .Values.envSecrets }}
            - name: {{ .name }}
              valueFrom:
                secretKeyRef:
                  name: {{ .valueFrom.name }}
                  key: {{ .valueFrom.key }}
                  optional: {{ .optional | default false }}
            {{- end }}
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
