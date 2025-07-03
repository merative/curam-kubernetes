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
{{- define "spm.imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .registry (printf "%s:%s" .username (required "Credentials password is required" .password) | b64enc) | b64enc }}
{{- end }}

{{/*
Create the persistence credentials
*/}}
{{- define "spm.persistenceCredentials" -}}
{{- range $key, $val := (required "Persistence storage credentials were not provided! (global.apps.common.persistence.credentials)" .credentials) -}}
{{ printf "%s: %s\n" $key ($val | quote) }}
{{- end -}}
{{- end -}}

{{/*
Create the persistence properties
*/}}
{{- define "spm.persistenceProperties" -}}
{{- if $.Values.global.apps.common.persistence.properties -}}
{{- toYaml $.Values.global.apps.common.persistence.properties }}
{{- end -}}
{{- end -}}

{{/*
Build up ssl-services value
*/}}
{{- define "spm.sslServicesChain" }}
{{- range $name, $app := .Values.global.apps.config -}}
{{- if $app.enabled -}}
ssl-service={{ $.Release.Name }}-apps-{{ $name }};
{{- end -}}
{{- end -}}
{{- if .Values.uawebapp.imageConfig.name -}}
ssl-service={{ $.Release.Name }}-uawebapp;
{{- end -}}
ssl-service={{ $.Release.Name }}-web;
{{- end }}

{{/*
Template for Ingress path definitions
*/}}
{{- define "spm.ingress.item" -}}
- path: {{ .path }}
  pathType: ImplementationSpecific
  backend:
    {{- if .caps.APIVersions.Has "networking.k8s.io/v1" }}
    service:
      name: {{ .name }}
      port:
        {{- if (kindIs "int" .port) }}
        number: {{ .port }}
        {{- else }}
        name: {{ .port }}
        {{- end }}
    {{- else }}
    serviceName: {{ .name }}
    servicePort: {{ .port }}
    {{- end }}
{{- end -}}
