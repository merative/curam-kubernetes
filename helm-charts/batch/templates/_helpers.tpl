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
Build up full image path
*/}}
{{- define "batch.imageFullName" -}}
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
Build up Ant Options for general and JMX Stats configuration
*/}}
{{- define "batch.antOpts" }}
{{- printf "-Djava.extra.jvmargs=\"-Dcuram.db.username=$SPM_DB_USR -Dcuram.db.password=$SPM_DB_PSW -Xverbosegclog:/tmp/gc/verbosegc.log\" " -}}
{{- if and .PersistenceConfig.enabled .PersistenceConfig.jmxstats.enabled -}}
{{- printf " -Dcuram.jmx.output_statistics_timer_enabled=true -Dcuram.jmx.output_statistics_timer_folder=/tmp/jmx/ -Dcuram.jmx.output_statistics_timer_period=%d" (default 60000 .PersistenceConfig.jmxstats.timerPeriod | int) -}}
{{- end }}
{{- if .MaxMemory -}}
{{- printf " -Djava.maxmemory=%s" .MaxMemory -}}
{{- end }}
{{- default .DefaultOptions .ProgramOptions -}}
{{- end }}

{{/*
Create the image pull secret
*/}}
{{- define "batch.imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .registry (printf "%s:%s" .username (required "Credentials password is required" .password) | b64enc) | b64enc }}
{{- end }}

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