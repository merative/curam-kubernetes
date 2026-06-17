###############################################################################
# © Merative US L.P. 2022,2026
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

# If set, must end with a forward slash, e.g. "registry.connect.redhat.com/"
ARG BASE_REGISTRY

FROM ${BASE_REGISTRY}ibm/ibm-semeru-runtime-open-jdk-8-ubi:8u482-b08.1-amd64

USER root
RUN rpm -e --nodeps tzdata \
    && dnf install -y nc tzdata \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

USER 1001
