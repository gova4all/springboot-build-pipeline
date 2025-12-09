#!/bin/bash

PORT=$1

if [ -z "$PORT" ]; then
   echo "ERROR: Port argument missing!"
   echo "Usage: ./check.sh <PORT>"
   exit 1
fi

echo "Checking application on port: $PORT"

# Try to reach the application
curl -is --max-redirs 10 http://localhost:$PORT -L | grep -w "HTTP/1.1 200" > /dev/null
if [ $? -ne 0 ]; then
   echo "============================================================="
   echo "Unable to reach Spring Boot application on port $PORT !!"
   echo "============================================================="
   exit 1
else
   echo "================="
   echo "Smoke Test passed"
   echo "================="
fi

# Check Trivy scan results
if grep -q "CRITICAL" trivyresults.txt; then
   echo "============================================================="
   echo "Docker Image has CRITICAL vulnerabilit
