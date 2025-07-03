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
{{- define "web.imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .registry (printf "%s:%s" .username (required "Credentials password is required" .password) | b64enc) | b64enc }}
{{- end }}

{{/*
Build up full image path
*/}}
{{- define "web.imageFullName" -}}
{{- $imageConfig := .Values.global.images -}}
{{- $imageConfig.registry -}}/
{{- if $imageConfig.imageLibrary -}}
{{- $imageConfig.imageLibrary -}}/
{{- end -}}
{{- if $imageConfig.imagePrefix -}}
{{- $imageConfig.imagePrefix -}}
{{- end -}}
httpd:{{- default $imageConfig.imageTag .Values.imageTagOverride -}}
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
