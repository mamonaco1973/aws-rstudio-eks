#!/bin/bash
set -euo pipefail
touch /var/log/rstudio/rstudio-server/rserver.log
/usr/lib/rstudio-server/bin/rserver --server-daemonize=0 &
tail -f /var/log/rstudio/rstudio-server/rserver.log 


