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
#
# Ownership model: TUBULAR OWNS THE COLOR, YOU OWN THE TEXT.
#   * Every *-style option is set to the live mode colors, so the whole bar
#     (and anything you don't explicitly recolor) lights up pink/white/blue/
#     dark per mode automatically — including your own native status content.
#   * The TEXT options (status-left, status-right, window list) are only set
#     by tubular when you ask it to (see @tubular_manage_content below).
#   * For custom-colored segments, use the {{token}} shortcuts (expanded once
#     at load time here) or the raw @tubular_* variables — see README.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Read a tmux option with a default (empty/unset → default).
get_tmux_option() {
  local option="$1"
  local default="$2"
  local value
  value=$(tmux show-option -gqv "$option")
  [ -n "$value" ] && echo "$value" || echo "$default"
}

# Is a user option explicitly set? show-options errors (exit 1) on unknown /
# unset options, and succeeds (exit 0) even when the option is set to "" — so
# this reliably distinguishes "user set it" from "user left it alone".
__tubular_is_set() {
  tmux show-options -g "$1" >/dev/null 2>&1
}

# --- Token preprocessor (load-time ONLY) ----------------------------------
# User content strings (@tubular_status_left_text etc.) may contain {{token}}
# shortcuts that expand here to the correct tmux format snippet. This runs
# ONCE, in bash, at load time. The string handed to set-option is a plain tmux
# format — so NO shell ever runs at render time. Dynamic tokens (mode/pill/
# icon) inject the required #{E:...}, so users never have to reason about the
# E: distinction: the token always does the right thing.
__tubular_tok_names=(
  mode_bg mode_fg pill_bg pill_fg icon_fg
  prefix copy zoom active
  bg bg_max bg_min fg fg_active fg_focus
  neutral_visible neutral_hidden
  zoom_indicator
)
__tubular_tok_values=(
  '#{E:@tubular_mode_bg}'      '#{E:@tubular_mode_fg}'
  '#{E:@tubular_pill_bg}'      '#{E:@tubular_pill_fg}'       '#{E:@tubular_icon_fg}'
  '#{@tubular_prefix_color}'   '#{@tubular_copy_color}'
  '#{@tubular_zoom_color}'     '#{@tubular_active_color}'
  '#{@tubular_bg}'             '#{@tubular_bg_max}'          '#{@tubular_bg_min}'
  '#{@tubular_fg}'             '#{@tubular_fg_active}'       '#{@tubular_fg_focus}'
  '#{@tubular_neutral_visible}' '#{@tubular_neutral_hidden}'
  '#{?window_zoomed_flag,#{@tubular_zoom_indicator},}'
)
__tubular_expand_tokens() {
  local s="$1" i name val pat
  for i in "${!__tubular_tok_names[@]}"; do
    name="${__tubular_tok_names[$i]}"
    val="${__tubular_tok_values[$i]}"
    pat="{{${name}}}"
    s="${s//$pat/$val}"
  done
  printf '%s' "$s"
}

