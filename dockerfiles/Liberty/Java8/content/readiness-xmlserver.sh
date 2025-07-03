#!/bin/bash
###############################################################################
# © Merative US L.P. 2023,2025
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
# Create execution log
exec 19>/tmp/readiness-xmlserver.log
BASH_XTRACEFD=19
set -x

XMLSERVER_PATH=/opt/ibm/Curam/xmlserver

if [ ! -e $XMLSERVER_PATH ] ; then
  # This is never expected and will fail the readinessProbe
  echo "FATAL - Did not find XML server path"
  exit 1
fi

XMLSERVER_LOG=$XMLSERVER_PATH/tmp/xmlserver.log
if [ ! -e $XMLSERVER_LOG ] ; then
  echo "INFO - Did not find $XMLSERVER_LOG.the xmlserver.log."
  echo "       So, probe is indeterminate and leaving quietly."
  exit 0
fi

grep 'XML Server awaiting connections on port' $XMLSERVER_LOG
LASTRC=$?

set +x
exit $?
