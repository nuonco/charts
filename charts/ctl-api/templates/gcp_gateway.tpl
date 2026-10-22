{{- if .Values.gcp.enabled }}
{{- $scope := .Values.gcp.scope | default "global" }}
{{- if not (has $scope (list "global" "regional")) }}
{{- fail (printf "gcp.scope must be one of: global, regional (got %q)" $scope) }}
{{- end }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: external-gateway
  namespace: {{ .Release.Namespace }}
  labels:
    # The public external-dns instance filters on this label so it never publishes
    # the internal IPs of other gateways (e.g. psc-gateway) into the public zone.
    nuon.co/external-dns: public
  {{- if eq $scope "global" }}
  annotations:
    networking.gke.io/certmap: {{ .Values.gcp.certMap }}
  {{- end }}
spec:
  {{- if eq $scope "global" }}
  gatewayClassName: gke-l7-global-external-managed
  {{- else }}
  gatewayClassName: gke-l7-regional-external-managed
  {{- end }}
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      {{- if eq $scope "regional" }}
      {{- if not .Values.gcp.certificates }}
      {{- fail "gcp.certificates is required when gcp.scope is regional" }}
      {{- end }}
      tls:
        mode: Terminate
        options:
          networking.gke.io/cert-manager-certs: {{ join "," .Values.gcp.certificates | quote }}
      {{- end }}
      allowedRoutes:
        namespaces:
          from: All
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
{{- if .Values.gcp.psc.enabled }}
---
# Internal gateway published to consumers over Private Service Connect. The service
# attachment is created outside the chart, against the forwarding rule for this
# gateway's static address. Kept separate from internal-gateway, which serves the
# unauthenticated admin API: a PSC consumer can send any Host header, so only routes
# listed in gcp.psc.routes attach here and unmatched hosts get a 404.
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: psc-gateway
  namespace: {{ .Release.Namespace }}
spec:
  gatewayClassName: gke-l7-rilb
  addresses:
    - type: NamedAddress
      value: {{ required "gcp.psc.addressName is required when gcp.psc.enabled" .Values.gcp.psc.addressName }}
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      {{- if not .Values.gcp.psc.certificates }}
      {{- fail "gcp.psc.certificates is required when gcp.psc.enabled" }}
      {{- end }}
      tls:
        mode: Terminate
        options:
          networking.gke.io/cert-manager-certs: {{ join "," .Values.gcp.psc.certificates | quote }}
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  {{- range (prepend (.Values.gcp.psc.allowedNamespaces | default list) .Release.Namespace | uniq) }}
                  - {{ . }}
                  {{- end }}
{{- if .Values.gcp.psc.globalAccess }}
---
# Global access can't be added to the forwarding rule once a PSC service attachment
# references it, so it is on from the start.
apiVersion: networking.gke.io/v1
kind: GCPGatewayPolicy
metadata:
  name: psc-gateway
  namespace: {{ .Release.Namespace }}
spec:
  default:
    allowGlobalAccess: true
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: psc-gateway
{{- end }}
{{- end }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-to-https-redirect
  namespace: {{ .Release.Namespace }}
spec:
  parentRefs:
    - kind: Gateway
      name: external-gateway
      sectionName: http
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-public-hc
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
        requestPath: {{ .Values.api.readiness_probe }}
        port: {{ .Values.api.public.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-public
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-runner-hc
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
        requestPath: {{ .Values.api.readiness_probe }}
        port: {{ .Values.api.runner.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-runner
{{- if .Values.auth.enabled }}
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-auth-hc
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
        requestPath: {{ .Values.api.readiness_probe }}
        port: {{ .Values.api.auth.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-auth
{{- end }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: internal-gateway
  namespace: {{ .Release.Namespace }}
spec:
  gatewayClassName: gke-l7-rilb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: {{ include "common.fullname" . }}-admin-hc
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
        requestPath: {{ .Values.api.readiness_probe }}
        port: {{ .Values.api.admin.port }}
  targetRef:
    group: ""
    kind: Service
    name: {{ include "common.fullname" . }}-admin
{{- end }}
