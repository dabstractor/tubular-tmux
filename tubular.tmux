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
bg_max=$(get_tmux_option "@tubular_bg_max" "#181822")
bg_min=$(get_tmux_option "@tubular_bg_min" "#24242e")
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


tmux set-option -g @active_pane_in_mode $(tmux display-message -p "#{?pane_in_mode}")
tmux set-option -g @active_window_zoomed $(tmux display-message -p "#{?window_zoomed_flag}")

# === Store Resolved Colors as Internal Options ===
# These will be referenced in templates as #{@_tubular_color_name}
tmux set-option -g @_tubular_bg "$bg"
tmux set-option -g @_tubular_bg_max "$bg_max"
tmux set-option -g @_tubular_bg_min "$bg_min"
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
tmux set-option -g @tubular_status_bg "$bg_max"
tmux set-option -g @tubular_status_fg "$neutral_visible"
tmux set-option -g @tubular_status_fg_dim "$neutral_visible"
tmux set-option -g @tubular_status_fg_muted "$neutral_hidden"

# === Set Icon Options for Scripts ===
tmux set-option -g @tubular_pane_icons "$pane_icons"
tmux set-option -g @tubular_window_icons "$window_icons"
# tmux set-option -g @tubular_zoom_indicator "$zoom_indicator"

# === Store Section Format Strings ===
# These are used by status-format[0] for accurate measurement
tmux set-option -g @left-section '#{T:status-left}'
tmux set-option -g @right-section '#{T:status-right}'
tmux set-option -g @window-section '#{W:#[range=window|#{window_index} #{window-status-style}]#{T:window-status-format}#[norange default]#{?window_end_flag,,#[fg=#{T:@window-status-fg},bg=#{T:@window-status-bg}]#{window-status-separator}},#[range=window|#{window_index} list=focus #{window-status-style}]#{T:window-status-current-format}#[norange default]#{?window_end_flag,,#[fg=#{T:@window-status-fg},bg=#{T:@window-status-bg}]#{window-status-separator}}}'

# === Store Colors for Prefix Highlighting Script ===
tmux set-option -g @prefix_highlight_color "$prefix_color"
tmux set-option -g @prefix_normal_color "$bg_max"
tmux set-option -g @prefix_normal_pane_color "$active_color"
tmux set-option -g @prefix_window_active_style_normal "fg=$fg,bg=$bg"
tmux set-option -g @prefix_window_active_style_highlight "fg=$fg_focus,bg=$bg_min"

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
tmux set-option -g status-bg "$bg_max"
# tmux set-option -g status-bg "#{?client_prefix,#ff0000,$bg_max}"

tmux set-window-option -g window-status-activity-style "fg=$fg,bg=$bg_max,none"
tmux set-window-option -g window-status-separator "$separator"
# tmux set-window-option -g window-status-separator ""
tmux set-window-option -g window-status-style "fg=${?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{@tubular_active_color}}},bg=$bg_max,none"

tmux set-option -g message-style "fg=$bg,bg=$active_color,align=centre"
tmux set-option -g message-command-style "fg=$bg,bg=$active_color,align=centre"

# tmux set-option -g pane-active-border-style "fg=$active_color,bg=$active_color"

# tmux set-option -g pane-active-border-style "fg=#{?client_prefix,#{@_tubular_prefix_color},#{?@active_pane_in_mode,#{@_tubular_copy_color},#{@tubular_active_color}}},bg=#{?#{@tubular_active_extra_bold},#{?client_prefix,#{@_tubular_prefix_color},#{?@active_pane_in_mode,@_tubular_copy_color,#{@_tubular_active_color}}},$tubular_bg_max}"
tmux set-option -g pane-active-border-style "fg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{@tubular_active_color}}},bg=#{?client_prefix,#{?#{@tubular_prefix_extra_bold},#{@_tubular_prefix_color},#{@_tubular_bg_max}},#{?pane_in_mode,#{?#{@tubular_copy_extra_bold},#{@_tubular_copy_color},#{@_tubular_bg_max}},#{?#{@tubular_active_extra_bold},#{@_tubular_active_color},#{@_tubular_bg_max}}}}"

##{?#{@tubular_active_extra_bold},#{?client_prefix,#{@_tubular_prefix_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},#{@tubular_active_color}}},#{@_tubular_bg}}"
tmux set-option -g pane-border-style "fg=#{?client_prefix,$bg_min,$neutral_hidden},bg=#{?#{@tubular_normal_extra_bold},$neutral_hidden,$bg_max}"
# tmux set-option -g pane-border-style "fg=$neutral_hidden,bg=#{?client_prefix,$neutral_hidden,$bg_max}"
tmux set-option -g pane-border-lines "#{?client_prefix?,heavy,heavy}"
tmux set-option -g window-style "fg=$neutral_visible,bg=$bg_max"
# tmux set-option -g window-active-style "fg=$fg,bg=$bg"
# tmux set-option -g win16kdow-active-style "fg=#{?pane_in_mode,#f0ff0f,$fg},bg=#{?#{!=:client_prefix},$neutral_hidden,$bg}"