# Resolve a content slot. Sets __TUBULAR_RESOLVED (token-expanded text) and
# returns 0 if tubular should manage the slot, 1 if the native tmux option
# should be left untouched. Priority:
#   1) user explicitly set @tubular_<slot>_text  -> use it (token-expanded)
#   2) @tubular_manage_content == on             -> use the bundled default
#   3) otherwise                                 -> leave native (return 1)
__tubular_resolve_content() {
  local user_opt="$1" default_val="$2" raw
  if __tubular_is_set "$user_opt"; then
    raw=$(tmux show-option -gqv "$user_opt")
    __TUBULAR_RESOLVED=$(__tubular_expand_tokens "$raw")
    return 0
  elif [ "$__tubular_manage_content" = "on" ]; then
    __TUBULAR_RESOLVED=$(__tubular_expand_tokens "$default_val")
    return 0
  else
    __TUBULAR_RESOLVED=""
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Read options
# ---------------------------------------------------------------------------

# === Read Color Options ===
bg=$(get_tmux_option "@tubular_bg" "#1f1f28")
bg_max=$(get_tmux_option "@tubular_bg_max" "#181822")
bg_min=$(get_tmux_option "@tubular_bg_min" "#24242e")
fg=$(get_tmux_option "@tubular_fg" "#dcd7ba")
fg_active=$(get_tmux_option "@tubular_fg_active" "#cde4ed")
fg_focus=$(get_tmux_option "@tubular_fg_focus" "#dddddd")
neutral_visible=$(get_tmux_option "@tubular_neutral_visible" "#787878")
neutral_hidden=$(get_tmux_option "@tubular_neutral_hidden" "#54546d")

# Mode-specific colors - THE ONLY COLORS THAT MATTER
zoom_color=$(get_tmux_option "@tubular_zoom_color" "#3d7ba9")
copy_color=$(get_tmux_option "@tubular_copy_color" "#e1cc79")
prefix_color=$(get_tmux_option "@tubular_prefix_color" "#d9c1a6")
active_color=$(get_tmux_option "@tubular_active_color" "#a2c9d7")

# Mode-specific foreground colors (default to @tubular_bg)
prefix_fg=$(get_tmux_option "@tubular_prefix_fg" "$bg")
zoom_fg=$(get_tmux_option "@tubular_zoom_fg" "$bg")
copy_fg=$(get_tmux_option "@tubular_copy_fg" "$bg")

# === Pane background ===
# on (default): paint the pane background with @tubular_bg_max (inactive) and
#               @tubular_bg (active) for a fully opaque, theme-matched look.
# off         : only set pane FOREGROUND colors — the terminal's own background
#               (or transparency / bg-image) shows through.
# Transparency comes from your terminal, not tmux; this switch just decides
# whether tmux covers it up.
pane_bg=$(get_tmux_option "@tubular_pane_bg" "on")
case "$pane_bg" in
  on|yes|true|1) pane_bg="on" ;;
  *)            pane_bg="off" ;;
esac

# === Read the content-ownership switch ===
# off (default): tubular sets ONLY colors/styles; your native status content
#                shows through, fully mode-colored. (The north star.)
# on           : tubular also provides its bundled content (pills/caps/icons)
#                for any slot whose @tubular_*_text you did not set explicitly.
# A slot whose @tubular_*_text IS set is always managed by tubular (token-
# expanded), regardless of this switch.
__tubular_manage_content=$(get_tmux_option "@tubular_manage_content" "off")
case "$__tubular_manage_content" in
  on|yes|true|1) __tubular_manage_content="on" ;;
  *)             __tubular_manage_content="off" ;;
esac

# === Read Content Decoration Options (used only when tubular manages windows)
separator=$(get_tmux_option "@tubular_separator" "   ")
tab_start=$(get_tmux_option "@tubular_tab_start" "")
tab_end=$(get_tmux_option "@tubular_tab_end" "")

# === Read Icon Options ===
pane_icons=$(get_tmux_option "@tubular_pane_icons" "󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘")
window_icons=$(get_tmux_option "@tubular_window_icons" "󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞")
zoom_indicator=$(get_tmux_option "@tubular_zoom_indicator" "+")
bell_icon=$(get_tmux_option "@tubular_bell_icon" "")

# === Read Border Style Options ===
# Note: pane-border-lines cannot be a format, so the line style is static
# (@tubular_normal_border_lines). Only colors/bold change per mode.
normal_border_lines=$(get_tmux_option "@tubular_normal_border_lines" "single")
normal_extra_bold=$(get_tmux_option "@tubular_normal_extra_bold" "0")
active_extra_bold=$(get_tmux_option "@tubular_active_extra_bold" "0")
# prefix/copy inherit active's bold unless set explicitly (the "cascade")
prefix_extra_bold=$(get_tmux_option "@tubular_prefix_extra_bold" "$active_extra_bold")
copy_extra_bold=$(get_tmux_option "@tubular_copy_extra_bold" "$active_extra_bold")

# ---------------------------------------------------------------------------
# Live Mode Expressions (the core of the plugin)
# ---------------------------------------------------------------------------
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

# Foreground for an activity/bell tab and the bell glyph: bright (@tubular_fg)
# on the dark NORMAL bar so the alert reads, but the dark mode fg on the bright
# PREFIX/COPY/ZOOM bars — white-on-white would be invisible there.
alert_fg="#{?$any_mode,#{E:@tubular_mode_fg},#{@tubular_fg}}"

