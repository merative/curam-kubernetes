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
SSL properties for JDBC connection in Liberty. If global.db2.ssl.secretName is provided, assume it has been imported into a Trust Store
*/}}
{{- define "apps.ssljdbc" -}}
{{- if .enabled }}
  sslConnection="true"
  {{- if .secretName }}
  sslTrustStoreLocation="/output/resources/security/db2TrustStore.jks"
  sslTrustStorePassword="{xor}PDc+MTg6Nis="
  {{- end }}
{{- end }}
{{- end }}

{{/*
Liberty Datastore properties fragment
*/}}
{{- define "apps.dsprops.fragment" -}}
{{- $params := . -}}
{{- $root := first $params -}}
{{- $connMgrSuffix := (include "sch.utils.getItem" (list $params 1 "")) -}}
{{- $dbConfig := $root.Values.global.database -}}
{{- if eq ($dbConfig.type | upper) "DB2" -}}
<properties.db2.jcc databaseName="{{ $dbConfig.dbName }}"
  fullyMaterializeLobData="false"
  portNumber="{{ $dbConfig.port }}"
  serverName="{{ $dbConfig.hostname }}"
  password="${env.XOR_DB_PSW}"
  user="${env.SPM_DB_USR}"
  {{- include "apps.ssljdbc" $dbConfig.ssl }}
/>
{{- else if eq ($dbConfig.type | upper) "ORA" -}}
<properties.oracle
  URL="{{ include "apps.oracleurl" $root }}"
  password="${env.XOR_DB_PSW}"
  user="${env.SPM_DB_USR}"
/>
{{- else -}}
{{ fail ("Unsupported database type provided: " $dbConfig.type) }}
{{- end }}
<connectionManager
  maxPoolSize="${env.CM_{{ $connMgrSuffix | upper }}_MAX_POOL_SIZE}"
  numConnectionsPerThreadLocal="${env.CM_{{ $connMgrSuffix | upper }}_CONN_PER_THREAD}"
  purgePolicy="${env.CM_{{ $connMgrSuffix | upper }}_PURGE_POLICY}"
/>
{{- end -}}

{{/*
Oracle JDBC URL
*/}}
{{- define "apps.oracleurl" -}}
{{- $dbConfig := .Values.global.database -}}
{{- if $dbConfig.serviceName -}}
jdbc:oracle:thin:/@//{{ $dbConfig.hostname }}:{{ $dbConfig.port }}/{{ $dbConfig.serviceName }}
{{- else -}}
jdbc:oracle:thin:@{{ $dbConfig.hostname }}:{{ $dbConfig.port }}:{{ $dbConfig.dbName }}
{{- end }}
{{- end }}

{{/*
JDBC Connection driver JAR list
*/}}
{{- define "apps.dbdriver.jars" -}}
{{- if eq (.type | upper) "DB2" -}}
db2jcc4.jar db2jcc_license_cu.jar
{{- else if eq (.type | upper) "ORA" -}}
ojdbc8.jar
{{- else -}}
{{ fail ("Unsupported database type provided: " .type) }}
{{- end -}}
{{- end -}}
