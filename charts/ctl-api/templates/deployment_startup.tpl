---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}-startup
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-startup
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "common.apiSelectorLabels" . | nindent 6 }}
      app.nuon.co/name: {{ include "common.fullname" . }}-startup
  template:
    metadata:
      labels:
        {{- include "common.apiSelectorLabels" . | nindent 8 }}
        app.nuon.co/name: {{ include "common.fullname" . }}-startup
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"startup"}'
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
              (dict "app.nuon.co/name" (printf "%s-startup" (include "common.fullname" $))))
        ) | nindent 8 }}
      {{- end }}

      containers:
        - name: {{ include "common.fullname" . }}-startup
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command:
            - tail
            - -f
            - /dev/null
          resources:
            limits:
              cpu: {{ .Values.api.resources.limits.cpu }}
              memory: {{ .Values.api.resources.limits.memory }}
            requests:
              cpu: {{ .Values.api.resources.requests.cpu }}
              memory: {{ .Values.api.resources.requests.memory }}
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
              value: startup
