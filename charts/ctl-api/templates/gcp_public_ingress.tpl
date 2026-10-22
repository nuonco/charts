{{- $internet := ne (.Values.api.public.exposure | default "internet") "tailscale" }}
{{- if and .Values.gcp.enabled (or $internet .Values.gcp.privateGateway.enabled) }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" . }}-public
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-public
spec:
  parentRefs:
    {{- if $internet }}
    - kind: Gateway
      name: external-gateway
      sectionName: https
    {{- end }}
    {{- if .Values.gcp.privateGateway.enabled }}
    - kind: Gateway
      name: private-gateway
      sectionName: https
    {{- end }}
  hostnames:
    - {{ .Values.api.public.domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" . }}-public
          port: {{ .Values.api.public.port }}
{{- end }}
