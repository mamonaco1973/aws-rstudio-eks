#!/bin/bash
# ==============================================================================
# Wait for RStudio Ingress Load Balancer to Become Reachable
# ------------------------------------------------------------------------------
# 1. Waits for the Ingress to have a Load Balancer hostname assigned.
# 2. Then waits until the Load Balancer endpoint returns HTTP 200.
# ==============================================================================

NAMESPACE="default"
INGRESS_NAME="rstudio-ingress"
MAX_ATTEMPTS=30
SLEEP_SECONDS=10

echo "NOTE: Waiting for Load Balancer address for Ingress: ${INGRESS_NAME}..."

# --- Step 1: Wait for LB hostname ------------------------------------------------
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  LB_ADDRESS=$(kubectl get ingress ${INGRESS_NAME} \
    --namespace ${NAMESPACE} \
    --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

  if [[ -n "$LB_ADDRESS" ]]; then
    echo "NOTE: Load Balancer hostname detected:"
    echo "NOTE: RStudio Ingress Load Balancer: $LB_ADDRESS"
    export LB_ADDRESS
    break
  fi

  echo "WARNING: Attempt $i/${MAX_ATTEMPTS}: Load Balancer not ready yet... retrying in ${SLEEP_SECONDS}s"
  sleep ${SLEEP_SECONDS}
done

if [[ -z "$LB_ADDRESS" ]]; then
  echo "ERROR: Timed out waiting for Load Balancer hostname."
  exit 1
fi

# --- Step 2: Wait for LB endpoint to return HTTP 200 -----------------------------
echo "Waiting for Load Balancer endpoint (http://${LB_ADDRESS}) to return HTTP 200..."

for ((j=1; j<=MAX_ATTEMPTS; j++)); do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${LB_ADDRESS}")

  if [[ "$STATUS_CODE" == "200" ]]; then
    echo "NOTE: Load Balancer endpoint is ready (HTTP 200)"
    echo "NOTE: RStudio available at: http://${LB_ADDRESS}"
    exit 0
  fi

  echo "WARNING: Attempt $j/${MAX_ATTEMPTS}: Current status: HTTP ${STATUS_CODE} ... retrying in ${SLEEP_SECONDS}s"
  sleep ${SLEEP_SECONDS}
done

echo "ERROR: Timed out after ${MAX_ATTEMPTS} attempts waiting for HTTP 200 from Load Balancer."
exit 1
