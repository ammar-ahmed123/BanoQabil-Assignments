#!/bin/bash

#############################################################################
# System Health Monitor v1.1 (Cross-Platform Compatible)
# Interactive terminal-based system monitoring dashboard
#############################################################################

# Configuration
REFRESH_RATE=3
LOG_FILE="system_health_alerts.log"
FILTER_MODE="all"  # all, cpu, memory, disk, network

# Thresholds
CPU_WARNING=50
CPU_CRITICAL=60
MEM_WARNING=60
MEM_CRITICAL=70
DISK_WARNING=50
DISK_CRITICAL=55

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Initialize
LAST_RX=0
LAST_TX=0
LAST_TIME=0
declare -a RECENT_ALERTS=()
MAX_ALERTS=5

#############################################################################
# Utility Functions
#############################################################################

# Cleanup on exit
cleanup() {
    tput cnorm  # Show cursor
    stty echo   # Re-enable echo
    tput sgr0   # Reset terminal
    echo -e "\n${GREEN}System Health Monitor stopped.${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# Initialize terminal
init_terminal() {
    clear
    tput civis  # Hide cursor
    stty -echo  # Disable echo for cleaner input
}

# Log alert to file
log_alert() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    
    # Add to recent alerts array
    RECENT_ALERTS=("$message" "${RECENT_ALERTS[@]}")
    if [ ${#RECENT_ALERTS[@]} -gt $MAX_ALERTS ]; then
        RECENT_ALERTS=("${RECENT_ALERTS[@]:0:$MAX_ALERTS}")
    fi
}

# Create progress bar
create_bar() {
    local percentage=$1
    local width=40
    local filled=$((percentage * width / 100))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    echo "$bar"
}

# Get status color and label
get_status() {
    local value=$1
    local warning=$2
    local critical=$3
    local type=$4
    
    if [ $value -ge $critical ]; then
        echo -e "${RED}[CRITICAL]${NC}"
        log_alert "$type usage is CRITICAL: ${value}%"
        return 2
    elif [ $value -ge $warning ]; then
        echo -e "${YELLOW}[WARNING]${NC}"
        return 1
    else
        echo -e "${GREEN}[OK]${NC}"
        return 0
    fi
}

#############################################################################
# System Metric Functions
#############################################################################

# Get CPU usage - Cross-platform version
get_cpu_usage() {
    # Try multiple methods to get CPU usage
    local cpu_usage=""
    
    # Method 1: Using top (BSD style - macOS)
    if command -v top &> /dev/null; then
        cpu_usage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
        if [ -n "$cpu_usage" ]; then
            printf "%.0f" "$cpu_usage" 2>/dev/null && return
        fi
    fi
    
    # Method 2: Using /proc/stat (Linux)
    if [ -f /proc/stat ]; then
        cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')
        if [ -n "$cpu_usage" ] && [ "$cpu_usage" != "0" ]; then
            echo "$cpu_usage"
            return
        fi
    fi
    
    # Method 3: Using ps (cross-platform fallback)
    if command -v ps &> /dev/null; then
        # Get CPU% from ps and sum up (rough estimate)
        cpu_usage=$(ps aux 2>/dev/null | awk 'NR>1 {sum+=$3} END {printf "%.0f", sum}')
        if [ -n "$cpu_usage" ]; then
            # Cap at 100%
            [ "$cpu_usage" -gt 100 ] && cpu_usage=100
            echo "$cpu_usage"
            return
        fi
    fi
    
    # Default fallback
    echo "0"
}

# Get top CPU processes - Cross-platform
get_top_processes() {
    if command -v ps &> /dev/null; then
        # Try BSD-style first (macOS, some Unix)
        local output=$(ps aux 2>/dev/null | awk 'NR>1 {printf "  %-20s (%.1f%%)\n", $11, $3}' | sort -t'(' -k2 -rn | head -3 | tr '\n' ',' | sed 's/,$//')
        
        if [ -z "$output" ]; then
            # Try simpler format
            output=$(ps -eo comm,pcpu 2>/dev/null | awk 'NR>1 {printf "  %-20s (%.1f%%)\n", $1, $2}' | sort -t'(' -k2 -rn | head -3 | tr '\n' ',' | sed 's/,$//')
        fi
        
        if [ -n "$output" ]; then
            echo "$output"
        else
            echo "  No process data available"
        fi
    else
        echo "  ps command not available"
    fi
}

# Get memory usage - Cross-platform
get_memory_info() {
    local percentage=0
    local used=0
    local total=0
    local free=0
    local cache=0
    local buffers=0
    
    # Method 1: Linux /proc/meminfo
    if [ -f /proc/meminfo ]; then
        total=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
        free=$(grep MemFree /proc/meminfo | awk '{print int($2/1024)}')
        available=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
        buffers=$(grep ^Buffers /proc/meminfo | awk '{print int($2/1024)}')
        cached=$(grep ^Cached /proc/meminfo | awk '{print int($2/1024)}')
        
        if [ -n "$available" ] && [ "$available" != "0" ]; then
            used=$((total - available))
            cache=$cached
        else
            used=$((total - free - buffers - cached))
            cache=$cached
        fi
        
        if [ "$total" -gt 0 ]; then
            percentage=$((used * 100 / total))
        fi
        
        echo "$percentage|$used|$total|$free|$cache|$buffers"
        return
    fi
    
    # Method 2: free command (Linux)
    if command -v free &> /dev/null; then
        local mem_info=$(free -m 2>/dev/null | grep Mem:)
        if [ -n "$mem_info" ]; then
            total=$(echo $mem_info | awk '{print $2}')
            used=$(echo $mem_info | awk '{print $3}')
            free=$(echo $mem_info | awk '{print $4}')
            cache=$(echo $mem_info | awk '{print $6}')
            buffers=$(echo $mem_info | awk '{print $5}')
            
            if [ "$total" -gt 0 ]; then
                percentage=$((used * 100 / total))
            fi
            
            echo "$percentage|$used|$total|$free|$cache|$buffers"
            return
        fi
    fi
    
    # Method 3: vm_stat (macOS)
    if command -v vm_stat &> /dev/null; then
        local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
        local pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        local pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        local pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
        local pages_wired=$(vm_stat | grep "Pages wired" | awk '{print $4}' | sed 's/\.//')
        
        total=$(sysctl hw.memsize | awk '{print int($2/1024/1024)}')
        free=$((pages_free * page_size / 1024 / 1024))
        used=$(( (pages_active + pages_inactive + pages_wired) * page_size / 1024 / 1024 ))
        
        if [ "$total" -gt 0 ]; then
            percentage=$((used * 100 / total))
        fi
        
        echo "$percentage|$used|$total|$free|0|0"
        return
    fi
    
    # Fallback
    echo "0|0|1024|1024|0|0"
}

# Get disk usage
get_disk_usage() {
    if command -v df &> /dev/null; then
        df -h 2>/dev/null | grep -E '^/dev/|^[A-Z]:' | awk '{
            gsub(/%/, "", $5);
            if ($5 ~ /^[0-9]+$/) {
                printf "%s|%s|%s|%d\n", $6, $5, $4, $5
            }
        }'
    else
        echo "/|0|0|0"
    fi
}

# Get network statistics
get_network_stats() {
    local interface=""
    local rx_bytes=0
    local tx_bytes=0
    
    # Try to find the active network interface
    if command -v ip &> /dev/null; then
        interface=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
    elif command -v netstat &> /dev/null; then
        interface=$(netstat -rn 2>/dev/null | grep default | awk '{print $NF}' | head -1)
    fi
    
    # Default to common interface names if not found
    [ -z "$interface" ] && interface="eth0"
    
    # Try to get network stats
    if [ -e "/sys/class/net/$interface/statistics/rx_bytes" ]; then
        rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo "0")
        tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo "0")
    fi
    
    local current_time=$(date +%s)
    
    if [ $LAST_TIME -eq 0 ]; then
        LAST_RX=$rx_bytes
        LAST_TX=$tx_bytes
        LAST_TIME=$current_time
        echo "0|0|$interface"
        return
    fi
    
    local time_diff=$((current_time - LAST_TIME))
    if [ $time_diff -eq 0 ]; then
        echo "0|0|$interface"
        return
    fi
    
    local rx_rate=$(( (rx_bytes - LAST_RX) / time_diff ))
    local tx_rate=$(( (tx_bytes - LAST_TX) / time_diff ))
    
    LAST_RX=$rx_bytes
    LAST_TX=$tx_bytes
    LAST_TIME=$current_time
    
    echo "$rx_rate|$tx_rate|$interface"
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -gt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}") MB/s"
    elif [ $bytes -gt 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024}") KB/s"
    else
        echo "$bytes B/s"
    fi
}

