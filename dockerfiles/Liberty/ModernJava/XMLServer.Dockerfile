###############################################################################
# © Merative US L.P. 2025
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

ARG ANT_VERSION=1.10.6

# Note: This public JMX Exporter is for getting JVM metrics
ARG JMX_EXPORTER_URL=https://github.com/prometheus/jmx_exporter/releases/download/1.3.0/jmx_prometheus_javaagent-1.3.0.jar

# If set, must end with a forward slash, e.g. "registry.connect.redhat.com/"
ARG BASE_REGISTRY

# Intermediate image: extract Ant
FROM alpine AS ExtractAndMod
ARG ANT_VERSION
COPY content/apache-ant-${ANT_VERSION}-bin.zip /tmp/apache-ant.zip
COPY content/release-stage/CuramSDEJ/xmlserver /opt/ibm/Curam/xmlserver
COPY content/start-xmlserver.sh /opt/ibm/Curam/xmlserver/start-xmlserver.sh
COPY content/stop-xmlserver.sh /opt/ibm/Curam/xmlserver/stop-xmlserver.sh

# For XML Server probes
COPY content/readiness-xmlserver.sh /opt/ibm/Curam/xmlserver/xmlserverprobes/readiness-xmlserver.sh
COPY content/release-stage/CuramSDEJ/lib/appinf.jar /opt/ibm/Curam/xmlserver/xmlserverprobes/appinf.jar
COPY content/release-stage/CuramSDEJ/lib/appinf_internal.jar /opt/ibm/Curam/xmlserver/xmlserverprobes/appinf_internal.jar
COPY content/release-stage/CuramSDEJ/lib/coreinf.jar /opt/ibm/Curam/xmlserver/xmlserverprobes/coreinf.jar
COPY content/liveness-xmlserver.xml /opt/ibm/Curam/xmlserver/xmlserverprobes/liveness-xmlserver.xml

RUN unzip -qo /tmp/apache-ant.zip -d /opt/ \
    && chgrp -Rc 0 /opt/ibm/Curam \
    && chmod -Rc g=u /opt/ibm/Curam \
    && chmod -c +x /opt/ibm/Curam/xmlserver/*.sh

# Final image
FROM ${BASE_REGISTRY}ibm/ibm-semeru-runtime-certified-jdk-21-ubi:21.0.4.1

EXPOSE 1800
WORKDIR /opt/ibm/Curam/xmlserver
ENTRYPOINT ["/opt/ibm/Curam/xmlserver/start-xmlserver.sh"]

ARG ANT_VERSION
ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION} \
    ANT_OPTS='-Xmx1400m -Dcmp.maxmemory=1400m' \
    JAVA_HOME=/opt/ibm/java
ENV PATH=$ANT_HOME/bin:$JAVA_HOME/bin:$PATH:.

USER root
RUN rpm -e --nodeps tzdata \
    && yum install -y tzdata \
    && yum install -y hostname \
    && yum clean all \
    && rm -rf /var/cache/yum
RUN mkdir -p /opt/ibm/Curam/xmlserver \
    && chmod -c g+w /etc/passwd $JAVA_HOME/lib/security/cacerts

# Prometheus JMX Exporter
ARG JMX_EXPORTER_URL
ADD $JMX_EXPORTER_URL /opt/ibm/Curam/xmlserver/jmx_prometheus_javaagent.jar
RUN chmod -c +rx /opt/ibm/Curam/xmlserver/jmx_prometheus_javaagent.jar

COPY --from=ExtractAndMod --chown=1001:0 /opt/apache-ant-${ANT_VERSION} /opt/apache-ant-${ANT_VERSION}
COPY --from=ExtractAndMod --chown=1001:0 /opt/ibm/Curam /opt/ibm/Curam

USER 1001