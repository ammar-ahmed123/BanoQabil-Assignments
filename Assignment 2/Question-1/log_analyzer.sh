#!/bin/bash

# Log File Analyzer Script
# Analyzes log files for ERROR, WARNING, and INFO messages
# Generates a comprehensive summary report

# Color codes for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 <log_file_path>"
    echo "Example: $0 /var/log/application.log"
    exit 1
}

# Check if log file argument is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No log file specified${NC}"
    usage
fi

LOG_FILE="$1"

# Validate log file exists and is readable
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}Error: File '$LOG_FILE' not found${NC}"
    exit 1
fi

if [ ! -r "$LOG_FILE" ]; then
    echo -e "${RED}Error: File '$LOG_FILE' is not readable${NC}"
    exit 1
fi

# Get file information
FILE_SIZE_BYTES=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null)
if [ "$FILE_SIZE_BYTES" -ge 1048576 ]; then
    FILE_SIZE_MB=$(awk "BEGIN {printf \"%.1f\", $FILE_SIZE_BYTES / 1048576}")
    FILE_SIZE_DISPLAY="${FILE_SIZE_MB}MB"
else
    FILE_SIZE_KB=$(awk "BEGIN {printf \"%.1f\", $FILE_SIZE_BYTES / 1024}")
    FILE_SIZE_DISPLAY="${FILE_SIZE_KB}KB"
fi

ANALYSIS_DATE=$(date '+%a %b %d %H:%M:%S %Z %Y')
REPORT_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="log_analysis_${REPORT_TIMESTAMP}.txt"

# Temporary files for processing
TEMP_DIR=$(mktemp -d)
ERRORS_FILE="${TEMP_DIR}/errors.txt"
WARNINGS_FILE="${TEMP_DIR}/warnings.txt"
INFO_FILE="${TEMP_DIR}/info.txt"
ERROR_MESSAGES_FILE="${TEMP_DIR}/error_messages.txt"
ERROR_TIMESTAMPS_FILE="${TEMP_DIR}/error_timestamps.txt"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Extract messages by type
echo "Analyzing log file..."
grep -i "ERROR" "$LOG_FILE" > "$ERRORS_FILE" 2>/dev/null || true
grep -i "WARNING" "$LOG_FILE" > "$WARNINGS_FILE" 2>/dev/null || true
grep -i "INFO" "$LOG_FILE" > "$INFO_FILE" 2>/dev/null || true

# Count messages
ERROR_COUNT=$(wc -l < "$ERRORS_FILE" | tr -d ' ')
WARNING_COUNT=$(wc -l < "$WARNINGS_FILE" | tr -d ' ')
INFO_COUNT=$(wc -l < "$INFO_FILE" | tr -d ' ')

# Process errors if any exist
if [ "$ERROR_COUNT" -gt 0 ]; then
    # Extract error messages (remove timestamps and ERROR prefix)
    sed -E 's/.*ERROR[:]?\s*//' "$ERRORS_FILE" > "$ERROR_MESSAGES_FILE"
    
    # Get top 5 most common error messages
    TOP_ERRORS=$(sort "$ERROR_MESSAGES_FILE" | uniq -c | sort -rn | head -5)
    
    # Extract timestamps from error lines
    grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' "$ERRORS_FILE" > "$ERROR_TIMESTAMPS_FILE" 2>/dev/null || true
    
    if [ -s "$ERROR_TIMESTAMPS_FILE" ]; then
        FIRST_ERROR_TS=$(head -1 "$ERROR_TIMESTAMPS_FILE")
        LAST_ERROR_TS=$(tail -1 "$ERROR_TIMESTAMPS_FILE")
        FIRST_ERROR_LINE=$(grep -m 1 "$FIRST_ERROR_TS" "$ERRORS_FILE" | sed -E 's/.*ERROR[:]?\s*//')
        LAST_ERROR_LINE=$(grep "$LAST_ERROR_TS" "$ERRORS_FILE" | tail -1 | sed -E 's/.*ERROR[:]?\s*//')
    else
        FIRST_ERROR_TS="N/A"
        LAST_ERROR_TS="N/A"
        FIRST_ERROR_LINE="Timestamp format not recognized"
        LAST_ERROR_LINE="Timestamp format not recognized"
    fi
    
    # Calculate error frequency by hour
    declare -A hour_counts
    for hour in {0..23}; do
        hour_counts[$hour]=0
    done
    
    if [ -s "$ERROR_TIMESTAMPS_FILE" ]; then
        while IFS= read -r timestamp; do
            # Extract hour from timestamp
            hour=$(echo "$timestamp" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | cut -d':' -f1 | sed 's/^0//' || echo "0")
            if [ -n "$hour" ] && [ "$hour" -ge 0 ] 2>/dev/null && [ "$hour" -le 23 ] 2>/dev/null; then
                ((hour_counts[$hour]++)) || true
            fi
        done < "$ERROR_TIMESTAMPS_FILE"
    fi