# Store for use in styles/formats via #{E:...} and for user content strings.
# These are the PUBLIC dynamic color variables (reference with #{E:...}).
tmux set-option -g @tubular_mode_bg "$mode_bg"
tmux set-option -g @tubular_mode_fg "$mode_fg"
tmux set-option -g @tubular_pill_bg "$pill_bg"
tmux set-option -g @tubular_pill_fg "$pill_fg"
tmux set-option -g @tubular_icon_fg "$icon_fg"

# Internal static palette copies (used inside this plugin's own formats; not
# part of the public API — users reference their own @tubular_* input options).
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

# === Icon Options (exposed for the icon-chain formats below) ===
tmux set-option -g @tubular_pane_icons "$pane_icons"
tmux set-option -g @tubular_window_icons "$window_icons"
tmux set-option -g @tubular_zoom_indicator "$zoom_indicator"

# ---------------------------------------------------------------------------
# Base Styling — TUBULAR OWNS ALL THE COLOR HERE
# ---------------------------------------------------------------------------
# Every per-segment *-style is set to the live mode colors. Any segment that
# doesn't declare its own #[fg=/bg=] inherits these, and #[default] snaps back
# to them — uniformly across left, right, and the whole window list. This is
# the base layer that makes the entire bar light up as one solid mode block.
tmux set-option -g status "on"
tmux set-option -g status-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-option -g status-left-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-option -g status-right-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-window-option -g window-status-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-window-option -g window-status-current-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-window-option -g window-status-last-style "fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}"
tmux set-window-option -g window-status-activity-style "fg=$alert_fg,bg=#{E:@tubular_mode_bg}"
tmux set-window-option -g window-status-bell-style "fg=$alert_fg,bg=#{E:@tubular_mode_bg}"

# Back on stock status-format, so the length limits apply again
tmux set-option -g status-left-length 100
tmux set-option -g status-right-length 150

tmux set-option -g message-style "fg=$bg,bg=$active_color,align=centre"
tmux set-option -g message-command-style "fg=$bg,bg=$active_color,align=centre"

tmux set-window-option -g clock-mode-colour "$active_color"
tmux set-window-option -g mode-style "fg=$fg,bg=$copy_color,bold"

# Pane interiors: foreground is always themed (dimmer on inactive panes);
# the background is painted with the theme palette by default (@tubular_pane_bg
# on). Set @tubular_pane_bg off to leave it to the terminal so transparency /
# background images pass through.
if [ "$pane_bg" = "on" ]; then
  tmux set-option -g window-style "fg=$neutral_visible,bg=$bg_max"
  tmux set-option -g window-active-style "fg=#{?pane_in_mode,$fg_focus,$fg},bg=#{?client_prefix,$neutral_hidden,$bg}"
else
  tmux set-option -g window-style "fg=$neutral_visible"
  tmux set-option -g window-active-style "fg=#{?pane_in_mode,$fg_focus,$fg}"
fi

# ---------------------------------------------------------------------------
# Pane Borders
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Inactive-window icon selector (pure tmux glyph lookup)
# ---------------------------------------------------------------------------
# The window's jump index while the prefix is held, otherwise its pane count
# (when more than 1 pane). Strip the first N-1 icons, take the next one.
window_icon_chain='#{?#{==:#{window_index},1},#{=1:#{@tubular_window_icons}},#{?#{==:#{window_index},2},#{=1:#{s/#{=1:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},3},#{=1:#{s/#{=2:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},4},#{=1:#{s/#{=3:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},5},#{=1:#{s/#{=4:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},6},#{=1:#{s/#{=5:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},7},#{=1:#{s/#{=6:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},8},#{=1:#{s/#{=7:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},9},#{=1:#{s/#{=8:#{@tubular_window_icons}}//:#{@tubular_window_icons}}},#{?#{==:#{window_index},0},#{=1:#{s/#{=9:#{@tubular_window_icons}}//:#{@tubular_window_icons}}}, }}}}}}}}}}'
pane_icon_chain='#{?#{==:#{window_panes},1},#{=1:#{@tubular_pane_icons}},#{?#{==:#{window_panes},2},#{=1:#{s/#{=1:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},3},#{=1:#{s/#{=2:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},4},#{=1:#{s/#{=3:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},5},#{=1:#{s/#{=4:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},6},#{=1:#{s/#{=5:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},7},#{=1:#{s/#{=6:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},8},#{=1:#{s/#{=7:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},9},#{=1:#{s/#{=8:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}},#{?#{==:#{window_panes},0},#{=1:#{s/#{=9:#{@tubular_pane_icons}}//:#{@tubular_pane_icons}}}, }}}}}}}}}}'
icon_selector="#{?window_bell_flag,$bell_icon,#{?client_prefix,$window_icon_chain,#{?#{>:#{window_panes},1},$pane_icon_chain, }}}"