tmux set-option -g window-active-style "fg=#{?pane_in_mode,#f0ff0f,$fg},bg=#{?#{!=:client_prefix},$neutral_hidden,$bg}"

tmux set-window-option -g clock-mode-colour "$active_color"
tmux set-window-option -g mode-style "fg=$bg_max bg=$copy_color bold"

tmux set-option -g @window-status-bg "#{?client_prefix,#{@_tubular_prefix_color},#{?@active_pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},#{@_tubular_bg_max}}}}"
tmux set-option -g @window-status-fg "#{?client_prefix,#{@_tubular_prefix_fg},#{?@pane_in_mode,#{@_tubular_copy_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{@_tubular_neutral_visible}}}}"
# tmux set-option -g @window-status-fg "#000000"

# === Build Status Line Content ===
# Status left - using tmux option references for dynamic colors
tmux set-option -g status-left "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?pane_in_mode,#{@_tubular_copy_fg},#{?window_zoomed_flag,#{@_tubular_zoom_fg},#{@_tubular_neutral_visible}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_bg_max}}}},nobold]$status_left_text"

# Status right - using tmux option references for dynamic colors
tmux set-option -g status-right "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?pane_in_mode,#{@_tubular_copy_fg},#{?window_zoomed_flag,#{@_tubular_zoom_fg},#{@_tubular_neutral_visible}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_bg_max}}}}]$status_right_text"

# Active window format - using tmux option references
tmux set-window-option -g window-status-current-format "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{?pane_in_mode,#{@_tubular_copy_fg},#{@_tubular_active_color}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},#{@_tubular_bg_max}}}},nobold,nounderscore,noitalics]\
$tab_start#[fg=#{?client_prefix,#{@tubular_status_bg},#{?pane_in_mode,#{@_tubular_copy_color},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_bg_max}}}},bg=#{?client_prefix,#{@_tubular_bg},#{?pane_in_mode,#{@_tubular_bg},#{@_tubular_active_color}}}]\
$window_tab_text#[fg=#{@_tubular_bg_max}]\
#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?pane_in_mode,#{@_tubular_copy_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{@_tubular_active_color}}}},\
bg=#{?client_prefix,#{@_tubular_prefix_color},#{?pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},default}}}]\
$tab_end"

# Inactive window format - Pure tmux conditionals with variable-based icon selectors
tmux set-window-option -g window-status-format "#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_pane_in_mode,#{@_tubular_copy_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{?@active_pane_in_mode,#{@_tubular_copy_color},#{@_tubular_fg}}}}},bg=#{?client_prefix,#{@_tubular_prefix_color},#{?@active_pane_in_mode,#{@_tubular_copy_color},#{?@active_window_zoomed,#{@_tubular_zoom_color},#{@_tubular_bg_max}}}}]\
$window_tab_text#[fg=#{?client_prefix,#{@_tubular_prefix_fg},#{?@active_window_zoomed,#{@_tubular_zoom_fg},#{?@active_pane_in_mode,#{@_tubular_copy_fg},#{?window_zoomed_flag,#{@_tubular_zoom_color},#{@_tubular_neutral_hidden}}}}}]\
#{?client_prefix,#{?#{==:#{window_index},1},#{=1:#{@tubular_window_icons}},#{?#{==:#{window_index},2},#{=1:#{s/#{=1:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},3},#{=1:#{s/#{=2:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},4},#{=1:#{s/#{=3:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},5},#{=1:#{s/#{=4:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},6},#{=1:#{s/#{=5:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},7},#{=1:#{s/#{=6:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},8},#{=1:#{s/#{=7:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},9},#{=1:#{s/#{=8:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},0},#{=1:#{s/#{=9:#{@tubular_window_icons}}//:#{@tubular_window_icons}}}, }}}}}}}}}},#{?#{>:#{window_panes},1},#{?#{==:#{window_panes},1},#{=1:#{@tubular_pane_icons}},#{?#{==:#{window_panes},2},#{=1:#{s/#{=1:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},3},#{=1:#{s/#{=2:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},4},#{=1:#{s/#{=3:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},5},#{=1:#{s/#{=4:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},6},#{=1:#{s/#{=5:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},7},#{=1:#{s/#{=6:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},8},#{=1:#{s/#{=7:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},9},#{=1:#{s/#{=8:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},0},#{=1:#{s/#{=9:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}}, }}}}}}}}}}, }}"


# tmux set-option -g status 3




