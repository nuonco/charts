{{- if .Values.api.dashboard_admin.enabled }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}-dashboard-admin
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
spec:
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" . | nindent 8 }}
        app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
        tags.datadoghq.com/service: ctl-api
      annotations:
        rollme: {{ randAlphaNum 5 | quote }}
        ad.datadoghq.com/tags: '{"service_type":"api","service_deployment":"dashboard-admin"}'
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

      # start: Topology Spread Constraints
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: "topology.kubernetes.io/zone"
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              {{- /* plucked from common.apiSelectorLabels */}}
              app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
        - maxSkew: 2
          minDomains: {{ .Values.api.minDomains }}
          topologyKey: "kubernetes.io/hostname"
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              {{- /* plucked from common.apiSelectorLabels */}}
              app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
      # end: Topology Spread Constraints
      containers:
        - name: {{ include "common.fullname" . }}-dashboard-admin
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - /bin/service
            - api-admin
          ports:
            - name: http-internal
              containerPort: {{ .Values.api.dashboard_admin.port }}
              protocol: TCP
            - name: pprof
              containerPort: 6060
              protocol: TCP
          readinessProbe:
            httpGet:
              path: {{ .Values.api.readiness_probe }}
              port: http-internal
          livenessProbe:
            httpGet:
              path: {{ .Values.api.liveness_probe }}
              port: http-internal
          {{- include "common.apiResources" (dict "service" .Values.api.dashboard_admin "fallback" .Values.api.resources) | nindent 10 }}
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
              value: dashboard-admin
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
  name: {{ include "common.fullname" . }}-dashboard-admin
  namespace: {{ .Release.Namespace }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-dashboard-admin
{{- end }}
