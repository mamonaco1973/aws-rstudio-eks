#!/bin/bash
set -euo pipefail

echo "=== Starting RStudio Server (forcing visible logs) ==="

/usr/lib/rstudio-server/bin/rserver --server-daemonize=0 \
  2>&1 | tee /var/log/rstudio/rstudio-server/rserver.log /proc/1/fd/1
