#!/bin/bash
# Get CPU temperature from lm-sensors (works with AMD, Intel, and others)
temp=$(sensors | grep -E "(Package id|Core|Tdie|temp1):" | head -1 | grep -oP '\+\K[0-9.]+' | head -1)
# Round and remove unnecessary .0
printf "%.1f" "$temp" | sed 's/\.0$//' || echo "N/A"
