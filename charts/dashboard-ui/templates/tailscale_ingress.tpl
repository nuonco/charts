{{- if ne (.Values.ui.exposure | default "internet") "internet" }}
{{- $tailscale := .Values.ui.tailscale | default dict }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}-tailscale
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{ with get $tailscale "proxyGroup" }}
  annotations:
    tailscale.com/proxy-group: {{ . }}
  {{ end }}
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - {{ get $tailscale "host" | default "dashboard" }}
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}
                port:
                  name: http
{{- end }}
