{{- /*
Kafka consumer deployments, named for what they consume rather than where they
write. `consumer --name` selects which run, the same way `worker --namespace`
does, and each consumer gets its own consumer group so a restart of one doesn't
rebalance the others.

A deployment is not necessarily one consumer: `--name` takes a list, so consumers
that should scale and fail together can share a pod. Co-tenants share more than a
pod, though — a single liveness probe, so a wedged handler restarts its
neighbours; one Kafka client id, so a client quota throttles them together; and
the process-wide KAFKA_CONSUMER_FETCH_* caps, which cannot be set per consumer.

Renders nothing when `consumer.instances` is empty, which is the chart default.
*/ -}}
{{- range $.Values.consumer.instances }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" $ }}-consumer-{{ .name }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.consumerLabels" $ | nindent 4 }}
    app.nuon.co/consumer: {{ .name }}
    app.nuon.co/name: {{ include "common.fullname" $ }}-consumer-{{ .name }}
spec:
  # Matches the HPA's minReplicas so a helm upgrade and the HPA never disagree.
  replicas: {{ .replicas }}
  # Selector is immutable once applied and must match the pod labels below. The
  # app.kubernetes.io labels name the consumer tier, so app.nuon.co/consumer is
  # what keeps one consumer deployment from selecting another's pods — the same
  # role app.nuon.co/worker-namespace plays for the workers.
  selector:
    matchLabels:
      {{- include "common.consumerSelectorLabels" $ | nindent 6 }}
      app.nuon.co/consumer: {{ .name }}
  template:
    metadata:
      labels:
        {{- include "common.consumerSelectorLabels" $ | nindent 8 }}
        app.nuon.co/consumer: {{ .name }}
        tags.datadoghq.com/service: ctl-api
      annotations:
        ad.datadoghq.com/tags: '{"service_type":"consumer","service_deployment":"{{ .name }}"}'
    spec:
      serviceAccountName: {{ $.Values.serviceAccount.name }}
      automountServiceAccountToken: true
      {{- with (default $.Values.consumer.nodeSelector .nodeSelector) }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (default $.Values.consumer.tolerations .tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- $name := .name }}
      {{- with $.Values.consumer.topologySpreadConstraints }}
      # Scoped per consumer, not across the whole consumer tier — otherwise one
      # instance's placement constrains another's for no reason.
      topologySpreadConstraints:
        {{- include "common.topologySpreadConstraints" (dict
            "constraints" .
            "labelSelector" (dict "matchLabels" (dict
              "app.kubernetes.io/name" (printf "%s-consumer" (include "common.name" $))
              "app.nuon.co/consumer" $name))
        ) | nindent 8 }}
      {{- end }}
      volumes:
        {{- include "common.kafkaCertVolumes" $ | nindent 8 }}
      containers:
        - name: {{ include "common.fullname" $ }}-consumer-{{ .name }}
          ports:
            - containerPort: 6060
              name: pprof
              protocol: TCP
            - containerPort: 8090
              name: health
              protocol: TCP
          image: "{{ $.Values.image.repository }}:{{ $.Values.image.tag }}"
          command: {{- .command | toYaml | nindent 14 }}
          resources: {{ merge (default (dict) .resources) $.Values.consumer.resources | toYaml | nindent 14 }}
          # Checks only whether this pod's handler is stuck — never ClickHouse or
          # Kafka reachability directly, so a degraded dependency can't trigger a
          # synchronized restart across every consumer replica.
          livenessProbe:
            httpGet:
              path: /livez
              port: health
            timeoutSeconds: 5
            periodSeconds: 15
            failureThreshold: 3
          volumeMounts:
            {{- include "common.kafkaCertVolumeMounts" $ | nindent 12 }}
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
              value: consumer
            # Names this consumer, matching --name, the ctl-api-consumer-<name>
            # group, and the derived Kafka client id. Kafka applies client quotas
            # per client id, so this is what lets one consumer be throttled
            # without throttling the others.
            - name: SERVICE_DEPLOYMENT
              value: {{ .name }}
          {{- if . | dig "extraEnv" (list) }}
            {{- .extraEnv | toYaml | nindent 12 }}
          {{- end }}
{{- end }}
