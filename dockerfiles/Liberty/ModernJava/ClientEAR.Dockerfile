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

ARG EAR_NAME
ARG SERVERCODE_IMAGE=servercode:latest
ARG WLP_VERSION=25.0.0.3-full-java21-openj9-ubi-minimal

# Explode EAR in a disposable environment
FROM alpine AS ExplodedEAR
ARG EAR_NAME

RUN apk add --no-cache unzip

COPY content/release-stage/ear/WLP/${EAR_NAME}.ear /tmp/
RUN mkdir -p /work/${EAR_NAME}.ear \
    && unzip -q /tmp/${EAR_NAME}.ear -d /work/${EAR_NAME}.ear \
    && ORIG_WAR_PATH=`find /work/${EAR_NAME}.ear -type f -name "*.war"` \
    && mv $ORIG_WAR_PATH /tmp/ \
    && mkdir -p $ORIG_WAR_PATH \
    && unzip -q /tmp/`basename $ORIG_WAR_PATH` -d $ORIG_WAR_PATH \
    && rm -rf /tmp/*.ear /tmp/*.war \
    && find /work -type f -name ibm-web-bnd.xm* | xargs -n1 sed -i 's|client_host|default_host|g' \
    && find /work -type f -name ibm-web-bnd.xm* | xargs -n1 sed -i 's|webservices_host|default_host|g' \
    && find /work -type d -name configuration -exec chmod -Rv g+w {} +

# Create final image
FROM ${SERVERCODE_IMAGE}
ARG EAR_NAME

COPY --from=ExplodedEAR --chown=1001:0 /work /config/apps
