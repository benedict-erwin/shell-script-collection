#!/bin/bash

# Script Name: disk-usage.sh
# Description: A script to export disk usage in JSON format.
#              This script requires the `jq` tool for formatting the output to JSON.
#              Useful for system monitoring, logging, or integration with other tools.
#
# Usage: ./disk-usage.sh "your-namespace" "/dev/root"
#
# Dependency:
# - jq (for JSON formatting)
#   Install it using the command: sudo apt-get install jq (Ubuntu/Debian) or sudo yum install jq (CentOS/RHEL)
#
# Output Format:
# {
#     "time": "2024-10-03T08:07:01.672543199Z",
#     "level": "INFO",
#     "msg": "disk usage information",
#     "namespace": "YOUR-NAMESPACE",
#     "data": [
#         {
#             "mount": "/dev/root",
#             "size": "20134592",
#             "used": "13884796",
#             "avail": "6233412",
#             "use": "70%"
#         },
#         {
#             "mount": "/dev/nvme0n1p15",
#             "size": "106858",
#             "used": "6186",
#             "avail": "100673",
#             "use": "6%"
#         }
#     ],
#     "selected_disk": {
#         "mount": "/dev/root",
#         "size": "20134592",
#         "used": "13884796",
#         "avail": "6233412",
#         "use": 70
#     }
# }
#
# Author: Benedict E. Pranata
# Version: 1.0
# Date: 2024-10-03

# Get label from param
label="DISK-USAGE-INFO"
ns=$1
sl=$2

# Get the current timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")

# Execute the df command and process the output with jq
disk_usage=$(df -P | jq -c -R -s '
    [
      split("\n") |
      .[] |
      if test("^/") then
        gsub(" +"; " ") | split(" ") | {mount: .[0], size: .[1], used: .[2], avail: .[3], use: .[4]}      
      else
        empty
      end
    ]')

# Extract root_usage specifically for /dev/root from the existing disk_usage
root_usage=$(echo "$disk_usage" | jq -c --arg mount "$sl" '
    .[] | 
    select(.mount == $mount) | 
    { 
        mount: .mount, 
        size: .size, 
        used: .used, 
        avail: .avail, 
        use: (.use | sub("%"; "") | tonumber)  # Remove % and convert to number
    }')

# Check if root_usage is empty and format it as JSON if not found
if [[ -z "$root_usage" ]]; then
    root_usage='{}'  # Set to an empty JSON object if not found
else
    root_usage=$(echo "$root_usage" | jq -c .)  # Ensure it's valid JSON
fi

# Format the final JSON output
json_output=$(jq -c -n \
  --arg time "$timestamp" \
  --arg level "INFO" \
  --arg msg "disk usage information" \
  --arg namespace "${ns^^}" \
  --argjson data "$disk_usage" \
  --argjson root_usage "$root_usage" \
  '{
    time: $time,
    level: $level,
    msg: $msg,
    namespace: $namespace,
    data: $data,
    selected_disk: $root_usage
  }')

# Write the JSON output to syslog
logger -t "${label,,}" "$json_output"
