#!/bin/bash
# Optimized prefix highlight with batched operations and state caching

# Get color configurations (tmux show-option doesn't support batching)
HIGHLIGHT_COLOR=$(tmux show-option -gv @prefix_highlight_color)
NORMAL_COLOR=$(tmux show-option -gv @prefix_normal_color)
NORMAL_PANE_COLOR=$(tmux show-option -gv @prefix_normal_pane_color)
WINDOW_ACTIVE_STYLE_NORMAL=$(tmux show-option -gv @prefix_window_active_style_normal)
WINDOW_ACTIVE_STYLE_HIGHLIGHT=$(tmux show-option -gv @prefix_window_active_style_highlight)

# Copy mode colors
COPY_MODE_COLOR=$(tmux show-option -gv @copy_mode_color)
COPY_MODE_PANE_COLOR=$(tmux show-option -gv @copy_mode_pane_color)
WINDOW_ACTIVE_STYLE_COPY=$(tmux show-option -gv @copy_mode_window_active_style)

# Zoom mode colors
ZOOM_MODE_COLOR=$(tmux show-option -gv @zoom_mode_color)
ZOOM_MODE_PANE_COLOR=$(tmux show-option -gv @zoom_mode_pane_color)
WINDOW_ACTIVE_STYLE_ZOOM=$(tmux show-option -gv @zoom_mode_window_active_style)

# Pane border color and settings
NORMAL_PANE_BORDER_COLOR=$(tmux show-option -gv @normal_pane_border_color)
NORMAL_BORDER_LINES=$(tmux show-option -gv @normal_border_lines 2>/dev/null)
NORMAL_BORDER_LINES=${NORMAL_BORDER_LINES:-single}
NORMAL_EXTRA_BOLD=$(tmux show-option -gv @normal_extra_bold 2>/dev/null)
NORMAL_EXTRA_BOLD=${NORMAL_EXTRA_BOLD:-0}
ACTIVE_EXTRA_BOLD=$(tmux show-option -gv @active_extra_bold 2>/dev/null)
ACTIVE_EXTRA_BOLD=${ACTIVE_EXTRA_BOLD:-1}

# Active pane border settings for prefix mode
PREFIX_BORDER_LINES=$(tmux show-option -gv @prefix_border_lines 2>/dev/null)
PREFIX_BORDER_LINES=${PREFIX_BORDER_LINES:-heavy}
PREFIX_EXTRA_BOLD=$(tmux show-option -gv @prefix_extra_bold 2>/dev/null)
PREFIX_EXTRA_BOLD=${PREFIX_EXTRA_BOLD:-1}

# Active pane border settings for copy mode
COPY_BORDER_LINES=$(tmux show-option -gv @copy_border_lines 2>/dev/null)
COPY_BORDER_LINES=${COPY_BORDER_LINES:-heavy}
COPY_EXTRA_BOLD=$(tmux show-option -gv @copy_extra_bold 2>/dev/null)
COPY_EXTRA_BOLD=${COPY_EXTRA_BOLD:-1}

# Calculate non-active pane border background (based on normal settings)
if [ "$NORMAL_EXTRA_BOLD" = "1" ]; then
    NORMAL_PANE_BORDER_BG="$NORMAL_PANE_BORDER_COLOR"
else
    NORMAL_PANE_BORDER_BG="$NORMAL_COLOR"
fi

# Check if this is a special mode activation
MODE="$1"

