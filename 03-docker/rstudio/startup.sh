#!/bin/bash
set -euo pipefail

echo "NOTE: Starting RStudio Server (forcing visible logs)..."

/usr/lib/rstudio-server/bin/rserver --server-daemonize=0 
