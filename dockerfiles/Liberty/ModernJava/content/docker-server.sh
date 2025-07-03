#!/bin/bash
set -e
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

case "${LICENSE,,}" in
  "accept" ) # Suppress license message in logs
    grep -s -F "com.ibm.ws.logging.hideMessage" /config/bootstrap.properties \
      && sed -i 's/^\(com.ibm.ws.logging.hideMessage=.*$\)/\1,CWWKE0100I/' /config/bootstrap.properties \
      || echo "com.ibm.ws.logging.hideMessage=CWWKE0100I" >> /config/bootstrap.properties
    ;;
  "view" ) # Display license file
    cat /opt/ibm/wlp/lafiles/LI_${LANG:-en}
    exit 1
    ;;
  "" ) # Continue, displaying license message in logs
    true
    ;;
  *) # License not accepted
    echo -e "Set environment variable LICENSE=accept to indicate acceptance of license terms and conditions.\n\nLicense agreements and information can be viewed by running this image with the environment variable LICENSE=view.  You can also set the LANG environment variable to view the license in a different language."
    exit 1
    ;;
esac

# Creates directories for persistence on the PV volume (if set by Helm)
if [ -n "$MOUNT_POINT" ]; then
  # Persistence volume can be slow to mount
  while [ ! -d "$MOUNT_POINT" ]; do
    sleep 1
  done
  mkdir -p $MOUNT_POINT/$HOSTNAME/logs
  mkdir -p $MOUNT_POINT/$HOSTNAME/jmx
  mkdir -p $MOUNT_POINT/$HOSTNAME/dump
  mkdir -p $MOUNT_POINT/$HOSTNAME/gc
  ln -s $MOUNT_POINT/$HOSTNAME/logs /tmp/logs
  ln -s $MOUNT_POINT/$HOSTNAME/jmx  /tmp/jmx
  ln -s $MOUNT_POINT/$HOSTNAME/dump /tmp/dump
  ln -s $MOUNT_POINT/$HOSTNAME/gc   /tmp/gc
  echo "1,$HOSTNAME" > /tmp/gc/GC_PID.pid       # Required by Performance Dashboard
fi

# Pass on to the real server run
exec "$@"