if [ "$MODE" = "activate" ]; then
    # Prefix activation: set colors FIRST, then switch-client to avoid lag
    # Active pane uses prefix settings, non-active panes use normal settings
    if [ "$PREFIX_EXTRA_BOLD" = "1" ]; then
        PREFIX_PANE_BG="$HIGHLIGHT_COLOR"
    else
        PREFIX_PANE_BG="$NORMAL_COLOR"
    fi

    # Get status bar foreground colors for prefix mode
    BG=$(tmux show-option -gv @tubular_bg 2>/dev/null)
    BG=${BG:-#1f1f28}
    PREFIX_FG=$(tmux show-option -gv @tubular_prefix_fg 2>/dev/null)
    PREFIX_FG=${PREFIX_FG:-$BG}
    NEUTRAL_VISIBLE=$(tmux show-option -gv @tubular_neutral_visible 2>/dev/null)
    NEUTRAL_HIDDEN=$(tmux show-option -gv @tubular_neutral_hidden 2>/dev/null)
        # set -g status-bg "$HIGHLIGHT_COLOR" \; \
        # set -g pane-active-border-style "fg=$HIGHLIGHT_COLOR,bg=$PREFIX_PANE_BG" \; \
        # set -g pane-border-style "fg=$NORMAL_PANE_BORDER_COLOR,bg=$NORMAL_PANE_BORDER_BG" \; \
        # set -g pane-border-lines "$PREFIX_BORDER_LINES" \; \
        # set -g @active_pane_in_mode "0" \; \
    tmux \
         set -g @current_display_mode "prefix" \; \
         set -g @tubular_status_bg "$HIGHLIGHT_COLOR" \; \
         set -g @tubular_status_fg "$PREFIX_FG" \; \
         set -g @tubular_status_fg_dim "$NEUTRAL_VISIBLE" \; \
         set -g @tubular_status_fg_muted "$NEUTRAL_HIDDEN" \; \
         switch-client -T prefix \; 
         # refresh-client -S

    # Start polling
    ALREADY_POLLING=$(tmux show-option -gv @prefix_polling 2>/dev/null)
    if [ "$ALREADY_POLLING" != "1" ]; then
        tmux set -g @prefix_olling "1"
        tmux run-shell -b "sleep 0.01 && $0 poll 1"
    fi
    exit 0
fi

# Check if this is a poll continuation
POLLING="$MODE"
POLL_COUNT="${2:-0}"

# Batch all status checks into single tmux call - MASSIVE performance improvement
# Format: client_prefix|pane_in_mode|window_zoomed_flag|window_index
read -r CLIENT_PREFIX PANE_IN_MODE WINDOW_ZOOMED WINDOW_INDEX <<< "$(tmux display-message -p '#{client_prefix}|#{pane_in_mode}|#{window_zoomed_flag}|#{window_index}' 2>/dev/null | tr '|' ' ')"

# Get mode-specific foreground colors and neutral colors for status bar
BG=$(tmux show-option -gv @tubular_bg 2>/dev/null)
BG=${BG:-#1f1f28}
PREFIX_FG=$(tmux show-option -gv @tubular_prefix_fg 2>/dev/null)
PREFIX_FG=${PREFIX_FG:-$BG}
COPY_FG=$(tmux show-option -gv @tubular_copy_fg 2>/dev/null)
COPY_FG=${COPY_FG:-$BG}
ZOOM_FG=$(tmux show-option -gv @tubular_zoom_fg 2>/dev/null)
ZOOM_FG=${ZOOM_FG:-$BG}
NEUTRAL_VISIBLE=$(tmux show-option -gv @tubular_neutral_visible 2>/dev/null)
NEUTRAL_HIDDEN=$(tmux show-option -gv @tubular_neutral_hidden 2>/dev/null)

# Determine current mode and active pane border style (priority: prefix > copy > zoom > normal)
# Note: Non-active panes always use NORMAL_BORDER_LINES and NORMAL_EXTRA_BOLD settings
if [ "$CLIENT_PREFIX" = "1" ]; then
    NEW_MODE="prefix"
    STATUS_BG="$HIGHLIGHT_COLOR"
    STATUS_FG="$PREFIX_FG"
    ACTIVE_PANE_FG="$HIGHLIGHT_COLOR"
    # Apply prefix mode settings to active pane border
    if [ "$PREFIX_EXTRA_BOLD" = "1" ]; then
        ACTIVE_PANE_BG="$HIGHLIGHT_COLOR"
    else
        ACTIVE_PANE_BG="$NORMAL_COLOR"
    fi
    ACTIVE_PANE_BORDER_LINES="$PREFIX_BORDER_LINES"
    WINDOW_STYLE="$WINDOW_ACTIVE_STYLE_HIGHLIGHT"
    ACTIVE_IN_MODE="0"
    ACTIVE_ZOOMED="$WINDOW_ZOOMED"
elif [ "$PANE_IN_MODE" = "1" ]; then
    NEW_MODE="copy"
    STATUS_BG="$COPY_MODE_COLOR"
    STATUS_FG="$COPY_FG"
    ACTIVE_PANE_FG="$COPY_MODE_PANE_COLOR"
    # Apply copy mode settings to active pane border
    if [ "$COPY_EXTRA_BOLD" = "1" ]; then
        ACTIVE_PANE_BG="$COPY_MODE_PANE_COLOR"
    else
        ACTIVE_PANE_BG="$NORMAL_COLOR"
    fi
    ACTIVE_PANE_BORDER_LINES="$COPY_BORDER_LINES"
    WINDOW_STYLE="$WINDOW_ACTIVE_STYLE_COPY"
    ACTIVE_IN_MODE="1"
    ACTIVE_ZOOMED="$WINDOW_ZOOMED"
elif [ "$WINDOW_ZOOMED" = "1" ]; then
    NEW_MODE="zoom"
    STATUS_BG="$ZOOM_MODE_COLOR"
    STATUS_FG="$ZOOM_FG"
    ACTIVE_PANE_FG="$ZOOM_MODE_PANE_COLOR"
    # Apply active (normal state) settings to zoomed pane border
    if [ "$ACTIVE_EXTRA_BOLD" = "1" ]; then
        ACTIVE_PANE_BG="$ZOOM_MODE_PANE_COLOR"
    else
        ACTIVE_PANE_BG="$NORMAL_COLOR"
    fi
    ACTIVE_PANE_BORDER_LINES="$NORMAL_BORDER_LINES"
    WINDOW_STYLE="$WINDOW_ACTIVE_STYLE_ZOOM"
    ACTIVE_IN_MODE="0"
    ACTIVE_ZOOMED="1"
else
    NEW_MODE="normal"
    STATUS_BG="$NORMAL_COLOR"
    STATUS_FG="$NEUTRAL_VISIBLE"
    ACTIVE_PANE_FG="$NORMAL_PANE_COLOR"
    # Apply active (normal state) settings to active pane border
    if [ "$ACTIVE_EXTRA_BOLD" = "1" ]; then
        ACTIVE_PANE_BG="$NORMAL_PANE_COLOR"
    else
        ACTIVE_PANE_BG="$NORMAL_COLOR"
    fi
    ACTIVE_PANE_BORDER_LINES="$NORMAL_BORDER_LINES"
    WINDOW_STYLE="$WINDOW_ACTIVE_STYLE_NORMAL"
    ACTIVE_IN_MODE="0"
    ACTIVE_ZOOMED="0"
fi

# Get pane count icon for current window
TUBULAR_DIR=$(tmux show-environment -g TUBULAR_DIR 2>/dev/null | cut -d= -f2)
PANE_COUNT_ICON=$("$TUBULAR_DIR/scripts/pane-count-icon.sh" "$WINDOW_INDEX" 2>/dev/null)

# State caching: only update if mode changed
CURRENT_MODE=$(tmux show-option -gv @current_display_mode 2>/dev/null)

if [ "$NEW_MODE" != "$CURRENT_MODE" ]; then
    # Batch ALL tmux set commands into single call - eliminates multiple process spawns
    # Active pane uses mode-specific settings, non-active panes always use normal settings
        # set -g status-bg "$STATUS_BG" \; \
        # set -g pane-active-border-style "fg=$ACTIVE_PANE_FG,bg=$ACTIVE_PANE_BG" \; \
        # set -g pane-border-style "fg=$NORMAL_PANE_BORDER_COLOR,bg=$NORMAL_PANE_BORDER_BG" \; \
        # set -g pane-border-lines "$ACTIVE_PANE_BORDER_LINES" \; \
        # set -g window-active-style "$WINDOW_STYLE" \; \

    # tmux set -g window-active-style "fg=#{?pane_in_mode,#f0ff0f,#{@_tubular_fg}},bg=#{?#{!=:client_prefix},#{@_tubular_neutral_hidden},#{@_tubular_bg}}"

         # set -g @active_pane_in_mode "$ACTIVE_IN_MODE" \; \
    tmux \
         set -g @active_window_zoomed "$ACTIVE_ZOOMED" \; \
         set -g @tubular_pane_count "$PANE_COUNT_ICON" \; \
         set -g @current_display_mode "$NEW_MODE" \; \
         set -g @tubular_status_bg "$STATUS_BG" \; \
         set -g @tubular_status_fg "$STATUS_FG" \; \
         set -g @tubular_status_fg_dim "$NEUTRAL_VISIBLE" \; \
         set -g @tubular_status_fg_muted "$NEUTRAL_HIDDEN" \;
         # refresh-client -S
fi

# # Adaptive polling: faster initially, slows down over time
# if [ "$NEW_MODE" = "prefix" ]; then
#     # Determine poll interval based on iteration count
#     if [ "$POLL_COUNT" -lt 3 ]; then
#         INTERVAL="0.01"  # 100 Hz for instant response
#     elif [ "$POLL_COUNT" -lt 10 ]; then
#         INTERVAL="0.05"  # 20 Hz after initial burst
#     else
#         INTERVAL="0.1"   # 10 Hz for sustained prefix hold
#     fi
#
#     # Only start polling if not already polling
#     if [ "$POLLING" = "poll" ]; then
#         # Continue the polling loop with incremented counter
#         tmux run-shell -b "sleep $INTERVAL && $0 poll $((POLL_COUNT + 1))"
#     else
#         # Check if already polling (atomic check)
#         ALREADY_POLLING=$(tmux show-option -gv @prefix_polling 2>/dev/null)
#         if [ "$ALREADY_POLLING" != "1" ]; then
#             tmux set -g @prefix_polling "1"
#             tmux run-shell -b "sleep 0.01 && $0 poll 1"
#         fi
#     fi
# else
#     # Clear polling flag when exiting prefix mode
#     if [ "$CURRENT_MODE" = "prefix" ]; then
#         tmux set -g @prefix_polling "0"
#     fi
# fi

exit 0
