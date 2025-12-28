#!/bin/bash
# Get GPU temperature - supports NVIDIA, AMD, and Intel GPUs
if command -v nvidia-smi &> /dev/null; then
  # NVIDIA GPU
  temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
elif sensors | grep -q "amdgpu"; then
  # AMD GPU
  temp=$(sensors | grep -A2 "amdgpu" | grep "edge:" | awk '{print $2}' | tr -d '+°C')
elif sensors | grep -q "pch_cannonlake\|pch_sunrisepoint\|pch_\|iwlwifi"; then
  # Intel GPU (from lm-sensors)
  temp=$(sensors | grep -E "Package|temp1" | head -1 | awk '{print $3}' | tr -d '+°C')
else
  echo "N/A"
  exit 0
fi
# Round and remove unnecessary .0
printf "%.1f" "$temp" | sed 's/\.0$//'
