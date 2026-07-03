#!/usr/bin/env bash
# Tubular TMux - A stylish statusline plugin
#
# Architecture: everything in the render path is a tmux format string that
# reads live server state (client_prefix, pane_in_mode, window_flags) on every
# redraw. No shell runs at render time, no state is cached in options, so the
# bar and borders can never disagree with the actual mode.
#
# The only imperative pieces are two key bindings that force a full client
# repaint (refresh-client) on prefix entry/exit, because tmux redraws the
# status line on its own when the key table changes but never repaints pane
# borders.

# Helper function to get tmux option with default
get_tmux_option() {
  local option="$1"
  local default="$2"
  local value=$(tmux show-option -gqv "$option")
  [ -n "$value" ] && echo "$value" || echo "$default"
}

# === Read Color Options ===
bg=$(get_tmux_option "@tubular_bg" "#1f1f28")
bg_max=$(get_tmux_option "@tubular_bg_max" "#181822")
bg_min=$(get_tmux_option "@tubular_bg_min" "#24242e")
fg=$(get_tmux_option "@tubular_fg" "#dcd7ba")
fg_active=$(get_tmux_option "@tubular_fg_active" "#cccccc")
fg_focus=$(get_tmux_option "@tubular_fg_focus" "#dddddd")
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
status_left_text=$(get_tmux_option "@tubular_status_left_text" " #S  ")
status_right_text=$(get_tmux_option "@tubular_status_right_text" "  󰃰  %I:%M  ")
tab_start=$(get_tmux_option "@tubular_tab_start" "")
tab_end=$(get_tmux_option "@tubular_tab_end" "")
separator=$(get_tmux_option "@tubular_separator" "   ")

# === Read Icon Options ===
pane_icons=$(get_tmux_option "@tubular_pane_icons" "󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘")
window_icons=$(get_tmux_option "@tubular_window_icons" "󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞")
zoom_indicator=$(get_tmux_option "@tubular_zoom_indicator" "+")

# === Read Border Style Options ===
# Note: pane-border-lines cannot be a format, so the line style is static
# (@tubular_normal_border_lines). Only colors/bold change per mode.
normal_border_lines=$(get_tmux_option "@tubular_normal_border_lines" "single")
normal_extra_bold=$(get_tmux_option "@tubular_normal_extra_bold" "0")
active_extra_bold=$(get_tmux_option "@tubular_active_extra_bold" "0")
prefix_extra_bold=$(get_tmux_option "@tubular_prefix_extra_bold" "$active_extra_bold")
copy_extra_bold=$(get_tmux_option "@tubular_copy_extra_bold" "$active_extra_bold")

# === Live Mode Expressions (the core of the plugin) ===
# These read the ACTIVE window's state from any format context - including
# while rendering other windows' tabs - by scanning the window list and
# emitting only the active window's value. No stored state, never stale.
copy_live='#{==:#{W:#{?window_active,#{pane_in_mode},}},1}'
zoom_live='#{m:*Z*,#{W:#{?window_active,#{window_flags},}}}'

# Priority: prefix > copy > zoom > normal
mode_bg="#{?client_prefix,$prefix_color,#{?$copy_live,$copy_color,#{?$zoom_live,$zoom_color,$bg_max}}}"
mode_fg="#{?client_prefix,$prefix_fg,#{?$copy_live,$copy_fg,#{?$zoom_live,$zoom_fg,$neutral_visible}}}"
any_mode="#{?client_prefix,1,#{?$copy_live,1,#{?$zoom_live,1,}}}"

# Current-window pill: inverted in any mode (dark pill, mode-colored text),
# accent-colored pill with dark text in normal mode.
pill_bg="#{?$any_mode,$bg,$active_color}"
pill_fg="#{?$any_mode,#{?client_prefix,$prefix_color,#{?$copy_live,$copy_color,$zoom_color}},$bg_max}"

# Indicator icon on inactive tabs: dim in normal mode (zoom-colored if that
# particular window is zoomed), mode fg otherwise.
icon_fg="#{?client_prefix,$prefix_fg,#{?$copy_live,$copy_fg,#{?$zoom_live,$zoom_fg,#{?window_zoomed_flag,$zoom_color,$neutral_hidden}}}}"

