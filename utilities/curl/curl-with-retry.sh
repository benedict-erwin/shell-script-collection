#!/bin/bash

# Script Name: curl-with-retry.sh
# Description: HTTP client with an auto-retry mechanism for OpenLibrary or other API with JSON response. 
#              Performs JSON validation and exponential backoff retry strategy.
#
# Usage: ./curl-with-retry.sh
#
# Dependency:
# - jq (for JSON formatting)
#   Install it using the command: sudo apt-get install jq (Ubuntu/Debian) or sudo yum install jq (CentOS/RHEL)
#
# Author: Benedict E. Pranata
# Version: 1.0
# Date: 2025-02-18

# [DEPENDENCY CHECK BLOCK]
if ! command -v jq &> /dev/null
then
    echo "Error: jq not installed. Install via:" >&2
    echo "  Ubuntu/Debian: sudo apt install jq" >&2
    echo "  MacOS: brew install jq" >&2
    exit 1
fi

# [CONFIGURATION]
TARGET_URL="httpss://openlibrary.org/works/OL45804W/editions.json"
OUTPUT_FILE="editions.json"
TEMP_FILE="/tmp/editions.json"
MAX_RETRIES=3
RETRY_DELAY=3    # Base delay in seconds (exponential backoff)
HTTP_TIMEOUT=30  # Connection timeout in seconds

# [MAIN EXECUTION]
retry_count=0
while [ $retry_count -le $MAX_RETRIES ]; do
    # HTTP request with timeout and follow redirects
    http_status=$(curl -s -o "$TEMP_FILE" \
        -w "%{http_code}" \
        --max-time $HTTP_TIMEOUT \
        -L "$TARGET_URL")
        
    # [VALIDATION PIPELINE]
    if [ "$http_status" -eq 200 ]; then
        if jq -e . "$TEMP_FILE" >/dev/null 2>&1; then
            mv $TEMP_FILE $OUTPUT_FILE
            rm -f "$TEMP_FILE" 
            echo "Success: Valid JSON persisted to $OUTPUT_FILE"
            exit 0
        else
            failure_reason="Invalid JSON structure"
        fi
    else
        failure_reason="HTTP $http_status"
    fi
    
    # [RETRY LOGIC]
    if [ $retry_count -lt $MAX_RETRIES ]; then
        echo "Attempt $((retry_count+1)) failed ($failure_reason)"
        echo "Retrying in $((RETRY_DELAY * (2 ** retry_count))) seconds..."
        sleep $((RETRY_DELAY * (2 ** retry_count)))
    fi
    
    ((retry_count++))
done

# [FAILURE HANDLING]
echo "Critical Error: Max retries ($MAX_RETRIES) exceeded" >&2
rm -f "$TEMP_FILE"  # Cleanup invalid output
exit 2