fi

# Print header
echo ""
echo "===== LOG FILE ANALYSIS REPORT ====="
echo ""
echo "File: $LOG_FILE"
echo "Analyzed on: $ANALYSIS_DATE"
echo "Size: $FILE_SIZE_DISPLAY ($FILE_SIZE_BYTES bytes)"
echo ""
echo "MESSAGE COUNTS:"
echo -e "  ${RED}ERROR${NC}:   $ERROR_COUNT messages"
echo -e "  ${YELLOW}WARNING${NC}: $WARNING_COUNT messages"
echo -e "  ${GREEN}INFO${NC}:    $INFO_COUNT messages"
echo ""

# Print error analysis if errors exist
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "TOP 5 ERROR MESSAGES:"
    echo "$TOP_ERRORS" | while IFS= read -r line; do
        count=$(echo "$line" | awk '{print $1}')
        message=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
        printf "  %4d - %s\n" "$count" "$message"
    done
    echo ""
    
    echo "ERROR TIMELINE:"
    echo "  First error: [$FIRST_ERROR_TS] $FIRST_ERROR_LINE"
    echo "  Last error:  [$LAST_ERROR_TS] $LAST_ERROR_LINE"
    echo ""
    
    if [ -s "$ERROR_TIMESTAMPS_FILE" ]; then
        echo "Error frequency by hour:"
        for range_start in 0 4 8 12 16 20; do
            range_end=$((range_start + 3))
            total=0
            for hour in $(seq $range_start $range_end); do
                total=$((total + ${hour_counts[$hour]}))
            done
            
            # Create bar chart (each █ represents ~10 errors)
            bars=$((total / 10))
            if [ "$bars" -eq 0 ] && [ "$total" -gt 0 ]; then
                bars=1
            fi
            bar_string=""
            for ((i=0; i<bars; i++)); do
                bar_string="${bar_string}█"
            done
            
            printf "  %02d-%02d: %s (%d)\n" "$range_start" "$((range_end + 1))" "$bar_string" "$total"
        done
        echo ""
    fi
else
    echo "No errors found in log file."
    echo ""
fi

echo -e "Report saved to: ${GREEN}$REPORT_FILE${NC}"

# Save report to file (without color codes)
{
    echo "===== LOG FILE ANALYSIS REPORT ====="
    echo ""
    echo "File: $LOG_FILE"
    echo "Analyzed on: $ANALYSIS_DATE"
    echo "Size: $FILE_SIZE_DISPLAY ($FILE_SIZE_BYTES bytes)"
    echo ""
    echo "MESSAGE COUNTS:"
    echo "  ERROR:   $ERROR_COUNT messages"
    echo "  WARNING: $WARNING_COUNT messages"
    echo "  INFO:    $INFO_COUNT messages"
    echo ""
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "TOP 5 ERROR MESSAGES:"
        echo "$TOP_ERRORS" | while IFS= read -r line; do
            count=$(echo "$line" | awk '{print $1}')
            message=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
            printf "  %4d - %s\n" "$count" "$message"
        done
        echo ""
        
        echo "ERROR TIMELINE:"
        echo "  First error: [$FIRST_ERROR_TS] $FIRST_ERROR_LINE"
        echo "  Last error:  [$LAST_ERROR_TS] $LAST_ERROR_LINE"
        echo ""
        
        if [ -s "$ERROR_TIMESTAMPS_FILE" ]; then
            echo "Error frequency by hour:"
            for range_start in 0 4 8 12 16 20; do
                range_end=$((range_start + 3))
                total=0
                for hour in $(seq $range_start $range_end); do
                    total=$((total + ${hour_counts[$hour]}))
                done
                
                bars=$((total / 10))
                if [ "$bars" -eq 0 ] && [ "$total" -gt 0 ]; then
                    bars=1
                fi
                bar_string=""
                for ((i=0; i<bars; i++)); do
                    bar_string="${bar_string}█"
                done
                
                printf "  %02d-%02d: %s (%d)\n" "$range_start" "$((range_end + 1))" "$bar_string" "$total"
            done
        fi
    else
        echo "No errors found in log file."
    fi
} > "$REPORT_FILE"

echo -e "${GREEN}Analysis complete!${NC}"
