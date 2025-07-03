{{/*
© Merative US L.P. 2022,2025
Copyright 2020 IBM Corporation

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

{{- /*
"<chart>.sch.chart.config.values" contains the default configuration values used by
the Shared Configurable Helpers overridden for this chart.
*/ -}}
{{- define "uawebapp.sch.chart.config.values" -}}
sch:
  appName: uawebapp
  chart:
    podAntiAffinity:
      preferredDuringScheduling:
        uawebapp:
          weight: 100
          key: app.kubernetes.io/name
          operator: In
          topologyKey: topology.kubernetes.io/zone
      preferredDuringScheduling:
        uawebapp:
          weight: 100
          key: app.kubernetes.io/name
          operator: In
          topologyKey: kubernetes.io/hostname
    nodeAffinity:
      nodeAffinityRequiredDuringScheduling:
        key: kubernetes.io/arch
        operator: In
        values:
          - amd64
      nodeAffinityPreferredDuringScheduling:
        {{ default "application" $.Values.affinityValue }}:
          key: {{ default "worker-type" $.Values.affinityKey }}
          operator: In
          weight: 100
    labelType: "prefixed"
    metering:
      productName: "IBM Curam Citizen Engagement"
      productVersion: "8.0"
      productID: "871ebfd3cbd04513813d51718bed9494"
    podSecurityContext:
      hostIPC: false
      hostNetwork: false
      hostPID: false
      securityContext:
        runAsNonRoot: true
    containerSecurityContext:
      securityContext:
        privileged: false
        readOnlyRootFilesystem: false
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
{{- end -}}
