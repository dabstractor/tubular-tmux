#!/usr/bin/env bash
# Tubular TMux - A stylish statusline plugin
# Manages all statusline styling based on user-defined colors and content

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper function to get tmux option with default
get_tmux_option() {
  local option="$1"
  local default="$2"
  local value=$(tmux show-option -gqv "$option")
  [ -n "$value" ] && echo "$value" || echo "$default"
}

# Helper function to resolve variable references
# If a value starts with @, it's a reference to another tmux option
resolve_option() {
  local value="$1"
  if [[ "$value" == @* ]]; then
    # The value is a reference - fetch the actual option (keep the @)
    tmux show-option -gqv "$value"
  else
    echo "$value"
  fi
}

# Export CURRENT_DIR for scripts
tmux set-environment -g TUBULAR_DIR "$CURRENT_DIR"

# === Read Color Options ===
bg=$(get_tmux_option "@tubular_bg" "#1f1f28")
bg_dark=$(get_tmux_option "@tubular_bg_dark" "#181822")
bg_light=$(get_tmux_option "@tubular_bg_light" "#24242e")
fg=$(get_tmux_option "@tubular_fg" "#dcd7ba")
fg_active=$(get_tmux_option "@tubular_fg_active" "#cccccc")
fg_focus=$(get_tmux_option "@tubular_fg_focus" "#cccccc")
neutral_visible=$(get_tmux_option "@tubular_neutral_visible" "#787878")
neutral_hidden=$(get_tmux_option "@tubular_neutral_hidden" "#54546d")

# Mode-specific colors - THE ONLY COLORS THAT MATTER
zoom_color=$(get_tmux_option "@tubular_zoom_color" "#e6c384")
copy_color=$(get_tmux_option "@tubular_copy_color" "#98bb6c")
prefix_color=$(get_tmux_option "@tubular_prefix_color" "#d27e99")
active_color=$(get_tmux_option "@tubular_active_color" "#7aa89f")

# Mode-specific foreground colors (default to @tubular_bg)
prefix_fg=$(get_tmux_option "@tubular_prefix_fg" "$bg")
zoom_fg=$(get_tmux_option "@tubular_zoom_fg" "$bg")
copy_fg=$(get_tmux_option "@tubular_copy_fg" "$bg")

# === Read Content Options ===
window_tab_text=$(get_tmux_option "@tubular_window_tab_text" " #W ")
status_left_text=$(get_tmux_option "@tubular_status_left_text" " #S  #{?@active_window_zoomed,    ,}")
status_right_text=$(get_tmux_option "@tubular_status_right_text" "  󰃰  %I:%M  ")
tab_start=$(get_tmux_option "@tubular_tab_start" "")
tab_end=$(get_tmux_option "@tubular_tab_end" "")
separator=$(get_tmux_option "@tubular_separator" "   ")

# === Read Icon Options ===
pane_icons=$(get_tmux_option "@tubular_pane_icons" "󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘")
window_icons=$(get_tmux_option "@tubular_window_icons" "󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞")
zoom_indicator=$(get_tmux_option "@tubular_zoom_indicator" "+")
echo "$zoom_indicator" > /tmp/tubular-zoom-indicator

# === Read Border Style Options ===
normal_border_lines=$(get_tmux_option "@tubular_normal_border_lines" "single")
normal_extra_bold=$(get_tmux_option "@tubular_normal_extra_bold" "0")
active_extra_bold=$(get_tmux_option "@tubular_active_extra_bold" "0")
prefix_border_lines=$(get_tmux_option "@tubular_prefix_border_lines" "heavy")
prefix_extra_bold=$(get_tmux_option "@tubular_prefix_extra_bold" "$active_extra_bold")
copy_border_lines=$(get_tmux_option "@tubular_copy_border_lines" "heavy")
copy_extra_bold=$(get_tmux_option "@tubular_copy_extra_bold" "$active_extra_bold")

