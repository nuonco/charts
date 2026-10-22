{{- if .Values.node_pool.enabled }}

apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: {{ include "common.fullname" . | quote }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- /* https://karpenter.sh/docs/concepts/disruption/#consolidation */}}
  disruption:
    consolidateAfter: 120s
    consolidationPolicy: WhenEmpty
    budgets:
    - nodes: 50%
  limits:
    cpu: {{ mul .Values.node_pool.instance_type.cpu .Values.node_pool.runner_count | add .Values.node_pool.instance_type.cpu | int }}
    {{- with mul .Values.node_pool.instance_type.memory .Values.node_pool.runner_count | add .Values.node_pool.instance_type.memory }}
    memory: {{ printf "%dMi" (int .) | quote }}
    {{- end }}
  template:
    metadata:
      labels:
        {{ include "common.fullname" . | quote }}: "true"
    spec:
      expireAfter: {{ .Values.node_pool.expireAfter | quote }}
      taints:
        - key: deployment
          effect: NoSchedule
          value: {{ include "common.fullname" . | quote }}
      nodeClassRef:
        group: {{ .Values.node_pool.node_class_ref.group | quote }}
        kind: {{ .Values.node_pool.node_class_ref.kind | quote }}
        name: {{ .Values.node_pool.node_class_ref.name | quote }}
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: {{ .Values.node_pool.capacity_types | toYaml | nindent 8 }}
      - key: node.kubernetes.io/instance-type
        operator: In
        values:
          - {{ .Values.node_pool.instance_type.name | quote }}

{{- end }}
