---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}-runner
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-runner
spec:
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-runner
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" . | nindent 8 }}
        app.nuon.co/name: {{ include "common.fullname" . }}-runner
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"api","service_deployment":"runner"}'
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
              (dict "app.nuon.co/name" (printf "%s-runner" (include "common.fullname" $))))
        ) | nindent 8 }}
      {{- end }}
      volumes:
        - name: iid-certs
          configMap:
            name: {{ include "common.fullname" . }}-iid-certs
        {{- include "common.kafkaCertVolumes" . | nindent 8 }}
      containers:
        - name: {{ include "common.fullname" . }}-runner
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - /bin/service
            - api-runner
          ports:
            - name: http-runner
              containerPort: {{ .Values.api.runner.port }}
              protocol: TCP
            - name: pprof
              containerPort: 6060
              protocol: TCP
          readinessProbe:
            httpGet:
              path: {{ .Values.api.readiness_probe}}
              port: http-runner
          livenessProbe:
            httpGet:
              path: {{ .Values.api.liveness_probe}}
              port: http-runner
          {{- include "common.apiResources" (dict "service" .Values.api.runner "fallback" .Values.api.resources) | nindent 10 }}
          volumeMounts:
            - name: iid-certs
              mountPath: /etc/nuon/iid-certs
              readOnly: true
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
            - name: AWS_IID_CERTS_DIR
              value: "/etc/nuon/iid-certs"
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
              value: runner
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
  name: {{ include "common.fullname" . }}-runner
  namespace: {{ .Release.Namespace }}
spec:
  minAvailable: 50%
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-runner
