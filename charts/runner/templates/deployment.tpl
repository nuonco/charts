{{- $secret := required "existingSecret is required" .Values.existingSecret -}}
{{- $serviceAccount := required "podIdentity.existingServiceAccount is required" .Values.podIdentity.existingServiceAccount -}}
{{- $repository := required "image.repository is required" .Values.image.repository -}}
{{- $digest := .Values.image.digest | default "" -}}
{{- $tag := .Values.image.tag | default "" | toString -}}
{{- if not (regexMatch "^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)*$" $repository) -}}
{{- fail "image.repository must be a registry/repository reference without a tag or digest" -}}
{{- end -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$" $serviceAccount) -}}
{{- fail "podIdentity.existingServiceAccount must be a valid Kubernetes object name" -}}
{{- end -}}
{{- if and $digest $tag -}}
{{- fail "image.digest and image.tag are mutually exclusive; set only one" -}}
{{- end -}}
{{- $image := "" -}}
{{- if $digest -}}
{{- if not (regexMatch "^sha256:[0-9a-f]{64}$" $digest) -}}
{{- fail "image.digest must be sha256 followed by 64 lowercase hexadecimal characters" -}}
{{- end -}}
{{- $image = printf "%s@%s" $repository $digest -}}
{{- else if $tag -}}
{{- if not (regexMatch "^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$" $tag) -}}
{{- fail "image.tag must be a valid OCI tag" -}}
{{- end -}}
{{- $image = printf "%s:%s" $repository $tag -}}
{{- else -}}
{{- fail "one of image.digest or image.tag is required" -}}
{{- end -}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . | quote }}
  namespace: {{ .Release.Namespace | quote }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.node_pool.runner_count | default 1 | int }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.selectorLabels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
        checksum/config: {{ include (print $.Template.BasePath "/config_map.tpl") $ | sha256sum }}
        checksum/secret-reference: {{ printf "%s:%s" $.Values.existingSecret $.Values.existingSecretKey | sha256sum }}
      {{- else }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/config_map.tpl") $ | sha256sum }}
        checksum/secret-reference: {{ printf "%s:%s" $.Values.existingSecret $.Values.existingSecretKey | sha256sum }}
      {{- end }}
    spec:
      automountServiceAccountToken: false
      serviceAccountName: {{ $serviceAccount | quote }}
      securityContext:
        # TODO: the published image still starts as root.
        runAsNonRoot: false
        seccompProfile:
          type: RuntimeDefault
      {{- if .Values.node_pool.enabled }}
      nodeSelector:
        {{ include "common.fullname" . | quote }}: "true"
      tolerations:
        - key: "deployment"
          operator: "Equal"
          value: {{ include "common.fullname" . | quote }}
          effect: "NoSchedule"
      {{- else }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ include "common.fullname" . | quote }}
          image: {{ $image | quote }}
          imagePullPolicy: {{ .Values.image.pullPolicy | quote }}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
          command:
            - /bin/runner
            - {{ .Values.command | default "install" | quote }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" . | quote }}
          env:
            - name: HOST_IP
              valueFrom:
                  fieldRef:
                      fieldPath: status.hostIP
            - name: HOST_NAME
              valueFrom:
                  fieldRef:
                      fieldPath: spec.nodeName
            - name: POD_NAME
              valueFrom:
                  fieldRef:
                      fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                  fieldRef:
                      fieldPath: metadata.namespace
            - name: DEPLOYMENT_NAME
              value: {{ include "common.fullname" . | quote }}
            - name: DELETE_POD_ON_SHUTDOWN
              value: "false"
            - name: RUNNER_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ $secret | quote }}
                  key: {{ .Values.existingSecretKey | default "RUNNER_API_TOKEN" | quote }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