# Status format[0] - Perfect centering with pure tmux conditionals
# Uses stored sections (@left-section, @window-section, @right-section) for accurate measurement
# Icon selectors use nested conditionals instead of shell scripts for consistency
tmux set-option -g status-format[0] "\
#{E:@left-section}\
#[bg=#{T:@window-status-bg},fg=#{T:@window-status-fg}]\
#(justify=\$(tmux display-message -p '#{status-justify}'); \
left=\$(tmux display-message -p '#{w:#{E:@left-section}}'); \
right=\$(tmux display-message -p '#{w:#{E:@right-section}}'); \
client=\$(tmux display-message -p '#{client_width}'); \
w=\$(tmux display-message -p '#{w:#{E:@window-section}}'); \
available=\$(( client - left - right )); \
if [ \"\$justify\" = \"centre\" ]; then \
  base_pad=\$(( (available - w) / 2 )); \
  left_pad=\$(( base_pad + 1 )); \
  center_pos=\$(( left + left_pad + w/2 )); \
  target_center=\$(( client / 2 )); \
  diff=\$(( target_center - center_pos )); \
  left_pad=\$(( left_pad + diff )); \
  printf '%*s' \$left_pad ''; \
elif [ \"\$justify\" = \"right\" ]; then \
  pad=\$(( available - w + 2 )); \
  printf '%*s' \$pad ''; \
fi)\
#{E:@window-section}\
#[bg=#{T:@window-status-bg},fg=#{T:@window-status-fg}]\
#(justify=\$(tmux display-message -p '#{status-justify}'); \
left=\$(tmux display-message -p '#{w:#{E:@left-section}}'); \
right=\$(tmux display-message -p '#{w:#{E:@right-section}}'); \
client=\$(tmux display-message -p '#{client_width}'); \
w=\$(tmux display-message -p '#{w:#{E:@window-section}}'); \
available=\$(( client - left - right )); \
if [ \"\$justify\" = \"centre\" ]; then \
  base_pad=\$(( (available - w) / 2 )); \
  remainder=\$(( (available - w) % 2 )); \
  left_pad=\$(( base_pad + 1 )); \
  right_pad=\$(( base_pad + remainder + 1 )); \
  center_pos=\$(( left + left_pad + w/2 )); \
  target_center=\$(( client / 2 )); \
  diff=\$(( target_center - center_pos )); \
  right_pad=\$(( right_pad - diff )); \
  printf '%*s' \$right_pad ''; \
elif [ \"\$justify\" = \"left\" ]; then \
  pad=\$(( available - w + 2 )); \
  printf '%*s' \$pad ''; \
fi)\
#{E:@right-section}"


# # === Set Up Hooks ===
# Inline hooks to update @active_pane_in_mode and @active_window_zoomed
# These use run-shell to capture format expansion into global variables
tmux set-hook -g pane-mode-changed[0] \
  "run-shell 'tmux set -g @active_pane_in_mode \$(tmux display -p \"#{pane_in_mode}\")'"
tmux set-hook -g pane-mode-changed[1] "refresh-client -S"
tmux set-hook -g after-select-pane \
  "run-shell 'tmux set -g @active_pane_in_mode \$(tmux display -p \"#{pane_in_mode}\")'"
tmux set-hook -g after-select-window[0] \
  "run-shell 'tmux set -g @active_pane_in_mode \$(tmux display -p \"#{pane_in_mode}\"); tmux set -g @active_window_zoomed \$(tmux display -p \"#{window_zoomed_flag}\")'"
tmux set-hook -g after-select-window[1] "refresh-client -S"
tmux set-hook -g after-resize-pane[0] \
  "run-shell 'tmux set -g @active_window_zoomed \$(tmux display -p \"#{window_zoomed_flag}\")'"
tmux set-hook -g after-resize-pane[1] "refresh-client -S"
tmux set-hook -g after-split-window "refresh-client -S"
tmux set-hook -g after-new-window "refresh-client -S"
tmux set-hook -g after-kill-pane "refresh-client -S"
tmux set-hook -g client-session-changed "refresh-client -S"
tmux set-hook -g session-window-changed "refresh-client -S"

# tmux set-hook -g after-select-window "run-shell '\$TUBULAR_DIR/scripts/prefix-highlght.sh'"
# tmux set-hook -g after-resize-pane "if-shell '[ #{client_prefix} -eq 1 ] || [ #{pane_in_mode} -eq 1 ]' \"run-shell -b '\$TUBULAR_DIR/scripts/prefix-highlight.sh'\""
# tmux set-hook -g after-split-window "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
# tmux set-hook -g after-new-window "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
# tmux set-hook -g after-kill-pane "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
# tmux set-hook -g client-session-changed "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"
# tmux set-hook -g session-window-changed "run-shell '\$TUBULAR_DIR/scripts/prefix-highlight.sh'"

# === Handle Prefix Key Binding ===
prefix_key=$(get_tmux_option "@tubular_prefix_key" "")
if [ -n "$prefix_key" ]; then
  tmux bind -n "$prefix_key" run-shell "$CURRENT_DIR/scripts/prefix-highlight.sh activate"
fi

