#!/bin/bash
set -euo pipefail
# Just run in foreground; rserver writes logs to stdout/stderr
exec /usr/lib/rstudio-server/bin/rserver --server-daemonize=0
