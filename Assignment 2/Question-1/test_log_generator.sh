#!/bin/bash

# Script to generate a realistic test log file
# Usage: ./test_log_generator.sh [number_of_entries] [output_file]

ENTRIES=${1:-1000}
OUTPUT=${2:-test_application.log}

ERROR_MSGS=(
    "Database connection failed: timeout"
    "Invalid authentication token provided"
    "Failed to write to disk: Permission denied"
    "API rate limit exceeded"
    "Uncaught exception: Null pointer reference"
    "Memory allocation failed"
    "Network timeout on external service"
    "Configuration file not found"
)

WARNING_MSGS=(
    "Memory usage at 85%"
    "Disk space low on /var partition"
    "SSL certificate expires in 30 days"
    "High network latency detected"
    "Connection pool exhausted"
    "Retry limit reached for external API"
    "Queue depth exceeding threshold"
    "Background job timeout"
)

INFO_MSGS=(
    "Application started successfully"
    "User login: user123"
    "Processing batch job"
    "Cache cleared successfully"
    "Backup completed"
    "Service health check passed"
    "Request processed"
    "Session created"
    "Data sync completed"
    "Metrics published"
)

> "$OUTPUT"

for ((i=1; i<=ENTRIES; i++)); do
    # Random date in last 7 days
    DAYS_AGO=$((RANDOM % 7))
    HOUR=$((RANDOM % 24))
    MINUTE=$((RANDOM % 60))
    SECOND=$((RANDOM % 60))
    
    TIMESTAMP=$(date -d "$DAYS_AGO days ago" "+%Y-%m-%d" 2>/dev/null || date -v-${DAYS_AGO}d "+%Y-%m-%d")
    TIMESTAMP="$TIMESTAMP $(printf "%02d:%02d:%02d" $HOUR $MINUTE $SECOND)"
    
    # 20% ERROR, 30% WARNING, 50% INFO
    RAND=$((RANDOM % 100))
    
    if [ $RAND -lt 20 ]; then
        LEVEL="ERROR"
        MSG_ARRAY=("${ERROR_MSGS[@]}")
    elif [ $RAND -lt 50 ]; then
        LEVEL="WARNING"
        MSG_ARRAY=("${WARNING_MSGS[@]}")
    else
        LEVEL="INFO"
        MSG_ARRAY=("${INFO_MSGS[@]}")
    fi
    
    MSG="${MSG_ARRAY[$RANDOM % ${#MSG_ARRAY[@]}]}"
    echo "[$TIMESTAMP] $LEVEL $MSG" >> "$OUTPUT"
done

sort "$OUTPUT" -o "$OUTPUT"
echo "Generated $ENTRIES log entries in $OUTPUT"