# Store for use in styles/formats via #{E:...} and for user content strings
tmux set-option -g @tubular_mode_bg "$mode_bg"
tmux set-option -g @tubular_mode_fg "$mode_fg"
tmux set-option -g @tubular_pill_bg "$pill_bg"
tmux set-option -g @tubular_pill_fg "$pill_fg"
tmux set-option -g @tubular_icon_fg "$icon_fg"
# Legacy names kept as aliases; these are now live formats (use #{E:...})
tmux set-option -g @tubular_status_bg "$mode_bg"
tmux set-option -g @tubular_status_fg "$mode_fg"

# Static color options for user content strings
tmux set-option -g @_tubular_bg "$bg"
tmux set-option -g @_tubular_bg_max "$bg_max"
tmux set-option -g @_tubular_bg_min "$bg_min"
tmux set-option -g @_tubular_fg "$fg"
tmux set-option -g @_tubular_fg_active "$fg_active"
tmux set-option -g @_tubular_fg_focus "$fg_focus"
tmux set-option -g @_tubular_neutral_visible "$neutral_visible"
tmux set-option -g @_tubular_neutral_hidden "$neutral_hidden"
tmux set-option -g @_tubular_zoom_color "$zoom_color"
tmux set-option -g @_tubular_copy_color "$copy_color"
tmux set-option -g @_tubular_prefix_color "$prefix_color"
tmux set-option -g @_tubular_active_color "$active_color"

# === Icon Options ===
tmux set-option -g @tubular_pane_icons "$pane_icons"
tmux set-option -g @tubular_window_icons "$window_icons"
tmux set-option -g @tubular_zoom_indicator "$zoom_indicator"

# === Base Styling ===
tmux set-option -g status "on"
# status-style is format-expanded on every redraw: the ENTIRE bar (separators,
# padding, both ends) takes the mode color as one solid block.
tmux set-option -g status-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
# Back on stock status-format, so the length limits apply again
tmux set-option -g status-left-length 100
tmux set-option -g status-right-length 150

tmux set-window-option -g window-status-separator "$separator"
tmux set-window-option -g window-status-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-window-option -g window-status-activity-style "fg=$fg,bg=#{E:@tubular_mode_bg},none"

tmux set-option -g message-style "fg=$bg,bg=$active_color,align=centre"
tmux set-option -g message-command-style "fg=$bg,bg=$active_color,align=centre"

tmux set-window-option -g clock-mode-colour "$active_color"
tmux set-window-option -g mode-style "fg=$fg,bg=$copy_color,bold"

tmux set-option -g window-style "fg=$neutral_visible,bg=$bg_max"
tmux set-option -g window-active-style "fg=#{?pane_in_mode,$fg_focus,$fg},bg=#{?client_prefix,$neutral_hidden,$bg}"

# === Pane Borders ===
# extra_bold=1 paints the border background with the border color (a thick
# solid band); otherwise the background stays dark. Baked here at load time.
[ "$normal_extra_bold" = "1" ] && normal_border_bg="$neutral_hidden" || normal_border_bg="$bg_max"
[ "$prefix_extra_bold" = "1" ] && prefix_border_bg="$prefix_color" || prefix_border_bg="$bg_max"
[ "$copy_extra_bold" = "1" ] && copy_border_bg="$copy_color" || copy_border_bg="$bg_max"
[ "$active_extra_bold" = "1" ] && active_border_bg="$active_color" || active_border_bg="$bg_max"
[ "$active_extra_bold" = "1" ] && zoom_border_bg="$zoom_color" || zoom_border_bg="$bg_max"

tmux set-option -g pane-border-lines "$normal_border_lines"
tmux set-option -g pane-border-style "fg=#{?client_prefix,$bg_min,$neutral_hidden},bg=$normal_border_bg"
# Active pane border is evaluated in the pane's own context, so pane_in_mode
# and window_zoomed_flag are direct here (no window-list scan needed).
tmux set-option -g pane-active-border-style "fg=#{?client_prefix,$prefix_color,#{?pane_in_mode,$copy_color,#{?window_zoomed_flag,$zoom_color,$active_color}}},bg=#{?client_prefix,$prefix_border_bg,#{?pane_in_mode,$copy_border_bg,#{?window_zoomed_flag,$zoom_border_bg,$active_border_bg}}}"

