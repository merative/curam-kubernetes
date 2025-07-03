{{- /*
"<chart>.sch.chart.config.values" contains the default configuration values used by
the Shared Configurable Helpers overridden for this chart.
*/ -}}
{{- define "mqserver.sch.chart.config.values" -}}
sch:
  appName: mqserver
  chart:
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
      productName: "IBM MQ Advanced for Developers"
      productID: "2f886a3eefbe4ccb89b2adb97c78b9cb"
      productVersion: "9.3.5.1-r2"
    podSecurityContext:
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
    initContainerSecurityContext:
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: false
        runAsNonRoot: false
        runAsUser: 0
        privileged: false
        capabilities:
          add:
            - CHOWN
            - FOWNER
            - DAC_OVERRIDE
          drop:
            - ALL
{{- end -}}