# === Store Resolved Colors as Internal Options ===
# These will be referenced in templates as #{@_tubular_color_name}
tmux set-option -g @_tubular_bg "$bg"
tmux set-option -g @_tubular_bg_dark "$bg_dark"
tmux set-option -g @_tubular_bg_light "$bg_light"
tmux set-option -g @_tubular_fg "$fg"
tmux set-option -g @_tubular_fg_active "$fg_active"
tmux set-option -g @_tubular_fg_focus "$fg_focus"
tmux set-option -g @_tubular_neutral_visible "$neutral_visible"
tmux set-option -g @_tubular_neutral_hidden "$neutral_hidden"

# Mode-specific colors (the key variables)
tmux set-option -g @_tubular_zoom_color "$zoom_color"
tmux set-option -g @_tubular_copy_color "$copy_color"
tmux set-option -g @_tubular_prefix_color "$prefix_color"
tmux set-option -g @_tubular_active_color "$active_color"

# Mode-specific foreground colors
tmux set-option -g @_tubular_prefix_fg "$prefix_fg"
tmux set-option -g @_tubular_zoom_fg "$zoom_fg"
tmux set-option -g @_tubular_copy_fg "$copy_fg"

# === Initialize Current Status Bar Colors (updated dynamically by prefix-highlight.sh) ===
# These represent the "current" status bar colors based on mode (normal/prefix/copy/zoom)
tmux set-option -g @tubular_status_bg "$bg_dark"
tmux set-option -g @tubular_status_fg "$neutral_visible"
tmux set-option -g @tubular_status_fg_dim "$neutral_visible"
tmux set-option -g @tubular_status_fg_muted "$neutral_hidden"

# === Set Icon Options for Scripts ===
tmux set-option -g @tubular_pane_icons "$pane_icons"
tmux set-option -g @tubular_window_icons "$window_icons"
# tmux set-option -g @tubular_zoom_indicator "$zoom_indicator"

# === Store Colors for Prefix Highlighting Script ===
tmux set-option -g @prefix_highlight_color "$prefix_color"
tmux set-option -g @prefix_normal_color "$bg_dark"
tmux set-option -g @prefix_normal_pane_color "$active_color"
tmux set-option -g @prefix_window_active_style_normal "fg=$fg,bg=$bg"
tmux set-option -g @prefix_window_active_style_highlight "fg=$fg_focus,bg=$bg_light"

tmux set-option -g @copy_mode_color "$copy_color"
tmux set-option -g @copy_mode_pane_color "$copy_color"
tmux set-option -g @copy_mode_window_active_style "fg=$fg_active,bg=$bg"

tmux set-option -g @zoom_mode_color "$zoom_color"
tmux set-option -g @zoom_mode_pane_color "$zoom_color"
tmux set-option -g @zoom_mode_window_active_style "fg=$fg,bg=$bg"

tmux set-option -g @normal_pane_border_color "$neutral_hidden"

# Border style options
tmux set-option -g @normal_border_lines "$normal_border_lines"
tmux set-option -g @normal_extra_bold "$normal_extra_bold"
tmux set-option -g @active_extra_bold "$active_extra_bold"
tmux set-option -g @prefix_border_lines "$prefix_border_lines"
tmux set-option -g @prefix_extra_bold "$prefix_extra_bold"
tmux set-option -g @copy_border_lines "$copy_border_lines"
tmux set-option -g @copy_extra_bold "$copy_extra_bold"

# === Apply Base Styling ===
tmux set-option -g status "on"
tmux set-option -g status-bg "$bg_dark"
tmux set-option -g status-justify "centre"
tmux set-option -g status-left-length "100"
tmux set-option -g status-right-length "10000"

tmux set-window-option -g window-status-activity-style "fg=$fg,bg=$bg_dark,none"
tmux set-window-option -g window-status-separator "$separator"
tmux set-window-option -g window-status-style "fg=$fg,bg=$bg_dark,none"

