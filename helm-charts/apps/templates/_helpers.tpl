{{/*
© Merative US L.P. 2022,2025
Copyright 2019,2020 IBM Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

{{/* vim: set filetype=mustache: */}}
{{/*
Create the image pull secret
*/}}
{{- define "apps.imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .registry (printf "%s:%s" .username (required "Credentials password is required" .password) | b64enc) | b64enc }}
{{- end }}

{{/*
Build up full image path
*/}}
{{- define "apps.imageFullName" -}}
{{- .ImageConfig.registry -}}/
{{- if .ImageConfig.imageLibrary -}}
{{- .ImageConfig.imageLibrary -}}/
{{- end -}}
{{- if .ImageConfig.imagePrefix -}}
{{- .ImageConfig.imagePrefix -}}
{{- end -}}
{{- .ImageName -}}:{{- .ImageConfig.imageTag -}}
{{- end -}}

{{/*
Folder name where the Liberty application will store its logs
*/}}
{{- define "apps.logsDir" -}}
{{- if .Values.global.apps.common.persistence.enabled -}}
{{- "/tmp/logs" -}}
{{- else -}}
{{- "/logs" -}}
{{- end -}}
{{- end -}}

{{/*
Mountpoint for the persistence storage on the application pods (e.g. /tmp/persistence )
*/}}
{{- define "persistence.mountPoint" -}}
{{- if .Values.global.apps.common.persistence.mountPoint -}}
{{- .Values.global.apps.common.persistence.mountPoint -}}
{{- else -}}
{{- "/tmp/persistence" -}}
{{- end -}}
{{- end -}}

{{/*
JMX Stats Persistence enablement options
*/}}
{{- define "persistence.jmxStats" -}}
{{- "-Dcuram.jmx.output_statistics_timer_enabled=true" }}
{{ "-Dcuram.jmx.output_statistics_timer_folder=/tmp/jmx/" }}
{{ printf "-Dcuram.jmx.output_statistics_timer_period=%d" ( .Values.global.apps.common.persistence.jmxstats.timerPeriod | default 60000 | int ) -}}
{{- end -}}

{{/*
Prometheus JMX Exporter JVM Config
*/}}
{{- define "jmxExporter.configJvm" -}}
{{- printf "-javaagent:/config/configDropins/overrides/jmx_prometheus_javaagent.jar=%d:/config/configDropins/overrides/config.yaml" ( .Values.jmxExporter.port | default 8080 | int ) -}}
{{- end -}}

{{/*
InitContainer resources
*/}}
{{- define "initContainer.resources" }}
resources:
  limits:
    memory: 256Mi
    cpu: 250m
  requests:
    memory: 128Mi
    cpu: 250m
{{- end }}

{{/*
InitContainer resources for applying custom SQL
*/}}
{{- define "customSQL.definition" }}
image: {{ include "apps.imageFullName" (dict "ImageConfig" $.Values.global.images "ImageName" "batch") }}
{{- include "initContainer.resources" $ }}
{{- include "sch.security.securityContext" (list $ $.sch.chart.containerSecurityContext) }}
{{- end }}

{{/*
ibmjava image
*/}}
{{- define "utilities.definition" }}
image: {{ include "apps.imageFullName" (dict "ImageConfig" $.Values.global.images "ImageName" "utilities") }}
{{- include "initContainer.resources" $ }}
{{- include "sch.security.securityContext" (list $ $.sch.chart.containerSecurityContext) }}
{{- end }}

{{/*
JMS Queue Connection Factory properties
*/}}
{{- define "jms.queueConnectionFactory" }}
<properties.wmqJms
  {{- if .Values.global.mq.useConnectionNameList }}
  connectionNameList="${connectionNameList}"
  {{- else }}
  hostName="${mqHostName}"
  port="${listenerPort}"
  {{- end }}
  queueManager="${mqName}"
  channel="${channel}"
  userName="${userName}"
  sslCipherSuite="SSL_RSA_WITH_AES_128_CBC_SHA256"
/>
{{- end }}

{{/*
JMS Topic Connection Factory properties
*/}}
{{- define "jms.topicConnectionFactory" }}
<properties.wmqJms
  {{- if .Values.global.mq.useConnectionNameList }}
  connectionNameList="{{ .Values.global.apps.config.curam.mqConnectionNameList }}"
  queueManager="{{ .Values.global.mq.objectSuffix }}_curam"
  channel="CHL_{{ .Values.global.mq.objectSuffix | upper }}_CURAM"
  {{- else }}
  {{- if ($.Capabilities.APIVersions.Has "mq.ibm.com/v1beta1") }}
  hostName="{{ $.Release.Name }}-mqserver-curam-ibm-mq"
  {{- else }}
  hostName="{{ $.Release.Name }}-mqserver-curam"
  {{- end }}
  port="${listenerPort}"
  queueManager="${mqName}"
  channel="${channel}"
  {{- end }}
  userName="${userName}"
  sslCipherSuite="SSL_RSA_WITH_AES_128_CBC_SHA256"
/>
{{- end }}

{{/*
JMS Queue Activation Spec properties
*/}}
{{- define "jms.queueActivationSpec" }}
{{- $params := . -}}
{{- $root := first $params -}}
{{- $refName := (include "sch.utils.getItem" (list $params 1 "")) -}}
<properties.wmqJms
  destinationRef="{{ $refName }}"
  destinationType="javax.jms.Queue"
  {{- if $root.Values.global.mq.useConnectionNameList }}
  connectionNameList="${connectionNameList}"
  {{- else }}
  hostName="${mqHostName}"
  port="${listenerPort}"
  {{- end }}
  queueManager="${mqName}"
  channel="${channel}"
  userName="${userName}"
  sslCipherSuite="SSL_RSA_WITH_AES_128_CBC_SHA256"
  subscriptionDurability="Durable"
/>
{{- end }}

{{/*
JMS Topic Activation Spec properties
*/}}
{{- define "jms.topicActivationSpec" }}
<properties.wmqJms
  destinationRef="CuramCacheInvalidationTopic"
  destinationType="javax.jms.Topic"
  {{- if .Values.global.mq.useConnectionNameList }}
  connectionNameList="{{ .Values.global.apps.config.curam.mqConnectionNameList }}"
  queueManager="{{ .Values.global.mq.objectSuffix }}_curam"
  channel="CHL_{{ .Values.global.mq.objectSuffix | upper }}_CURAM"
  {{- else }}
  {{- if ($.Capabilities.APIVersions.Has "mq.ibm.com/v1beta1") }}
  hostName="{{ $.Release.Name }}-mqserver-curam-ibm-mq"
  {{- else }}
  hostName="{{ $.Release.Name }}-mqserver-curam"
  {{- end }}
  port="${listenerPort}"
  queueManager="${mqName}"
  channel="${channel}"
  {{- end }}
  userName="${userName}"
  sslCipherSuite="SSL_RSA_WITH_AES_128_CBC_SHA256"
  subscriptionDurability="Durable"
/>
{{- end }}

{{/*
Value Validation Function
*/}}
{{- define "apps.value-validation" -}}
{{- $value := (.value | toString) -}}
{{- if or (contains "--" $value) (contains "#" $value) (contains ";" $value) (contains "'" $value) (contains "||" $value) (contains "/*" $value) -}}
{{- $error :=  print "\n\nERROR: forbidden characters (-- # /* ;) in value: " $value  -}}
{{- fail $error -}}
{{- end -}}
{{- end -}}
