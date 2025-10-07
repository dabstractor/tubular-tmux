#!/bin/bash
# Get window index icon from configurable icon string
# Displays the window number (#I) as an icon

window_number="$1"

# Get icon string from tmux option
icon_string=$(tmux show-option -gqv "@tubular_window_icons")
if [ -z "$icon_string" ]; then
  # Default icons for window numbers 1-10 (truncated to 10)
  icon_string="󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞"
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use utility to select icon with fallback
"$SCRIPT_DIR/select-icon.sh" "$icon_string" "$window_number" "󰲞"
