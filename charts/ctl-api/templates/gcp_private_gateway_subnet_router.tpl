{{- if and .Values.gcp.enabled .Values.gcp.privateGateway.enabled .Values.gcp.privateGateway.subnetRouter.enabled }}
{{- $router := .Values.gcp.privateGateway.subnetRouter }}
{{- if not $router.route }}
{{- fail "gcp.privateGateway.subnetRouter.route is required when gcp.privateGateway.subnetRouter.enabled is true" }}
{{- end }}
---
apiVersion: tailscale.com/v1alpha1
kind: Connector
metadata:
  name: private-gateway
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ $router.replicas }}
  hostnamePrefix: {{ $router.hostnamePrefix }}
  subnetRouter:
    advertiseRoutes:
      - {{ $router.route | quote }}
{{- end }}
