{{/*
mTLS certs for the Kafka client, mounted into every pod that produces or
consumes. Two secrets, both created by Strimzi in the kafka namespace and
mirrored into this one by Reflector:
  <cluster>-cluster-ca-cert  ca.crt              verify the brokers
  <kafkaUser>                user.crt, user.key  present our own identity

Unconditional: Kafka is part of the platform, not an opt-in feature. Both names
are derived from the Kafka CR and KafkaUser names, so they are identical in every
environment — which is why they can be defaulted in values.yaml rather than
plumbed through per install.

Mounted as whole-secret volumes, NOT subPath: a subPath mount never receives
secret updates, so a rotated cert would silently never reach the process. The app
re-reads these from disk per TLS handshake, so rotation needs no restart.

optional: the secrets only exist once the Kafka cluster has been provisioned and
Reflector has mirrored them here. Without this, a non-existent secret leaves
every pod in ContainerCreating — which would take the whole control plane down
while Kafka is still being stood up, or in any install that does not have Kafka
yet. With it, a missing secret mounts as an empty directory and is inert while
KAFKA_ENABLED is false; once enabled, the client fails fast at startup instead,
which is a far clearer error.

Do not remove `optional: true`.
*/}}
{{- define "common.kafkaCertVolumes" -}}
- name: kafka-ca
  secret:
    secretName: {{ $.Values.kafka.certs.caSecret }}
    defaultMode: 0400
    optional: true
- name: kafka-user
  secret:
    secretName: {{ $.Values.kafka.certs.userSecret }}
    defaultMode: 0400
    optional: true
{{- end -}}

{{- define "common.kafkaCertVolumeMounts" -}}
- name: kafka-ca
  mountPath: /etc/kafka/certs/ca
  readOnly: true
- name: kafka-user
  mountPath: /etc/kafka/certs/user
  readOnly: true
{{- end -}}