# === Status Line Content ===
tmux set-option -g status-left "#[fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg},nobold]$status_left_text"
tmux set-option -g status-right "#[fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}]$status_right_text"

# Current window: pill with rounded caps sitting on the mode-colored bar
tmux set-window-option -g window-status-current-format "#[fg=#{E:@tubular_pill_bg},bg=#{E:@tubular_mode_bg},nobold,nounderscore,noitalics]$tab_start#[fg=#{E:@tubular_pill_fg},bg=#{E:@tubular_pill_bg}]$window_tab_text#[fg=#{E:@tubular_pill_bg},bg=#{E:@tubular_mode_bg}]$tab_end"

# Inactive windows: name plus an indicator icon - the window's jump index
# while the prefix is held, otherwise its pane count (when more than 1 pane).
# Pure tmux glyph lookup: strip the first N-1 icons, take the next one.
window_icon_chain='#{?#{==:#{window_index},1},#{=1:#{@tubular_window_icons}},#{?#{==:#{window_index},2},#{=1:#{s/#{=1:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},3},#{=1:#{s/#{=2:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},4},#{=1:#{s/#{=3:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},5},#{=1:#{s/#{=4:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},6},#{=1:#{s/#{=5:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},7},#{=1:#{s/#{=6:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},8},#{=1:#{s/#{=7:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},9},#{=1:#{s/#{=8:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},0},#{=1:#{s/#{=9:#{@tubular_window_icons}}//:#{@tubular_window_icons}}}, }}}}}}}}}}'
pane_icon_chain='#{?#{==:#{window_panes},1},#{=1:#{@tubular_pane_icons}},#{?#{==:#{window_panes},2},#{=1:#{s/#{=1:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},3},#{=1:#{s/#{=2:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},4},#{=1:#{s/#{=3:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},5},#{=1:#{s/#{=4:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},6},#{=1:#{s/#{=5:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},7},#{=1:#{s/#{=6:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},8},#{=1:#{s/#{=7:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},9},#{=1:#{s/#{=8:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},0},#{=1:#{s/#{=9:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}}, }}}}}}}}}}'
icon_selector="#{?client_prefix,$window_icon_chain,#{?#{>:#{window_panes},1},$pane_icon_chain, }}"

tmux set-window-option -g window-status-format "#[fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}]$window_tab_text#[fg=#{E:@tubular_icon_fg}]$icon_selector"

# === Clean Up Legacy Machinery (running servers upgrading in place) ===
# (unset the whole array: unsetting a single index deletes it instead of
# restoring the default entry)
tmux set-option -gu status-format 2>/dev/null
# Legacy status-bg/fg override the corresponding parts of status-style when
# set, which silently pins the bar background and defeats the mode coloring.
tmux set-option -gu status-bg 2>/dev/null
tmux set-option -gu status-fg 2>/dev/null
tmux set-option -gu @window-section 2>/dev/null
tmux set-option -gu @left-section 2>/dev/null
tmux set-option -gu @right-section 2>/dev/null
tmux set-option -gu @window-status-bg 2>/dev/null
tmux set-option -gu @window-status-fg 2>/dev/null
tmux set-hook -gu pane-mode-changed 2>/dev/null

# === Prefix Handling ===
# tmux never repaints pane borders when the prefix state changes, and native
# prefix handling preempts root-table bindings, so we own the key entirely:
# prefix is None and the key switches tables by hand, then forces a repaint.
# `Any` catches every key with no binding in the prefix table (Escape, stray
# keys, ...) and repaints AFTER the table has reset - this is what un-sticks
# the border. Both are pure tmux commands: no shell, fully synchronous.
prefix_key=$(get_tmux_option "@tubular_prefix_key" "")
if [ -n "$prefix_key" ]; then
  tmux set-option -g prefix None
  tmux bind-key -n "$prefix_key" 'switch-client -T prefix ; refresh-client'
  tmux bind-key -T prefix Any 'refresh-client'
fi
