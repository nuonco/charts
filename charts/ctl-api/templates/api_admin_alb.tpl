{{- if and .Values.ingress.enabled .Values.api.admin.enabled (not .Values.gcp.enabled) }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}-admin
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-admin
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/aws-load-balancer-ssl-ports: https
    alb.ingress.kubernetes.io/healthcheck-path: /livez
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '5'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    {{- include "common.albGroup" (dict "group" .Values.ingressGroups.internal.name "groupTags" .Values.ingressGroups.internal.tags "tags" (printf "service=ctl-api,service_type=api,service_deployment=admin,env=%s" .Values.env.ENV)) | nindent 4 }}
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.api.admin.domain }}
spec:
  ingressClassName: alb
  rules:
    {{- if .Values.ingressGroups.internal.name }}
    - host: {{ .Values.api.admin.domain | quote }}
      http:
    {{- else }}
    - http:
    {{- end }}
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}-admin
                port:
                  name: http
{{- end }}
