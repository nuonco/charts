{{/*
Standalone NEG Service for one API.

A second ClusterIP Service beside the regular one, annotated so GKE creates a zonal
NEG with a fixed name that a load balancer managed outside the cluster attaches to.
Takes ctx, svc (public, runner, ...), port, targetPort and the api.<svc>.neg values.
*/}}
{{- define "ctl-api.negService" -}}
{{- $name := printf "%s-%s" (include "common.fullname" .ctx) .svc }}
{{- $neg := .neg.name | default $name }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}-neg
  namespace: {{ .ctx.Release.Namespace }}
  labels:
    {{- include "common.apiLabels" .ctx | nindent 4 }}
    app.nuon.co/name: {{ $name }}
  annotations:
    cloud.google.com/neg: {{ dict "exposed_ports" (dict (toString .port) (dict "name" $neg)) | toJson | quote }}
spec:
  selector:
    {{- include "common.apiSelectorLabels" .ctx | nindent 4 }}
    app.nuon.co/name: {{ $name }}
  type: ClusterIP
  ports:
    - name: http
      port: {{ .port }}
      targetPort: {{ .targetPort }}
{{- end }}
