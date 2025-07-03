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

ARG CONTENT_DIR=CuramStatic

# If set, must end with a forward slash, e.g. "registry.redhat.io/"
ARG BASE_REGISTRY

# Unzip static content in to temp
FROM alpine AS ExplodedStaticzip
COPY StaticContent.zip /tmp/
RUN mkdir -p /work/staticcontent/ \
    && unzip -o -q /tmp/StaticContent.zip -d /work/staticcontent/ \
    && chmod -R g=u /work/staticcontent

# Final
FROM ${BASE_REGISTRY}rhel8/httpd-24
ARG CONTENT_DIR

COPY --from=ExplodedStaticzip --chown=1001:0 /work/staticcontent/WebContent /var/www/html/$CONTENT_DIR
USER root
RUN rpm -e --nodeps tzdata \
    && yum install -y tzdata \
    && yum clean all \
    && rm -rf /var/cache/yum
USER 1001
