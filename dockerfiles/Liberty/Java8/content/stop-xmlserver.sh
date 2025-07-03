#!/bin/bash
set -e
###############################################################################
# © Merative US L.P. 2022,2025
# Copyright 2020,2021 IBM Corporation
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
XMLSERVER_PATH=/opt/ibm/Curam/xmlserver

echo "INFO - Stopping XML Server ..."

# Set the xmlserver.log path
XMLSERVER_LOG=$XMLSERVER_PATH/tmp/xmlserver.log

# The start-xmlserver.sh script hard codes the GC settings in the xmlserver.xml java.jvmargs property,
# so here java.jvmargs is set explicitly to "" to avoid overwriting the verbosegc.log file.
ant -f $XMLSERVER_PATH/xmlserver.xml stop -Djava.jvmargs="" 2>&1 | tee -a $XMLSERVER_LOG
if [ $? = 0 ]
then
  echo "INFO - XML Server stop invoked."
else
  echo "ERROR - XML Server stop invocation failed; more information may be found in $XMLSERVER_LOG"
fi

