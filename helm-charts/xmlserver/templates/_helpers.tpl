{{/*
© Merative US L.P. 2022,2025
Copyright 2019,2022 IBM Corporation

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
Expand the name of the chart.
*/}}
{{- define "xmlserver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "xmlserver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Build up full image path
*/}}
{{- define "xmlserver.imageFullName" -}}
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
Create the image pull secret
*/}}
{{- define "xmlserver.imagePullSecret" }}
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
ibmjava image
*/}}
{{- define "xmlserver.utilities.definition" }}
image: {{ include "xmlserver.imageFullName" (dict "ImageConfig" .Values.global.images "ImageName" "utilities") }}
{{- include "initContainer.resources" . }}
{{- include "sch.security.securityContext" (list . .sch.chart.containerSecurityContext) }}
{{- end }}

