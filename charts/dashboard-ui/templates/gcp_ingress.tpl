{{- if and .Values.ingress.enabled (.Values.gcp | default dict).enabled }}
{{- $gateways := list (dict "name" "external-gateway" "namespace" "ctl-api" "sectionName" "https") }}
{{- if hasKey .Values.gcp "gateways" }}
{{- $gateways = .Values.gcp.gateways | default list }}
{{- end }}
{{- include "dashboard-ui.gcpBackend" (dict "ctx" . "service" (include "common.fullname" .) "port" .Values.ui.port "path" (.Values.ui.readiness_probe | default "/")) }}
{{- /*
One HTTPRoute per gateway: external-dns publishes the address of every parent gateway, so a route
shared with psc-gateway would put its internal VIP in public DNS. Only the external-gateway route keeps
the plain name and is left to external-dns; every other route opts out.
*/}}
{{- range $gateways }}
{{- $public := eq .name "external-gateway" }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ include "common.fullname" $ }}{{ if not $public }}-{{ .name }}{{ end }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include "common.labels" $ | nindent 4 }}
  {{- if not $public }}
  annotations:
    external-dns.alpha.kubernetes.io/controller: none
  {{- end }}
spec:
  parentRefs:
    - kind: Gateway
      name: {{ .name }}
      namespace: {{ .namespace | default "ctl-api" }}
      sectionName: {{ .sectionName | default "https" }}
  hostnames:
    - {{ $.Values.ui.alb.public_domain | trimSuffix "." }}
  rules:
    - backendRefs:
        - name: {{ include "common.fullname" $ }}
          port: 4000
{{- end }}
{{- end }}
