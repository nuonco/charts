{{- /*
Deliberately pinned: minReplicas == maxReplicas == .replicas, so this autoscales
nothing today. It exists so the wiring is in place when we do want to scale, and
so replica counts live in one place per instance.

Two notes for whoever turns it on:

  - Do NOT add a memory metric, the way worker_hpas.tpl does. Go doesn't return
    memory to the OS eagerly, so a consumer's RSS sits near its high-water mark
    after any backlog drain. Memory utilization becomes a one-way ratchet that
    pins replicas at max and never scales back down.
  - Consumer lag is the metric that actually says whether these are keeping up,
    and Strimzi's kafkaExporter already publishes kafka_consumergroup_* to
    Datadog. Wiring that up as an external metric is the real fix; CPU below is a
    placeholder that stays inert while min == max.

Replicas above the topic partition count sit idle holding no partitions, so that
is the ceiling worth raising to.
*/ -}}
{{- range $.Values.consumer.instances }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.fullname" $ }}-consumer-{{ .name }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.consumerSelectorLabels" $ | nindent 4 }}
    app.nuon.co/consumer: {{ .name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common.fullname" $ }}-consumer-{{ .name }}
  minReplicas: {{ .replicas }}
  maxReplicas: {{ .replicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $.Values.consumer.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
