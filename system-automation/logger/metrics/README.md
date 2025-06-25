# Running Bash Scripts as Systemd Services

This README explains how to run any bash script as a systemd service daemon on Linux systems.

## Prerequisites

- Linux system with systemd
- Bash script you want to run as a service
- Root or sudo privileges for service installation

## Installation Steps

### 1. Prepare Your Script

Ensure your bash script is executable and located in a permanent directory:

```bash
# Make script executable
chmod +x /path/to/your/script.sh

# Recommended: Place in system directory
sudo cp your-script.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/your-script.sh
```

**Best practices for script location:**
- `/usr/local/bin/` - For custom user scripts
- `/opt/your-app/` - For application-specific scripts
- `/home/user/scripts/` - For user-specific scripts (not recommended for system services)

### 2. Create Systemd Service File

Create the service configuration file:

```bash
sudo nano /etc/systemd/system/your-service-name.service
```

**Basic service template:**

```ini
[Unit]
Description=Your Service Description
After=network.target

[Service]
Type=simple
ExecStart=/path/to/your/script.sh [arguments]
Restart=always
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
```

**Advanced service template with more options:**

```ini
[Unit]
Description=Your Service Description
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/path/to/your/script.sh [arguments]
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
User=your-user
Group=your-group
WorkingDirectory=/path/to/working/directory
Environment=ENV_VAR=value
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 3. Configure the Service

```bash
# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable your-service-name.service

# Start the service
sudo systemctl start your-service-name.service
```

## Service Management Commands

```bash
# Check service status
sudo systemctl status your-service-name.service

# Start the service
sudo systemctl start your-service-name.service

# Stop the service
sudo systemctl stop your-service-name.service

# Restart the service
sudo systemctl restart your-service-name.service

# Reload service configuration
sudo systemctl reload your-service-name.service

# Enable service to start on boot
sudo systemctl enable your-service-name.service

# Disable service from starting on boot
sudo systemctl disable your-service-name.service

# View service logs (real-time)
sudo journalctl -u your-service-name.service -f

# View service logs (recent)
sudo journalctl -u your-service-name.service --since "1 hour ago"
```

## When to Use Systemd vs Cron

### **Long-running Scripts (Recommended: Systemd)**
Use systemd for scripts that run continuously:
- Monitoring scripts with `while true` loops
- Daemon processes
- Services that need automatic restart on failure
- Scripts requiring complex dependency management

**Example:** CPU/memory monitoring, log watchers, API servers

### **Oneshot Scripts (Alternative: Cron)**
For simple periodic tasks, **cron might be simpler** than systemd:

**Systemd approach (more complex):**
```ini
# my-script.service
[Unit]
Description=My Periodic Task
[Service]
Type=oneshot
ExecStart=/usr/local/bin/my-script.sh

# my-script.timer  
[Unit]
Description=Run My Script Every 5 Minutes
[Timer]
OnCalendar=*:0/5
[Install]
WantedBy=timers.target
```

**Cron approach (simpler):**
```bash
# Edit crontab: crontab -e
# Run every 5 minutes
*/5 * * * * /usr/local/bin/my-script.sh "namespace" "/dev/root"

# Run every hour
0 * * * * /usr/local/bin/backup-script.sh

# Run daily at 2 AM
0 2 * * * /usr/local/bin/cleanup-script.sh
```

### **When to Choose Cron:**
- ✅ Simple periodic execution (minimum 1 minute intervals)
- ✅ Script runs quickly and exits
- ✅ No complex dependencies
- ✅ Standard scheduling patterns
- ✅ Easier to configure and understand

### **When to Choose Systemd:**
- ✅ Sub-minute intervals (seconds-level precision)
- ✅ Complex dependency management
- ✅ Need detailed logging and monitoring
- ✅ Integration with other systemd services
- ✅ Advanced restart policies
- ✅ Resource management (CPU/memory limits)

**Recommendation:** For simple oneshot scripts like disk usage monitoring that run every few minutes, **cron is often the better choice** due to its simplicity.

## Configuration Options Explained

### [Unit] Section
- **Description**: Brief description of the service
- **After**: Services/targets this service should start after
- **Before**: Services/targets this service should start before
- **Wants**: Weak dependency (service continues if dependency fails)
- **Requires**: Strong dependency (service fails if dependency fails)

### [Service] Section
- **Type**: Service startup type
  - `simple`: Service runs in foreground (default)
  - `forking`: Service forks to background
  - `oneshot`: Service runs once and exits
  - `notify`: Service sends notification when ready
- **ExecStart**: Command to start the service
- **ExecStop**: Command to stop the service (optional)
- **ExecReload**: Command to reload the service (optional)
- **Restart**: When to restart the service
  - `always`: Always restart
  - `on-failure`: Restart only on failure
  - `no`: Never restart
- **RestartSec**: Seconds to wait before restarting (NOT a scheduling interval - only applies when service fails/crashes)
- **User/Group**: User and group to run the service as
- **WorkingDirectory**: Working directory for the service
- **Environment**: Environment variables
- **StandardOutput/StandardError**: Where to send output (journal, syslog, null)

### [Install] Section
- **WantedBy**: Target that should include this service
  - `multi-user.target`: Normal system operation
  - `graphical.target`: Graphical system operation

## Script Requirements

For your bash script to work well as a systemd service:

### Long-running Scripts
```bash
#!/bin/bash
# For continuous monitoring/daemon scripts
while true; do
    # Your logic here
    sleep 10
