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
# Static color tokens point at the RESOLVED internal copies (@_tubular_*),
# not the user input options: input options are unset when the palette comes
# from @tubular_theme, but the internals always hold the final colors.
__tubular_tok_values=(
  '#{E:@tubular_mode_bg}'      '#{E:@tubular_mode_fg}'
  '#{E:@tubular_pill_bg}'      '#{E:@tubular_pill_fg}'       '#{E:@tubular_icon_fg}'
  '#{@_tubular_prefix_color}'   '#{@_tubular_copy_color}'
  '#{@_tubular_zoom_color}'     '#{@_tubular_active_color}'
  '#{@_tubular_bg}'             '#{@_tubular_bg_max}'          '#{@_tubular_bg_min}'
  '#{@_tubular_fg}'             '#{@_tubular_fg_active}'       '#{@_tubular_fg_focus}'
  '#{@_tubular_neutral_visible}' '#{@_tubular_neutral_hidden}'
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
# Built-in Themes
# ---------------------------------------------------------------------------
# @tubular_theme picks a complete default palette (and a matching style
# character — border weight, mode boldness) with ONE option. Precedence is
# strictly layered: any @tubular_* option you set explicitly always wins; the
# theme only replaces the plugin's built-in defaults underneath it.
#
# Themes are FILES: themes/<name>.theme, bash-sourced ONCE at load time
# (never in the render path). A theme file assigns th_* variables and only
# needs to define what it changes — anything it omits inherits the kanagawa
# base below. @tubular_theme accepts either a bare name (resolved against the
# plugin's themes/ directory) or a path containing a "/" (leading ~ expands),
# so ANY theme can be dropped in without touching the plugin. To generate a
# theme file from any tinted-theming/base16 scheme, see
# scripts/theme-import-base16.sh.
#
# Palette rules every bundled preset follows:
#   * Colors are CANONICAL values from the named scheme — no approximations.
#   * Zoom is only ever seen on a screen by itself (the zoomed pane fills it),
#     so when two accents look alike (orange/yellow, blue/cyan) the look-alike
#     goes on zoom; prefix/copy/normal keep the highest mutual contrast.
#   * The scheme's most NEUTRAL accent goes on the default pane border
#     (active), freeing the popping colors for the modes.
#   * Thin borders in normal mode always pair with fat (extra-bold) borders
#     in prefix mode, so the mode change reads even without the status bar.

__TUBULAR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

__tubular_load_theme() {
  local name="$1" file
  # kanagawa base: the default palette, and the fallback every partial theme
  # file inherits from — ink-wash sumi backgrounds, crystalBlue border (the
  # calm accent), violet/yellow contrast, aqua on zoom.
  # (themes/kanagawa.theme mirrors these values; keep them in sync.)
  th_bg="#1f1f28"; th_bg_max="#16161d"; th_bg_min="#2a2a37"
  th_copy_pane_bg="#14141b"   # copy-mode pane bg (bg_max nudged down ~2/ch)
  th_fg="#dcd7ba"; th_fg_active="#dcd7ba"; th_fg_focus="#dcd7ba"
  th_neutral_visible="#727169"; th_neutral_hidden="#54546d"
  th_zoom="#7aa89f"; th_copy="#e6c384"; th_prefix="#957fb8"; th_active="#7e9cd8"
  th_border_lines="single"; th_normal_xb="0"; th_active_xb="0"
  th_prefix_xb="1"; th_copy_xb="0"

  [ "$name" = "onedark" ] && name="one-dark"
  case "$name" in
    */*) file="${name/#\~/$HOME}" ;;                 # explicit path
    *)   file="$__TUBULAR_DIR/themes/$name.theme" ;; # bundled / dropped-in
  esac
  if [ -f "$file" ]; then
    . "$file"
  elif [ "$name" != "kanagawa" ]; then
    tmux display-message "tubular: theme '$name' not found, using kanagawa"
  fi
}

# ---------------------------------------------------------------------------
# Read options
# ---------------------------------------------------------------------------

# === Theme (defaults provider) ===
theme=$(get_tmux_option "@tubular_theme" "kanagawa")
__tubular_load_theme "$theme"

# === Read Color Options (explicit user options beat the theme) ===
bg=$(get_tmux_option "@tubular_bg" "$th_bg")
bg_max=$(get_tmux_option "@tubular_bg_max" "$th_bg_max")
bg_min=$(get_tmux_option "@tubular_bg_min" "$th_bg_min")
fg=$(get_tmux_option "@tubular_fg" "$th_fg")
fg_active=$(get_tmux_option "@tubular_fg_active" "$th_fg_active")
fg_focus=$(get_tmux_option "@tubular_fg_focus" "$th_fg_focus")
neutral_visible=$(get_tmux_option "@tubular_neutral_visible" "$th_neutral_visible")
neutral_hidden=$(get_tmux_option "@tubular_neutral_hidden" "$th_neutral_hidden")

# Mode-specific colors - THE ONLY COLORS THAT MATTER
zoom_color=$(get_tmux_option "@tubular_zoom_color" "$th_zoom")
copy_color=$(get_tmux_option "@tubular_copy_color" "$th_copy")
prefix_color=$(get_tmux_option "@tubular_prefix_color" "$th_prefix")
active_color=$(get_tmux_option "@tubular_active_color" "$th_active")

# Mode-specific foreground colors (default to @tubular_bg)
prefix_fg=$(get_tmux_option "@tubular_prefix_fg" "$bg")
zoom_fg=$(get_tmux_option "@tubular_zoom_fg" "$bg")
copy_fg=$(get_tmux_option "@tubular_copy_fg" "$bg")

# Per-mode PANE interior colors. The focused pane recolors in each mode
# (normal / copy / prefix / zoom), kept live by re-setting window-active-style
# on every mode change (pane-mode-changed + window-layout-changed hooks — see
# below) since that style caches its format at set-time. Distinct from the
# status-bar mode colors above: @tubular_*_color / @tubular_*_fg paint the BAR;
# these paint the pane you read on. Defaults preserve the built-in look; set any
# pair to override.
#   normal -> @tubular_bg / @tubular_fg
#   copy   -> the theme's copy_pane_bg (a subtle dim: bg_max nudged down) /
#             @tubular_fg_focus (brighter)
#   zoom   -> @tubular_bg / @tubular_fg
# Prefix has no pane color — client_prefix is per-client, but the pane interior
# is shared; see the window-active-style comment.
copy_pane_bg=$(get_tmux_option "@tubular_copy_pane_bg" "$th_copy_pane_bg")
copy_pane_fg=$(get_tmux_option "@tubular_copy_pane_fg" "$fg_focus")
normal_pane_bg=$(get_tmux_option "@tubular_normal_pane_bg" "$bg")
normal_pane_fg=$(get_tmux_option "@tubular_normal_pane_fg" "$fg")
zoom_pane_bg=$(get_tmux_option "@tubular_zoom_pane_bg" "$bg")
zoom_pane_fg=$(get_tmux_option "@tubular_zoom_pane_fg" "$fg")

# === Pane background ===
# on     (default): paint ALL panes — @tubular_bg_max on inactive, @tubular_bg
#                   on active — for a fully opaque, theme-matched look.
# active          : paint ONLY the focused pane (@tubular_bg); inactive panes
#                   stay transparent so the terminal background shows through.
# off             : paint NO panes — full transparency everywhere.
# Transparency comes from your terminal, not tmux; this switch decides which
# panes tmux covers up.
pane_bg=$(get_tmux_option "@tubular_pane_bg" "on")
case "$pane_bg" in
  on|yes|true|1|all)          pane_bg="on" ;;
  active|focused|active-only) pane_bg="active" ;;
  *)                         pane_bg="off" ;;
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
zoom_indicator=$(get_tmux_option "@tubular_zoom_indicator" " ")
bell_icon=$(get_tmux_option "@tubular_bell_icon" "")

# === Read Border Style Options ===
# Note: pane-border-lines cannot be a format, so the line style is static
# (@tubular_normal_border_lines). Only colors/bold change per mode.
# Defaults come from the theme's style character (see __tubular_apply_theme).
normal_border_lines=$(get_tmux_option "@tubular_normal_border_lines" "$th_border_lines")
normal_extra_bold=$(get_tmux_option "@tubular_normal_extra_bold" "$th_normal_xb")
active_extra_bold=$(get_tmux_option "@tubular_active_extra_bold" "$th_active_xb")
# prefix/copy cascade: explicit option > user-set active bold > theme value.
# (If the user set active_extra_bold themselves, prefix/copy follow it like
# they always have; otherwise the theme's per-mode character applies.)
if __tubular_is_set "@tubular_active_extra_bold"; then
  th_prefix_xb="$active_extra_bold"
  th_copy_xb="$active_extra_bold"
fi
prefix_extra_bold=$(get_tmux_option "@tubular_prefix_extra_bold" "$th_prefix_xb")
copy_extra_bold=$(get_tmux_option "@tubular_copy_extra_bold" "$th_copy_xb")

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

# Foreground for an activity/bell tab and the bell glyph: bright (@_tubular_fg,
# the resolved palette) on the dark NORMAL bar so the alert reads, but the dark
# mode fg on the bright PREFIX/COPY/ZOOM bars — white-on-white would be
# invisible there. NB: must read @_tubular_fg (always set), NOT @tubular_fg
# (the user-input option, unset when the palette comes from @tubular_theme —
# which would make alert_fg blank and silently drop the highlight).
alert_fg="#{?$any_mode,#{E:@tubular_mode_fg},#{@_tubular_fg}}"

# Store for use in styles/formats via #{E:...} and for user content strings.
# These are the PUBLIC dynamic color variables (reference with #{E:...}).
tmux set-option -g @tubular_mode_bg "$mode_bg"
tmux set-option -g @tubular_mode_fg "$mode_fg"
tmux set-option -g @tubular_pill_bg "$pill_bg"
tmux set-option -g @tubular_pill_fg "$pill_fg"
tmux set-option -g @tubular_icon_fg "$icon_fg"

# Resolved static palette copies — the FINAL colors after layering the theme
# and any explicit @tubular_* input options. Used inside this plugin's own
# formats, targeted by the {{token}} shortcuts, and the documented reference
# for static colors in user formats (input options are unset when the palette
# comes from @tubular_theme, so they can't serve that role).
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
tmux set-option -g @_tubular_normal_pane_bg "$normal_pane_bg"
tmux set-option -g @_tubular_normal_pane_fg "$normal_pane_fg"
tmux set-option -g @_tubular_copy_pane_bg "$copy_pane_bg"
tmux set-option -g @_tubular_copy_pane_fg "$copy_pane_fg"
tmux set-option -g @_tubular_zoom_pane_bg "$zoom_pane_bg"
tmux set-option -g @_tubular_zoom_pane_fg "$zoom_pane_fg"

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

tmux set-option -g message-style "fg=$bg,bg=$active_color,align=centre"
tmux set-option -g message-command-style "fg=$bg,bg=$active_color,align=centre"

tmux set-window-option -g clock-mode-colour "$active_color"
tmux set-window-option -g mode-style "fg=$fg,bg=$copy_color,bold"

# Pane interiors: foreground is always themed (dimmer on inactive panes).
# The background depends on @tubular_pane_bg:
#   on     -> every pane painted (active = @tubular_bg, inactive = @tubular_bg_max)
#   active -> only the focused pane painted; inactive panes stay transparent
#   off    -> no pane painted; full transparency
# The active pane reacts to the mode like the status bar and borders — BUT
# window-active-style is the one style tmux does NOT re-evaluate per redraw:
# it caches the format at the moment the option is SET, so the conditionals
# below would otherwise freeze at whatever the mode was at load. status-style
# and pane-active-border-style are dynamic; window-active-style is not. To
# keep it live we re-set this option on every mode change (pane-mode-changed
# hook + the prefix key bindings, both installed later), reusing this same
# template, expanded against the live palette + mode at fire time.
# copy / zoom / normal are driven by pane_in_mode / window_zoomed_flag here,
# re-applied by the pane-mode-changed + window-layout-changed hooks (the mode
# change itself redraws the pane, picking up the new template).
#   copy mode -> @tubular_copy_pane_*   (darker bg, brighter fg)
#   zoom      -> @tubular_zoom_pane_*
#   normal    -> @tubular_normal_pane_*
# Prefix is intentionally NOT here: client_prefix is PER-CLIENT, but the pane
# interior is shared across clients, so a #{?client_prefix,...} in
# window-active-style stores but never paints. Pair that with the set-time
# caching (no re-eval on redraw) and the absence of any hook that fires on
# prefix-table exit, and a binding-based swap can't be restored reliably
# (bound prefix commands bypass it; the color sticks). So the pane interior
# does not react to prefix — the border and status bar do (dynamic styles).
active_style_tmpl="fg=#{?pane_in_mode,#{@_tubular_copy_pane_fg},#{?window_zoomed_flag,#{@_tubular_zoom_pane_fg},#{@_tubular_normal_pane_fg}}}"
[ "$pane_bg" != "off" ] && active_style_tmpl="$active_style_tmpl,bg=#{?pane_in_mode,#{@_tubular_copy_pane_bg},#{?window_zoomed_flag,#{@_tubular_zoom_pane_bg},#{@_tubular_normal_pane_bg}}}"
case "$pane_bg" in
  on) tmux set-option -g window-style "fg=$neutral_visible,bg=$bg_max" ;;
  *)  tmux set-option -g window-style "fg=$neutral_visible" ;;
esac
tmux set-option -g window-active-style "$active_style_tmpl"

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
#
# status-{left,right}-length belong to the TEXT layer are only set if tubular
# is the one that "owns" the content, otherwise we would incorrectly overwrite
# the user config

# status-left
if __tubular_resolve_content "@tubular_status_left_text" " #S  "; then
  tmux set-option -g status-left-length 100
  tmux set-option -g status-left "#[fg=#{E:@tubular_mode_fg},bg=#{E:@tubular_mode_bg},nobold]$__TUBULAR_RESOLVED"
fi

# status-right
if __tubular_resolve_content "@tubular_status_right_text" "  󰃰  %I:%M  "; then
  tmux set-option -g status-right-length 150
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
# Re-apply the mode-reactive window-active-style on copy/zoom changes. It
# caches its format at set-time (no re-eval on redraw), so the option must be
# re-set when the mode flips: pane-mode-changed covers copy, window-layout-changed
# covers zoom (it fires on the zoom toggle). Prefix is deliberately not handled
# here — see the window-active-style comment for why it can't be done reliably.
# Pure tmux, no shell at render.
tmux set-hook -g pane-mode-changed "set-option -g window-active-style \"$active_style_tmpl\""
tmux set-hook -g window-layout-changed "set-option -g window-active-style \"$active_style_tmpl\""
if [ -n "$prefix_key" ]; then
  tmux set-option -g prefix None
  tmux bind-key -n "$prefix_key" 'switch-client -T prefix ; refresh-client'
  tmux bind-key -T prefix Any 'refresh-client'
fi
