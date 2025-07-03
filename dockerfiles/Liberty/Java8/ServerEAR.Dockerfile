###############################################################################
# © Merative US L.P. 2022,2025
# Copyright 2020,2022 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

ARG WLP_VERSION=25.0.0.3-full-java8-ibmjava-ubi
ARG MQ_ADAPTER_VERSION=9.2.4.0
ARG MQ_RA_LICENSE
ARG JMX_EXPORTER_URL=https://github.com/prometheus/jmx_exporter/releases/download/1.3.0/jmx_prometheus_javaagent-1.3.0.jar

# Explode EAR in a disposable environment
FROM alpine AS ExplodedEAR
ARG MQ_RA_LICENSE

COPY content/release-stage/ear/WLP/CuramServerCode.ear /tmp/
RUN mkdir -p /work/CuramServerCode.ear \
    && unzip -q /tmp/CuramServerCode.ear -d /work/CuramServerCode.ear \
    && rm -rf /tmp/*.ear /tmp/*.war \
    && mv /work/CuramServerCode.ear/properties.jar /tmp/properties.jar

# Run MQ Adapter installer in a disposable environment
FROM ibmjava:8-sdk AS MQAdapter
ARG MQ_ADAPTER_VERSION
ARG MQ_RA_LICENSE

COPY content/${MQ_ADAPTER_VERSION}-IBM-MQ-Java-InstallRA.jar /tmp/
RUN java -jar /tmp/${MQ_ADAPTER_VERSION}-IBM-MQ-Java-InstallRA.jar ${MQ_RA_LICENSE} /opt

# Create final image
FROM ibmcom/websphere-liberty:${WLP_VERSION} AS servercode
ARG JMX_EXPORTER_URL

ENV IBM_JAVA_OPTIONS='-Xshareclasses:none -XX:+UseContainerSupport'

USER root
# Prometheus JMX Exporter
ADD $JMX_EXPORTER_URL /config/configDropins/overrides/jmx_prometheus_javaagent.jar
RUN rpm -e --nodeps tzdata \
    && yum install -y tzdata \
    && yum install -y wget \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && ln -s /opt/ibm/wlp/usr/shared/resources /shared_resources \
    && chown -R 1001:0 /config/configDropins \
    && chown -R 1001:0 /opt/ibm/wlp/usr/shared \
    && chmod -R g=u /opt/ibm/wlp/usr/shared \
    && chmod -R g=u /output \
    && rm -f /config/configDropins/defaults/* \
    && touch /config/configDropins/overrides/config.yaml \
    && chown 1001:0 /config/configDropins/overrides/config.yaml /config/configDropins/overrides/jmx_prometheus_javaagent.jar \
    && rm -f /tmp/wget.txt

USER 1001

COPY --chown=1001:0 content/*.sh /opt/ibm/helpers/runtime/
COPY --from=MQAdapter --chown=1001:0 /opt/wmq /opt/wmq
COPY --chown=1001:0 content/release-stage/CuramSDEJ/drivers/db2jcc*.jar /shared_resources/drivers/
COPY --chown=1001:0 content/release-stage/CuramSDEJ/drivers/ojdbc*.jar /shared_resources/drivers/
COPY --chown=1001:0 content/release-stage/CuramSDEJ/lib/WLPRegistry.jar /shared_resources/
COPY --chown=1001:0 content/release-stage/CuramSDEJ/lib/coreinf-ejb-interfaces.jar /shared_resources/
COPY --chown=1001:0 content/release-stage/build/CryptoConfig.jar /opt/ibm/java/jre/lib/ext/
COPY --from=ExplodedEAR --chown=1001:0 /work /config/apps
COPY --from=ExplodedEAR --chown=1001:0 /tmp/properties.jar /shared_resources/

# Install defaultServer and wmqJmsClient-2.0 if available
RUN installUtility install defaultServer \
    && (installUtility install wmqJmsClient-2.0 || true)