done
```

### One-time Scripts
```bash
#!/bin/bash
# For scripts that run once and exit
# Use Type=oneshot in service file
# Your logic here
exit 0
```

### Signal Handling (Recommended)
```bash
#!/bin/bash
# Handle shutdown signals gracefully
cleanup() {
    echo "Shutting down..."
    # Cleanup logic here
    exit 0
}

trap cleanup SIGTERM SIGINT

# Your main logic here
while true; do
    # Work
    sleep 1
done
```

## Common Use Cases and Examples

### Example 1: Log Monitor
```ini
[Unit]
Description=Log File Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/log-monitor.sh /var/log/app.log
Restart=always
RestartSec=10
User=syslog

[Install]
WantedBy=multi-user.target
```

### Example 2: Backup Service
```ini
[Unit]
Description=Daily Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh /data /backup
User=backup
Group=backup

[Install]
WantedBy=multi-user.target
```

### Example 3: API Service
```ini
[Unit]
Description=Custom API Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/api-server.sh --port 8080
Restart=always
RestartSec=5
User=www-data
Group=www-data
Environment=PORT=8080
Environment=LOG_LEVEL=info

[Install]
WantedBy=multi-user.target
```

## Troubleshooting

### Service Won't Start
1. **Check script permissions and path**
   ```bash
   ls -la /path/to/your/script.sh
   ```

2. **Verify script syntax**
   ```bash
   bash -n /path/to/your/script.sh
   ```

3. **Test script manually**
   ```bash
   /path/to/your/script.sh [arguments]
   ```

4. **Check service logs**
   ```bash
   sudo journalctl -u your-service-name.service -n 50
   ```

5. **Verify service file syntax**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl status your-service-name.service
   ```

### Common Issues
- **Permission denied**: Check script executable permissions
- **Command not found**: Verify script path in ExecStart
- **Service keeps restarting**: Check script for errors or infinite loops
- **Environment issues**: Set proper environment variables in service file

## Security Considerations

- **Run with minimal privileges**: Use dedicated user instead of root when possible
- **Limit file access**: Use appropriate WorkingDirectory and file permissions
- **Environment isolation**: Set only necessary environment variables
- **Log management**: Configure appropriate log rotation for service output

## Cron vs Systemd Timer Examples

### **Disk Usage Monitoring (Oneshot)**

**Option 1: Cron (Recommended for simplicity)**
```bash
# Edit user crontab
crontab -e

# Add line for every 5 minutes
*/5 * * * * /usr/local/bin/disk-usage.sh "production" "/dev/root" 2>&1 | logger

# Or system-wide cron
sudo vim /etc/cron.d/disk-usage
*/5 * * * * root /usr/local/bin/disk-usage.sh "production" "/dev/root"
```

**Option 2: Systemd Timer (More complex but more features)**
```ini
# /etc/systemd/system/disk-usage.service
[Unit]
Description=Disk Usage Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/disk-usage.sh "production" "/dev/root"
User=root

# /etc/systemd/system/disk-usage.timer
[Unit]
Description=Run Disk Usage Monitor every 5 minutes
Requires=disk-usage.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target

# Enable and start timer
sudo systemctl enable disk-usage.timer
sudo systemctl start disk-usage.timer
```

### **CPU Memory Monitoring (Long-running)**

**Only Systemd (Cron not suitable for continuous processes)**
```ini
[Unit]
Description=CPU and Memory Usage Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cpu-mem-usage.sh "production"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Best Practices

1. **Use absolute paths** in ExecStart
2. **Create dedicated users** for services when possible
3. **Handle signals properly** in your scripts
4. **Use descriptive service names** and descriptions
5. **Test thoroughly** before enabling on boot
6. **Monitor logs** regularly for issues
7. **Document dependencies** and configuration requirements
