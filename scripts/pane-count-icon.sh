#!/bin/bash
# Get pane count icon from configurable icon string
# Displays the number of panes in a window as an icon

# Get window param if available, default to current window
if [ -n "$1" ]; then
  pane_count=$(tmux display-message -p -t ":$1" "#{window_panes}")
else
  pane_count=$(tmux display-message -p "#{window_panes}")
fi

# Get icon string from tmux option
icon_string=$(tmux show-option -gqv "@tubular_pane_icons")
if [ -z "$icon_string" ]; then
  # Default icons for pane counts 1-10 (truncated to 10)
  icon_string="󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘"
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use utility to select icon with fallback
"$SCRIPT_DIR/select-icon.sh" "$icon_string" "$pane_count" "󰼘"
