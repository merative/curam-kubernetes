###############################################################################
# © Merative US L.P. 2022,2025
# Copyright 2020 IBM Corporation
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
ARG ANT_VERSION=1.10.6
ARG JMX_EXPORTER_URL=https://github.com/prometheus/jmx_exporter/releases/download/1.3.0/jmx_prometheus_javaagent-1.3.0.jar


# Intermediate image: extract Ant
FROM alpine AS PrepStage
ARG ANT_VERSION
COPY content/apache-ant-${ANT_VERSION}-bin.zip /tmp/apache-ant.zip
RUN unzip -qo /tmp/apache-ant.zip -d /opt/

COPY content/dependencies/javax.mail.jar /opt/javamail/mail.jar
COPY content/dependencies/activation.jar /opt/javamail/activation.jar
COPY content/release-stage/SetEnvironment.sh /opt/ibm/Curam/
COPY content/release-stage /opt/ibm/Curam/release
RUN chmod -R g=u /opt/ibm/Curam

FROM ibmcom/websphere-liberty:${WLP_VERSION}

WORKDIR /opt/ibm/Curam/release
ENTRYPOINT ["/opt/ibm/Curam/release/build.sh"]
CMD ["runbatch"]

ARG ANT_VERSION
ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION} \
    ANT_OPTS='-Xmx1400m -Dcmp.maxmemory=1400m' \
    IBM_JAVA_OPTIONS='-Xshareclasses:none -XX:+UseContainerSupport' \
    JAVA_HOME=/opt/ibm/java \
    JAVAMAIL_HOME=/opt/javamail \
    WLP_HOME=/opt/ibm/wlp
ENV PATH=$ANT_HOME/bin:$JAVA_HOME/bin:$PATH:.
USER root
RUN rpm -e --nodeps tzdata \
    && yum install -y tzdata \
    && yum clean all \
    && rm -rf /var/cache/yum
ARG JMX_EXPORTER_URL
ADD $JMX_EXPORTER_URL /opt/ibm/Curam/jmx_prometheus_javaagent.jar
RUN chmod -c +rx /opt/ibm/Curam/jmx_prometheus_javaagent.jar
USER 1001

COPY --chown=1001:0 content/*.sh /opt/ibm/helpers/runtime/
COPY --from=PrepStage --chown=1001:0 /opt/apache-ant-${ANT_VERSION} /opt/apache-ant-${ANT_VERSION}
COPY --from=PrepStage --chown=1001:0 /opt/javamail /opt/javamail
COPY --from=PrepStage --chown=1001:0 /opt/ibm/Curam /opt/ibm/Curam
COPY --chown=1001:0 content/release-stage/build/CryptoConfig.jar /opt/ibm/java/jre/lib/ext/
