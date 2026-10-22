{{- if .Values.gcp }}
{{- $gateways := list (dict "name" "external-gateway" "namespace" "ctl-api" "sectionName" "https") }}
{{- if hasKey .Values.gcp "gateways" }}
{{- $gateways = .Values.gcp.gateways | default list }}
{{- end }}
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-hc
  namespace: {{ .Release.Namespace }}
spec:
  default:
    checkIntervalSec: 5
    timeoutSec: 2
    healthyThreshold: 2
    unhealthyThreshold: 2
    config:
      type: HTTP
      httpHealthCheck:
        requestPath: {{ .Values.ui.readiness_probe | default "/" }}
        port: {{ .Values.ui.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}
{{- if .Values.gcp.securityPolicy }}
---
apiVersion: networking.gke.io/v1
kind: GCPBackendPolicy
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  default:
    securityPolicy: {{ .Values.gcp.securityPolicy | quote }}
    logging:
      enabled: true
      sampleRate: 1000000
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}
{{- end }}
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
