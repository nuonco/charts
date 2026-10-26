{{- if (.Values.gcp | default dict).enabled }}
{{- $gateways := list (dict "name" "external-gateway" "namespace" "ctl-api" "sectionName" "https") }}
{{- if hasKey .Values.gcp "gateways" }}
{{- $gateways = .Values.gcp.gateways | default list }}
{{- end }}
{{- include "dashboard-ui.gcpBackend" (dict "ctx" . "service" (include "common.fullname" .) "port" .Values.ui.port "path" (.Values.ui.readiness_probe | default "/")) }}
{{- if $gateways }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  parentRefs:
    {{- range $gateways }}
    - kind: Gateway
      name: {{ .name }}
      namespace: {{ .namespace | default "ctl-api" }}
      sectionName: {{ .sectionName | default "https" }}
    {{- end }}
  hostnames:
    - {{ .Values.ui.alb.public_domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}
          port: 4000
{{- end }}
{{- end }}
