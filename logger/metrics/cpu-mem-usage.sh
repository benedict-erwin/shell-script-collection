#!/bin/bash

# Script Name: cpu-mem-usage.sh
# Description: A script to export CPU & Memory usage, uptime, TOP result for 10 CPU & Memory in JSON format.
#              This script requires the `jq` tool for formatting the output to JSON.
#              Useful for system monitoring, logging, or integration with other tools.
#
# Usage: ./cpu-mem-usage.sh "your-namespace"
#
# Dependency:
# - jq (for JSON formatting)
#   Install it using the command: sudo apt-get install jq (Ubuntu/Debian) or sudo yum install jq (CentOS/RHEL)
#
# Output Format:
# {
#     "time": "2024-10-03T07:10:20.825694600Z",
#     "level": "INFO",
#     "msg": "CPU, Memory, and Uptime usage",
#     "namespace": "YOUR-NAMESPACE",
#     "data": {
#         "cpu": {
#             "user": "16.1",
#             "system": "1.6",
#             "idle": "80.6",
#             "usage_percent": "19.40",
#             "cores": "4"
#         },
#         "memory": {
#             "total": "7645",
#             "used": "563",
#             "free": "998",
#             "usage_percent": "7.36"
#         },
#         "uptime": "17 days,  3:20",
#         "top_cpu": [
#             "/usr/sbin/serve [daemon]",
#             "/lib/systemd/systemd-journa [0.6]",
#             "/lib/systemd/systemd-resolv [0.6]",
#             "/usr/sbin/rsyslogd [-n]",
#             "htop [0.2]",
#             "tmux [new]",
#             "journalctl [-u]",
#             "/lib/systemd/systemd [--syst]",
#             "[kthreadd] [0.0]",
#             "[pool_workqueue_release] [0.0]"
#         ],
#         "top_mem": [
#             "/lib/systemd/systemd-journa [4.0]",
#             "/usr/sbin/serve [daemon]",
#             "journalctl [-u]",
#             "/usr/lib/snapd/snapd [0.3]",
#             "/sbin/multipathd [-d]",
#             "/usr/sbin/serve [daemon]",
#             "/snap/amazon-ssm-agent/1234 [0.2]",
#             "asynqmon [--redis-addr=localhost]",
#             "/usr/bin/python3 [/usr/bin/n]",
#             "/usr/bin/python3 [/usr/share]"
#         ]
#     }
# }
#
# Author: Benedict E. Pranata
# Version: 1.0
# Date: 2024-10-03


# Get ns from param
ns=$1

# Set locale to ensure decimal numbers use a dot (.) instead of a comma (,)
export LC_NUMERIC="en_US.UTF-8"

while true; do

  # Get the current timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")

  # Run top once and capture its output
  top_output=$(top -bn1)

  # Collect CPU usage data
  cpu_user=$(echo "$top_output" | grep "Cpu(s)" | awk '{print $2}')
  cpu_system=$(echo "$top_output" | grep "Cpu(s)" | awk '{print $4}')
  cpu_idle=$(echo "$top_output" | grep "Cpu(s)" | awk '{print $8}')

  # Check if cpu_idle is correctly extracted
  if [[ -z "$cpu_idle" || "$cpu_idle" == "id," ]]; then
    cpu_idle=100
  fi

  # Calculate total CPU usage percentage (100% minus idle time)
  cpu_usage_percent=$(awk -v id="$cpu_idle" 'BEGIN {printf "%.2f", 100 - id}')

  # Get the number of CPU cores using nproc
  cpu_core_count=$(nproc)

  # Create JSON for CPU usage, including core count
  cpu_usage=$(jq -n --arg user "$cpu_user" --arg system "$cpu_system" --arg idle "$cpu_idle" --arg usage_percent "$cpu_usage_percent" --arg cores "$cpu_core_count" \
    '{user: $user, system: $system, idle: $idle, usage_percent: $usage_percent, cores: $cores}')

  # Collect memory usage data using top output
  mem_total=$(echo "$top_output" | grep "Mem:" | awk '{print $2}')
  mem_used=$(echo "$top_output" | grep "Mem:" | awk '{print $3}')
  mem_free=$(echo "$top_output" | grep "Mem:" | awk '{print $4}')

  # If the above extraction fails, we can fall back to using free command
  if [ -z "$mem_total" ] || [ -z "$mem_used" ]; then
      mem_info=$(free -m)
      mem_total=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
      mem_used=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
      mem_free=$(echo "$mem_info" | grep "Mem:" | awk '{print $4}')
  fi

  mem_usage_percent=$(awk "BEGIN {printf \"%.2f\", ($mem_used/$mem_total)*100}")

  # Create JSON for memory usage
  memory_usage=$(jq -n --arg total "$mem_total" --arg used "$mem_used" --arg free "$mem_free" --arg usage_percent "$mem_usage_percent" \
    '{total: $total, used: $used, free: $free, usage_percent: $usage_percent}')

  # Extract uptime from the top output (adjust the pattern for robustness)
  uptime=$(echo "$top_output" | grep -oP "up\s+\K.*?(?=,\s+\d+\s+user)")

  # Extract top 10 process with high CPU usage
  top_cpu_processes=$(ps -eo cmd,%cpu --sort=-%cpu | head -n 11 | tail -n 10 | awk '{print $1 " [" $2 "]"}' | jq -R -s -c 'split("\n")[:-1]')

  # Extract top 10 process with high Memory usage
  top_mem_processes=$(ps -eo cmd,%mem --sort=-%mem | head -n 11 | tail -n 10 | awk '{print $1 " [" $2 "]"}' | jq -R -s -c 'split("\n")[:-1]')

  # Format the final JSON output including CPU, memory, and uptime
  json_output=$(jq -c -n \
    --arg time "$timestamp" \
    --arg level "INFO" \
    --arg msg "CPU, Memory, and Uptime usage" \
    --arg namespace "${ns^^}" \
    --argjson cpu "$cpu_usage" \
    --argjson memory "$memory_usage" \
    --arg uptime "$uptime" \
    --argjson top_cpu "$top_cpu_processes" \
    --argjson top_mem "$top_mem_processes" \
    '{
      time: $time,
      level: $level,
      msg: $msg,
      namespace: $namespace,
      data: {
        cpu: $cpu,
        memory: $memory,
        uptime: $uptime,
        top_cpu: $top_cpu,
        top_mem: $top_mem,
      }
    }')

  # Run in systemd so no need to use logger
  echo "$json_output"

  # Sleep for 10 seconds before the next iteration
  sleep 10
done