# ---------------------------------------------------------------------------
# Status Line Content — YOU OWN THE TEXT
# ---------------------------------------------------------------------------
# Per-slot model (see __tubular_resolve_content): tubular sets a content option
# only if (a) you explicitly set its @tubular_*_text, or (b) manage_content is
# on. Otherwise the option is left untouched, so your own native content shows
# through — fully colored by the *-style base layer above.

# status-left
if __tubular_resolve_content "@tubular_status_left_text" " #S  "; then
  tmux set-option -g status-left "#[fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg},nobold]$__TUBULAR_RESOLVED"
fi

# status-right
if __tubular_resolve_content "@tubular_status_right_text" "  󰃰  %I:%M  "; then
  tmux set-option -g status-right "#[fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg}]$__TUBULAR_RESOLVED"
fi

# Window list (tab text wrapped in the rounded-pill caps; native if unmanaged)
if __tubular_resolve_content "@tubular_window_tab_text" " #W "; then
  tmux set-window-option -g window-status-separator "$separator"
  # Current window: pill with rounded caps sitting on the mode-colored bar
  tmux set-window-option -g window-status-current-format "#[fg=#{E:@tubular_pill_bg},bg=#{E:@tubular_mode_bg},nobold,nounderscore,noitalics]$tab_start#[fg=#{E:@tubular_pill_fg},bg=#{E:@tubular_pill_bg}]$__TUBULAR_RESOLVED#[fg=#{E:@tubular_pill_bg},bg=#{E:@tubular_mode_bg}]$tab_end"
  # Inactive windows: name plus an indicator icon — a bell glyph when the
  # window has a bell flag (so you can tell a bell apart from plain activity,
  # even with only two tabs), else the jump-index under prefix, else its pane
  # count when >1. Leads with #[default] so the tab inherits its *-style (mode
  # colors normally; a brighter fg for activity or a bell) rather than
  # hardcoding them inline — that's what lets activity/bell-style take effect.
  tmux set-window-option -g window-status-format "#[default]$__TUBULAR_RESOLVED#[fg=#{?window_bell_flag,$alert_fg,#{E:@tubular_icon_fg}}]$icon_selector"
fi

# ---------------------------------------------------------------------------
# Clean Up Legacy Machinery (running servers upgrading in place)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Prefix Handling
# ---------------------------------------------------------------------------
# tmux never repaints pane borders when the prefix state changes, and native
# prefix handling preempts root-table bindings, so we own the key entirely:
# prefix is set to None and the key switches tables by hand, then forces a
# repaint. `Any` catches every key with no binding in the prefix table (Escape,
# stray keys, ...) and repaints AFTER the table has reset - this is what
# un-sticks the border. Both are pure tmux commands: no shell, fully sync.
#
# REQUIRED: set @tubular_prefix_key to your tmux prefix (e.g. "C-Space", "C-b").
# It must match the `prefix` you set in tmux, since the plugin takes that key
# over. Auto-detecting it isn't reliable: once the plugin sets prefix to None,
# a reload can no longer read the original key back.
prefix_key=$(get_tmux_option "@tubular_prefix_key" "")
if [ -n "$prefix_key" ]; then
  tmux set-option -g prefix None
  tmux bind-key -n "$prefix_key" 'switch-client -T prefix ; refresh-client'
  tmux bind-key -T prefix Any 'refresh-client'
fi