tmux set-option -g message-style "fg=$bg,bg=$active_color,align=centre"
tmux set-option -g message-command-style "fg=$bg,bg=$active_color,align=centre"

tmux set-option -g pane-active-border-style "fg=$active_color,bg=$active_color"
tmux set-option -g pane-border-style "fg=$neutral_hidden,bg=$bg_dark"
tmux set-option -g pane-border-lines heavy
tmux set-option -g window-style "fg=$neutral_visible,bg=$bg_dark"
tmux set-option -g window-active-style "fg=$fg,bg=$bg"

tmux set-window-option -g clock-mode-colour "$active_color"
tmux set-window-option -g mode-style "fg=$bg_dark bg=$copy_color bold"

# === Build Status Line Content ===
# Status left - using tmux option references for dynamic colors
tmux set-option -g status-left "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?pane_in_mode,#{@_tubular_copy_fg},#{?window_zoomed_flag,#{@_tubular_zoom_fg},#{@_tubular_neutral_visible}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_bg_dark}}}},nobold]$status_left_text"

# Status right - using tmux option references for dynamic colors
tmux set-option -g status-right "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?pane_in_mode,#{@_tubular_copy_fg},#{?window_zoomed_flag,#{@_tubular_zoom_fg},#{@_tubular_neutral_visible}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_bg_dark}}}}]$status_right_text"

# Active window format - using tmux option references
tmux set-window-option -g window-status-current-format "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{?@active_pane_in_mode,#{@_tubular_copy_fg},#{@_tubular_active_color}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?@active_pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},#{@_tubular_bg_dark}}}},nobold,nounderscore,noitalics]$tab_start#[fg=#{?#{@active_window_zoomed},#{@_tubular_zoom_color},#{?client_prefix,#{@tubular_status_bg},#{?pane_in_mode,#{@_tubular_copy_color},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_bg_dark}}}}},bg=#{?#{||:#{@active_window_zoomed},#{||:#{@active_pane_in_mode},#{client_prefix}}},#{@tubular_status_fg},#{@_tubular_active_color}}]$window_tab_text#[fg=#{@_tubular_bg_dark}]#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_pane_in_mode,#{@_tubular_copy_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{@_tubular_active_color}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},default}}}]$tab_end"

# Inactive window format - using tmux option references
tmux set-window-option -g window-status-format "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_pane_in_mode,#{@_tubular_copy_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{?pane_in_mode,#{@_tubular_copy_color},#{@_tubular_fg}}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?@active_pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},#{@_tubular_bg_dark}}}}]$window_tab_text#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{?@active_pane_in_mode,#{@_tubular_copy_fg},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_neutral_hidden}}}}}]#{?client_prefix,#(\$TUBULAR_DIR/scripts/window-index-icon.sh #I),#{?#{>:#{window_panes},1},#{?#{||:#pane_in_mode,#window_zoomed_flag},#(\$TUBULAR_DIR/scripts/pane-count-icon.sh #I),#{?#{||:#{pane_in_mode},#{window_zoomed_flag}},#[fg=#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_copy_color}}]$tab_end, }}, }}"

# === Set Up Hooks ===
tmux set-hook -g pane-mode-changed "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
tmux set-hook -g after-select-window "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
tmux set-hook -g after-resize-pane "if-shell '[ #{client_prefix} -eq 1 ] || [ #{pane_in_mode} -eq 1 ]' \"run-shell -b '\$TUBULAR_DIR/scripts/prefix-highlight.sh'\""
tmux set-hook -g after-split-window "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
tmux set-hook -g after-new-window "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
tmux set-hook -g after-kill-pane "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
tmux set-hook -g client-session-changed "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
tmux set-hook -g session-window-changed "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"

# === Handle Prefix Key Binding ===
prefix_key=$(get_tmux_option "@tubular_prefix_key" "")
if [ -n "$prefix_key" ]; then
  tmux bind -n "$prefix_key" run-shell "$CURRENT_DIR/scripts/prefix-highlight.sh activate"
fi
