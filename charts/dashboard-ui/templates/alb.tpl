{{- if not .Values.gcp }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ui.alb.public_domain_certificate }}
    alb.ingress.kubernetes.io/aws-load-balancer-ssl-ports: https
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-FIPS-2023-04
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '5'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/tags: 'service=dashboard-ui,service_type=ui,env={{ .Values.env.ENV }}'
    alb.ingress.kubernetes.io/actions.deny-proxy: '{"type":"fixed-response","fixedResponseConfig":{"contentType":"text/plain","statusCode":"403","messageBody":"Forbidden"}}'
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.ui.alb.public_domain }}
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /public/swagger
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/temporal-codec
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/swagger
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/temporal
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/kafka
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/grafana
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/v1
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /admin/dashboard
            pathType: Prefix
            backend:
              service:
                name: deny-proxy
                port:
                  name: use-annotation
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}
                port:
                  name: http
{{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  type: ClusterIP
  ports:
    - name: http
      port: 4000
      targetPort: http
