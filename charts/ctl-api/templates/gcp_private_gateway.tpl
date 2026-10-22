{{- if and .Values.gcp.enabled .Values.gcp.privateGateway.enabled }}
{{- if not .Values.gcp.privateGateway.certificate }}
{{- fail "gcp.privateGateway.certificate is required when gcp.privateGateway.enabled is true" }}
{{- end }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: private-gateway
  namespace: {{ .Release.Namespace }}
spec:
  gatewayClassName: gke-l7-rilb
  {{- with .Values.gcp.privateGateway.address }}
  addresses:
    - type: NamedAddress
      value: {{ . }}
  {{- end }}
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        options:
          networking.gke.io/cert-manager-certs: {{ .Values.gcp.privateGateway.certificate }}
      allowedRoutes:
        namespaces:
          from: All
{{- end }}
