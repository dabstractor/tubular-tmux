#!/bin/bash
# Utility to select an icon from an icon string by index
# Usage: select-icon.sh <icon_string> <index> [fallback_icon]
#
# Parameters:
#   icon_string: String of icon characters (up to 10)
#   index: 1-based index to select from
#   fallback_icon: Optional fallback if selection fails

icon_string="$1"
index="$2"
fallback="${3:-}"

# Convert string to array for Unicode-safe indexing
declare -a icons
while IFS= read -r -n1 char; do
  [ -n "$char" ] && icons+=("$char")
done < <(printf '%s' "$icon_string")

# Convert 1-based index to 0-based array index
array_index=$((index - 1))

# Select icon with fallback logic
if [ "$array_index" -ge 0 ] && [ "$array_index" -lt "${#icons[@]}" ]; then
  echo "${icons[$array_index]}"
elif [ "${#icons[@]}" -gt 0 ]; then
  # Use last icon if index out of bounds
  echo "${icons[-1]}"
elif [ -n "$fallback" ]; then
  # Use provided fallback
  echo "$fallback"
fi
