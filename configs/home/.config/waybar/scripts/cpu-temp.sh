#!/bin/bash
# Get CPU temperature from lm-sensors (AMD and Intel compatible)
# Try AMD k10temp first
temp=$(sensors | grep -A2 "k10temp" | grep "Tctl:" | grep -oP '\+\K[0-9.]+' | head -1)

# Fallback to Intel Package ID
if [ -z "$temp" ]; then
  temp=$(sensors 2>/dev/null | grep "Package id" | grep -oP '\+\K[0-9.]+' | head -1)
fi

# Fallback to Core temperature
if [ -z "$temp" ]; then
  temp=$(sensors 2>/dev/null | grep "Core" | grep -oP '\+\K[0-9.]+' | head -1)
fi

# Fallback to Tdie (some AMD CPUs)
if [ -z "$temp" ]; then
  temp=$(sensors 2>/dev/null | grep "Tdie:" | grep -oP '\+\K[0-9.]+' | head -1)
fi

# Format output
if [ -n "$temp" ]; then
  printf "%.1f" "$temp" | sed 's/\.0$//'
else
  echo "N/A"
fi
