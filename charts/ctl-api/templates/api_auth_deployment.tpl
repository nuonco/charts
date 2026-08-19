{{- if .Values.auth.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}-auth
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-auth
spec:
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-auth
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" . | nindent 8 }}
        app.nuon.co/name: {{ include "common.fullname" . }}-auth
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"api","service_deployment":"auth"}'
    spec:
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

      {{- with .Values.api.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- include "common.topologySpreadConstraints" (dict
            "constraints" .
            "labelSelector" (dict "matchLabels"
              (dict "app.nuon.co/name" (printf "%s-auth" (include "common.fullname" $))))
        ) | nindent 8 }}
      {{- end }}
      volumes:
        {{- include "common.kafkaCertVolumes" . | nindent 8 }}
      containers:
        - name: {{ include "common.fullname" . }}-auth
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - /bin/service
            - api-auth
          ports:
            - name: http-internal
              containerPort: {{ .Values.api.auth.port }}
              protocol: TCP
          readinessProbe:
            httpGet:
              path: {{ .Values.api.readiness_probe }}
              port: http-internal
          livenessProbe:
            httpGet:
              path: {{ .Values.api.liveness_probe }}
              port: http-internal
          {{- include "common.apiResources" (dict "service" .Values.api.auth "fallback" .Values.api.resources) | nindent 10 }}
          volumeMounts:
            {{- include "common.kafkaCertVolumeMounts" . | nindent 12 }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" . }}
          env:
          {{- range $envSecret := .Values.envSecrets }}
            - name: {{ $envSecret.name }}
              valueFrom:
                secretKeyRef:
                  name: {{ $envSecret.valueFrom.name }}
                  key: {{ $envSecret.valueFrom.key }}
                  optional: {{ $envSecret.optional | default false }}
          {{- end}}
          {{/* additional secrets for the auth service */}}
          {{- range $envSecret := .Values.auth.envSecrets }}
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
            - name: DD_SERVICE
              value: ctl-api
            - name: SERVICE_TYPE
              value: api
            - name: SERVICE_DEPLOYMENT
              value: auth
          lifecycle:
            preStop:
              exec:
                # sleep: during this time, the api can finish processing requests.
                command: [
                  "/bin/sh", "-c", "sleep 20"
                ]
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}-auth
  namespace: {{ .Release.Namespace }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-auth
{{- end }}
