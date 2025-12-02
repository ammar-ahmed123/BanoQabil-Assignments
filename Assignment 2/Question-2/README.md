![system health monitor ss](https://github.com/user-attachments/assets/59b5abd4-f600-49b4-881e-97688d1df638)


# System Health Monitor v1.0

An interactive, real-time system health monitoring dashboard for Linux systems.

## Features

### 📊 Real-Time Monitoring
- **CPU Usage**: Overall percentage with top consuming processes
- **Memory**: RAM usage with free, cache, and buffer breakdown
- **Disk Usage**: All mounted filesystems with usage percentages
- **Network**: Real-time incoming/outgoing traffic rates
- **Load Average**: System load over 1, 5, and 15 minutes

### 🎨 Visual Elements
- **Progress Bars**: ASCII bar graphs (40 characters wide) for all metrics
- **Color Coding**: 
  - 🟢 **Green (OK)**: Usage below warning threshold
  - 🟡 **Yellow (WARNING)**: Usage between warning and critical
  - 🔴 **Red (CRITICAL)**: Usage above critical threshold
- **Box Drawing**: Unicode characters for clean dashboard borders

### ⚠️ Alert System
- Automatic anomaly detection for:
  - CPU spikes above 85%
  - Memory pressure above 90%
  - Disk filling up (>75%)
- Alerts logged to `system_health_alerts.log`
- Recent alerts displayed in dashboard (last 5)

### ⌨️ Keyboard Controls
- **[R]** - Change refresh rate (1-60 seconds)
- **[F]** - Filter view (cycle through: all → cpu → memory → disk → network → all)
- **[H]** - Show help screen
- **[Q]** - Quit the monitor

## Installation

```bash
# Download the script
chmod +x system_health_monitor.sh

# Run the monitor
./system_health_monitor.sh
```

## Usage

### Basic Usage
```bash
./system_health_monitor.sh
```

The dashboard will start with a 3-second refresh rate showing all metrics.

### Keyboard Shortcuts

**Change Refresh Rate:**
1. Press `R` or `r`
2. Enter a number between 1-60 seconds
3. Dashboard will update at the new rate

**Filter Information:**
- Press `F` or `f` to cycle through different views:
  - `all` - Show all metrics (default)
  - `cpu` - Show only CPU usage
  - `memory` - Show only memory usage
  - `disk` - Show only disk usage
  - `network` - Show only network traffic

**View Help:**
- Press `H` or `h` to see the help screen
- Press any key to return to the dashboard

**Exit:**
- Press `Q` or `q` to cleanly exit the monitor

## Configuration

Edit the following variables at the top of the script to customize thresholds:

```bash
# Refresh rate (seconds)
REFRESH_RATE=3

# Alert thresholds (percentage)
CPU_WARNING=70
CPU_CRITICAL=85

MEM_WARNING=75
MEM_CRITICAL=90

DISK_WARNING=75
DISK_CRITICAL=90

# Log file location
LOG_FILE="system_health_alerts.log"

# Maximum alerts to display
MAX_ALERTS=5
```

## Alert Log Format

Alerts are logged to `system_health_alerts.log` in the following format:

```
[2025-12-02 14:25:12] CPU usage is CRITICAL: 87%
[2025-12-02 14:02:37] Memory usage is WARNING: 78%
[2025-12-02 13:46:15] Disk /var/log usage is WARNING: 76%
```

## Requirements

- Linux operating system (Ubuntu, Debian, CentOS, etc.)
- Bash shell (version 4.0+)
- Standard Linux utilities:
  - `top` or `ps` - Process monitoring
  - `free` - Memory information
  - `df` - Disk usage
  - `/sys/class/net` - Network statistics
  - `uptime` - System uptime and load

## Troubleshooting

### Script doesn't show network stats
The script automatically detects your active network interface. If it fails:
1. Check available interfaces: `ip link show`
2. Edit the script and set `interface="your_interface"` (e.g., `eth0`, `ens33`, `wlan0`)

### Permission denied errors
Some metrics may require elevated privileges:
```bash
sudo ./system_health_monitor.sh
```

### Terminal display issues
Ensure your terminal supports:
- ANSI color codes
- Unicode box-drawing characters
- Minimum 80 columns width

### CPU usage shows 0%
If `top` command format differs on your system, the script uses `/proc/stat` as a fallback.

## Examples

### Example Output (Normal)
```
╔════════════════════════════════════════════════════════════════════╗
║         SYSTEM HEALTH MONITOR v1.0                              ║  [R]efresh: 3s
║ Hostname: webserver-prod1      Date: 2025-12-02 15:30:45       ║  [F]ilter: all
║ Uptime: 43 days, 7 hours, 13 minutes                           ║  [H]elp [Q]uit
╚════════════════════════════════════════════════════════════════════╝

CPU USAGE: 45% ██████████████████░░░░░░░░░░░░░░░░░░░░░░ [OK]
  Process: nginx (8%), mysqld (6%), python (5%)

MEMORY: 4.2GB/8GB (53%) █████████████████████░░░░░░░░░░░░░░░░░░░ [OK]
  Free: 3.8GB | Cache: 1.5GB | Buffers: 0.3GB

DISK USAGE:
  /        : 42% █████████████████░░░░░░░░░░░░░░░░░░░░░ [OK]
  /home    : 28% ███████████░░░░░░░░░░░░░░░░░░░░░░░░░░ [OK]

NETWORK:
  eth0 (in)  : 5.3 MB/s  ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [OK]
  eth0 (out) : 2.1 MB/s  █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ [OK]

LOAD AVERAGE: 1.23, 1.15, 1.08

RECENT ALERTS:
  No recent alerts
```

### Example Output (Under Load)
```
CPU USAGE: 87% ███████████████████████████████████░░░░░ [CRITICAL]
  Process: mongod (35%), nginx (22%), node (18%)

MEMORY: 7.2GB/8GB (90%) ████████████████████████████████████░░░░ [CRITICAL]
  Free: 0.8GB | Cache: 2.1GB | Buffers: 0.2GB

DISK USAGE:
  /        : 89% ████████████████████████████████████░░░ [CRITICAL]

RECENT ALERTS:
  [15:32:18] CPU usage is CRITICAL: 87%
  [15:31:45] Memory usage is CRITICAL: 90%
  [15:30:12] Disk / usage is CRITICAL: 89%
```

## License

This script is provided as-is for system monitoring purposes. Feel free to modify and distribute.

## Support

For issues or feature requests, check:
- Terminal compatibility
- Script permissions
- System utility availability

## Version History

- **v1.0** (2025-12-02)
  - Initial release
  - Real-time monitoring dashboard
  - Color-coded alerts
  - Keyboard controls
  - Anomaly logging
