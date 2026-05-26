{{- range $.Values.worker.instances }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" $ }}-worker-{{ .namespace }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.workerLabels" $ | nindent 4 }}
    app.nuon.co/worker-namespace: {{ .namespace }}
spec:
  selector:
    matchLabels:
      {{- include "common.workerSelectorLabels" $ | nindent 6 }}
      app.nuon.co/worker-namespace: {{ .namespace }}
  template:
    metadata:
      labels:
        {{- include "common.workerSelectorLabels" $ | nindent 8 }}
        app.nuon.co/worker-namespace: {{ .namespace }}
        tags.datadoghq.com/service:  ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"worker","service_deployment":"{{ .namespace }}","temporal_namespace":"{{ .namespace }}"}'
    spec:
      serviceAccountName: {{ $.Values.serviceAccount.name }}
      automountServiceAccountToken: true
      {{- with $.Values.worker.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $.Values.worker.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- $ns := .namespace }}
      {{- with $.Values.worker.topologySpreadConstraints }}
      topologySpreadConstraints:
        {{- include "common.topologySpreadConstraints" (dict
            "constraints" .
            "labelSelector" (dict "matchLabels" (dict
              "app.kubernetes.io/name" (printf "%s-worker" (include "common.name" $))
              "app.nuon.co/worker-namespace" $ns))
        ) | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ include "common.fullname" $ }}-worker-{{ .namespace }}
          ports:
          - containerPort: 6060
            name: pprof
            protocol: TCP
          image: "{{ $.Values.image.repository }}:{{ $.Values.image.tag }}"
          command: {{- .command  | toYaml | nindent 14}}
          resources: {{ merge (default (dict) .resources) $.Values.worker.resources | toYaml | nindent 14 }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" $ }}
          env:
          {{- range $envSecret := $.Values.envSecrets }}
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
              value: worker
            - name: SERVICE_DEPLOYMENT
              value: {{ .namespace }}
            - name: TEMPORAL_NAMESPACE
              value: {{ .namespace }}
          {{- if . | dig "extraEnv" (list) }}
            {{- .extraEnv | toYaml | nindent 12 }}
          {{- end }}

{{- end }}
