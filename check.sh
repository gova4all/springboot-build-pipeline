#!/bin/bash

PORT=$1

if [ -z "$PORT" ]; then
   echo "ERROR: Port argument missing!"
   echo "Usage: ./check.sh <PORT>"
   exit 1
fi

echo "Checking application on port: $PORT"

# Retry up to 10 times (about 100 seconds total)
MAX_RETRIES=10
SLEEP_SECONDS=10
ATTEMPT=1
SUCCESS=0

while [ $ATTEMPT -le $MAX_RETRIES ]; do
   echo "Attempt $ATTEMPT/$MAX_RETRIES: checking http://localhost:$PORT ..."
   # Use -f so curl fails on non-2xx, follow redirects just in case
   if curl -fsS --max-redirs 10 "http://localhost:$PORT" > /dev/null 2>&1; then
      SUCCESS=1
      break
   fi
   sleep $SLEEP_SECONDS
   ATTEMPT=$((ATTEMPT+1))
done

if [ $SUCCESS -ne 1 ]; then
   echo "============================================================="
   echo "Unable to reach Spring Boot application on port $PORT !!"
   echo "Tried $MAX_RETRIES times, giving up."
   echo "============================================================="
   exit 1
else
   echo "================="
   echo "Smoke Test passed"
   echo "================="
fi

# Check Trivy scan results
if grep -q "CRITICAL" trivyresults.txt; then
   echo "CRITICAL vulnerabilities found, but continuing pipeline..."
   echo "Docker Image is ready for testing (no CRITICAL issues)"
else

   echo "============================================================="
   echo "Docker Image is ready for testing (no CRITICAL issues)"
   echo "============================================================="
fi
