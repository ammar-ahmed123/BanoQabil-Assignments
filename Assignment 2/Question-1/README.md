<img width="838" height="604" alt="image" src="https://github.com/user-attachments/assets/079d7007-e0e4-4ddf-bfe1-1e81321f2205" />


# Log File Analyzer

A comprehensive bash script that analyzes log files for ERROR, WARNING, and INFO messages, providing detailed statistics and insights.

## Features

- **Message Counting**: Counts ERROR, WARNING, and INFO messages in log files
- **Top Error Analysis**: Identifies the 5 most common error messages with occurrence counts
- **Timeline Analysis**: Shows first and last error timestamps with their messages
- **Hourly Distribution**: Displays error frequency by 4-hour time blocks with visual bar charts
- **File Statistics**: Shows file size and analysis timestamp
- **Report Generation**: Saves detailed report to timestamped file
- **Color-Coded Output**: Terminal output with color highlighting for better readability

## Usage

```bash
./log_analyzer.sh <log_file_path>
```

### Example

```bash
./log_analyzer.sh /var/log/application.log
```

or

```bash
./log_analyzer.sh sample_application.log
```

## Requirements

- Bash 4.0 or higher (for associative arrays)
- Standard Unix utilities: `grep`, `sed`, `awk`, `wc`, `sort`, `uniq`
- Read permissions on the log file

## Output Format

The script provides:

1. **Header Section**:
   - File path
   - Analysis timestamp
   - File size (KB or MB)

2. **Message Counts**:
   - Total ERROR messages
   - Total WARNING messages
   - Total INFO messages

3. **Top 5 Error Messages**:
   - Ranked by frequency
   - Shows count and message text

4. **Error Timeline**:
   - First error occurrence with timestamp
   - Last error occurrence with timestamp

5. **Hourly Distribution**:
   - Errors grouped by 4-hour blocks
   - Visual bar chart (█ = ~10 errors)
   - Exact counts in parentheses

## Log File Format

The script works with log files using common timestamp formats:

- `[YYYY-MM-DD HH:MM:SS]` - Bracketed timestamps
- `YYYY-MM-DD HH:MM:SS` - Unbracketed timestamps
- `YYYY/MM/DD HH:MM:SS` - Slash-separated dates

Error lines should contain the keyword "ERROR" (case-insensitive).

### Example Log Entry
```
[2025-07-10 02:14:32] ERROR Database connection failed: timeout
```

## Output Files

The script generates a report file named:
```
log_analysis_YYYYMMDD_HHMMSS.txt
```

This file contains the same information as the terminal output but without color codes.

## Error Handling

The script includes validation for:
- Missing file argument
- Non-existent files
- Unreadable files
- Empty log files

## Customization

You can modify the following aspects:

1. **Bar Chart Scaling**: Edit the line `bars=$((total / 10))` to change how many errors each █ represents
2. **Top N Errors**: Change `head -5` to show more or fewer top errors
3. **Time Blocks**: Modify the `for range_start in 0 4 8 12 16 20` loop to change time groupings
4. **Timestamp Format**: Update the grep pattern in the timestamp extraction section

## Example Output

```
===== LOG FILE ANALYSIS REPORT =====

File: sample_application.log
Analyzed on: Tue Dec 02 08:01:50 UTC 2025
Size: 3.0KB (3081 bytes)

MESSAGE COUNTS:
  ERROR:   24 messages
  WARNING: 13 messages
  INFO:    15 messages

TOP 5 ERROR MESSAGES:
     9 - Database connection failed: timeout
     5 - Invalid authentication token provided
     5 - Failed to write to disk: Permission denied
     3 - API rate limit exceeded
     2 - Uncaught exception: Null pointer reference

ERROR TIMELINE:
  First error: [2025-07-10 02:14:32] Database connection failed: timeout
  Last error:  [2025-07-12 14:03:27] Failed to write to disk: Permission denied

Error frequency by hour:
  00-04: █ (4)
  04-08: █ (2)
  08-12: █ (7)
  12-16: █ (7)
  16-20: █ (2)
  20-24: █ (2)

Report saved to: log_analysis_20251202_080150.txt
```

## Technical Details

### Temporary Files
The script uses a temporary directory created with `mktemp -d` and automatically cleans it up on exit using a trap.

### Performance
The script efficiently processes large log files by:
- Using grep for initial filtering
- Processing data in temporary files
- Avoiding repeated scans of the original file

## Troubleshooting

**Issue**: "Permission denied" error
- **Solution**: Ensure the script has execute permissions: `chmod +x log_analyzer.sh`

**Issue**: No errors found but you expect some
- **Solution**: Check if your log file uses a different keyword (e.g., "ERR" instead of "ERROR")

**Issue**: Timestamp not recognized
- **Solution**: Update the timestamp extraction pattern to match your log format

## License

This script is provided as-is for educational and practical purposes.

## Author

Created as a log analysis utility for DevOps and system administration tasks.