# Get system uptime
get_uptime() {
    if command -v uptime &> /dev/null; then
        uptime -p 2>/dev/null | sed 's/up //' || uptime | awk -F'( |,|:)+' '{print $6" "$7}'
    elif [ -f /proc/uptime ]; then
        local uptime_sec=$(cat /proc/uptime | awk '{print int($1)}')
        local days=$((uptime_sec / 86400))
        local hours=$(( (uptime_sec % 86400) / 3600 ))
        local mins=$(( (uptime_sec % 3600) / 60 ))
        echo "${days}d ${hours}h ${mins}m"
    else
        echo "unknown"
    fi
}

# Get load average
get_load_average() {
    if command -v uptime &> /dev/null; then
        uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs
    elif [ -f /proc/loadavg ]; then
        cat /proc/loadavg | awk '{print $1", "$2", "$3}'
    else
        echo "N/A"
    fi
}

#############################################################################
# Display Functions
#############################################################################

display_header() {
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    local date=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    printf "║         ${BOLD}SYSTEM HEALTH MONITOR v1.1${NC}${CYAN}                              ║${NC}  ${YELLOW}[R]${NC}efresh: ${REFRESH_RATE}s\n"
    printf "║ ${NC}Hostname: %-20s Date: %-19s${CYAN} ║${NC}  ${YELLOW}[F]${NC}ilter: $FILTER_MODE\n" "$hostname" "$date"
    printf "║ ${NC}Uptime: %-53s${CYAN} ║${NC}  ${YELLOW}[H]${NC}elp ${YELLOW}[Q]${NC}uit\n" "$(get_uptime)"
    echo -e "╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

display_cpu() {
    if [ "$FILTER_MODE" != "all" ] && [ "$FILTER_MODE" != "cpu" ]; then
        return
    fi
    
    local cpu_usage=$(get_cpu_usage)
    local bar=$(create_bar $cpu_usage)
    local status=$(get_status $cpu_usage $CPU_WARNING $CPU_CRITICAL "CPU")
    
    echo -e "${BOLD}CPU USAGE:${NC} ${cpu_usage}% ${bar} ${status}"
    echo -e "$(get_top_processes)"
    echo
}

display_memory() {
    if [ "$FILTER_MODE" != "all" ] && [ "$FILTER_MODE" != "memory" ]; then
        return
    fi
    
    local mem_data=$(get_memory_info)
    IFS='|' read -r percentage used total free cache buffers <<< "$mem_data"
    
    local bar=$(create_bar $percentage)
    local status=$(get_status $percentage $MEM_WARNING $MEM_CRITICAL "Memory")
    
    echo -e "${BOLD}MEMORY:${NC} ${used}MB/${total}MB (${percentage}%) ${bar} ${status}"
    echo -e "  Free: ${free}MB | Cache: ${cache}MB | Buffers: ${buffers}MB"
    echo
}

display_disk() {
    if [ "$FILTER_MODE" != "all" ] && [ "$FILTER_MODE" != "disk" ]; then
        return
    fi
    
    echo -e "${BOLD}DISK USAGE:${NC}"
    
    local disk_output=$(get_disk_usage)
    if [ -z "$disk_output" ]; then
        echo "  No disk information available"
    else
        while IFS='|' read -r mount_point percentage available usage_num; do
            local bar=$(create_bar $usage_num)
            local status=$(get_status $usage_num $DISK_WARNING $DISK_CRITICAL "Disk $mount_point")
            
            printf "  %-10s: %3d%% %s %s\n" "$mount_point" "$usage_num" "$bar" "$status"
        done <<< "$disk_output"
    fi
    echo
}

display_network() {
    if [ "$FILTER_MODE" != "all" ] && [ "$FILTER_MODE" != "network" ]; then
        return
    fi
    
    local net_data=$(get_network_stats)
    IFS='|' read -r rx_rate tx_rate interface <<< "$net_data"
    
    local rx_formatted=$(format_bytes $rx_rate)
    local tx_formatted=$(format_bytes $tx_rate)
    
    # Calculate percentage for visualization (assuming 100MB/s as max)
    local rx_percent=$((rx_rate * 100 / 104857600))
    local tx_percent=$((tx_rate * 100 / 104857600))
    [ $rx_percent -gt 100 ] && rx_percent=100
    [ $tx_percent -gt 100 ] && tx_percent=100
    
    local rx_bar=$(create_bar $rx_percent)
    local tx_bar=$(create_bar $tx_percent)
    
    echo -e "${BOLD}NETWORK:${NC} Interface: ${interface}"
    printf "  ${GREEN}Download${NC}: %-12s %s ${GREEN}[OK]${NC}\n" "$rx_formatted" "$rx_bar"
    printf "  ${BLUE}Upload${NC}  : %-12s %s ${GREEN}[OK]${NC}\n" "$tx_formatted" "$tx_bar"
    echo
}

display_load() {
    echo -e "${BOLD}LOAD AVERAGE:${NC} $(get_load_average)"
    echo
}

display_alerts() {
    echo -e "${BOLD}${RED}RECENT ALERTS:${NC}"
    
    if [ ${#RECENT_ALERTS[@]} -eq 0 ]; then
        echo -e "  ${GREEN}No recent alerts${NC}"
    else
        local count=0
        for alert in "${RECENT_ALERTS[@]}"; do
            local timestamp=$(date '+%H:%M:%S')
            echo -e "  ${YELLOW}[$timestamp]${NC} $alert"
            count=$((count + 1))
            [ $count -ge $MAX_ALERTS ] && break
        done
    fi
    echo
}

display_help() {
    echo -e "${BOLD}KEYBOARD SHORTCUTS:${NC}"
    echo -e "  ${YELLOW}[R]${NC} - Change refresh rate (1-60 seconds)"
    echo -e "  ${YELLOW}[F]${NC} - Filter view (all/cpu/memory/disk/network)"
    echo -e "  ${YELLOW}[H]${NC} - Show this help"
    echo -e "  ${YELLOW}[Q]${NC} - Quit the monitor"
    echo
}

display_footer() {
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Press ${YELLOW}'h'${NC} for help, ${YELLOW}'q'${NC} to quit"
}

#############################################################################
# Main Dashboard
#############################################################################

display_dashboard() {
    clear
    display_header
    display_cpu
    display_memory
    display_disk
    display_network
    display_load
    display_alerts
    display_footer
}

#############################################################################
# Input Handling
#############################################################################

handle_input() {
    local key
    
    # Read key with timeout
    read -t 0.1 -n 1 key 2>/dev/null
    
    case "$key" in
        q|Q)
            cleanup
            ;;
        r|R)
            tput cnorm
            stty echo
            echo -ne "\n${YELLOW}Enter new refresh rate (1-60 seconds):${NC} "
            read new_rate
            if [[ "$new_rate" =~ ^[0-9]+$ ]] && [ "$new_rate" -ge 1 ] && [ "$new_rate" -le 60 ]; then
                REFRESH_RATE=$new_rate
            else
                echo -e "${RED}Invalid refresh rate. Using current: ${REFRESH_RATE}s${NC}"
                sleep 2
            fi
            tput civis
            stty -echo
            ;;
        f|F)
            case "$FILTER_MODE" in
                all)
                    FILTER_MODE="cpu"
                    ;;
                cpu)
                    FILTER_MODE="memory"
                    ;;
                memory)
                    FILTER_MODE="disk"
                    ;;
                disk)
                    FILTER_MODE="network"
                    ;;
                network)
                    FILTER_MODE="all"
                    ;;
            esac
            ;;
        h|H)
            clear
            display_help
            echo -e "${YELLOW}Press any key to continue...${NC}"
            read -n 1 -s
            ;;
    esac
}

#############################################################################
# Main Loop
#############################################################################

main() {
    # Initialize
    init_terminal
    
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    
    echo -e "${GREEN}Starting System Health Monitor v1.1...${NC}"
    echo -e "Cross-platform compatible version"
    echo -e "Log file: ${CYAN}$LOG_FILE${NC}"
    sleep 2
    
    # Main monitoring loop
    while true; do
        display_dashboard
        
        # Handle input for the refresh interval
        local elapsed=0
        while [ $elapsed -lt $REFRESH_RATE ]; do
            handle_input
            sleep 0.1
            elapsed=$(awk "BEGIN {print $elapsed + 0.1}")
        done
    done
}

# Run the monitor
main
