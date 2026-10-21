{{- if ne (.Values.api.public.exposure | default "internet") "internet" }}
{{- $tailscale := .Values.api.public.tailscale | default dict }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}-public-tailscale
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-public
  {{ with get $tailscale "proxyGroup" }}
  annotations:
    tailscale.com/proxy-group: {{ . }}
  {{ end }}
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - {{ get $tailscale "host" | default "api" }}
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}-public
                port:
                  name: http
{{- end }}
