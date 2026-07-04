# Tubular TMux

A tmux status-line theme where **the plugin owns the color and you own the text.**

Tubular lights up your entire status line — and your pane borders — with the
current **mode** color: pink while the prefix is held, white in copy mode, blue
when a pane is zoomed, dark otherwise. It does this by setting every `*-style`
option to a live, mode-reactive color, so whatever text is already in your
status line (yours, tmux's defaults, or tubular's bundled look) automatically
inherits the right color on every redraw.

Everything in the draw path is a pure tmux **format string**. No shell runs at
render time — ever — so the bar and borders can never lag behind the real mode.

## Requirements

- tmux 3.0+
- bash (macOS's bash 3.2 is fine)
- a [Nerd Font](https://www.nerdfonts.com/) for the default icons (optional)

## Installation

### Via TPM (recommended)

```tmux
set -g @plugin 'dabstractor/tubular-tmux'
```

Then `prefix` + <kbd>I</kbd>.

### Manual

```bash
git clone https://github.com/dabstractor/tubular-tmux ~/.tmux/plugins/tubular-tmux
```

```tmux
run-shell ~/.tmux/plugins/tubular-tmux/tubular.tmux
```

---

## Quick start: which one are you?

Tubular **always** paints the whole status line with the current mode color.
You only decide **who provides the text.** There are three ways to use it —
pick the one that sounds like you and skip the rest until you want more.

### A. "Leave my status line alone." *(the default)*

You already have a `status-left` / `status-right` / window list you like. Just
add the plugin and tell it your prefix key — your text stays exactly where it
is, and lights up with the mode colors on top.

```tmux
set -g prefix C-Space
set -g @tubular_prefix_key "C-Space"      # MUST match your prefix (see below)
set -g @plugin 'dabstractor/tubular-tmux'
```

That's the whole config. Nothing you already have is overwritten. Press your
prefix and watch the whole bar — your own text included — turn pink.

### B. "Give me the bundled look."

You want tubular's pills, rounded caps, and pane-count icons out of the box.

```tmux
set -g prefix C-Space
set -g @tubular_prefix_key "C-Space"
set -g @tubular_manage_content on
set -g @plugin 'dabstractor/tubular-tmux'
```

`@tubular_manage_content on` makes tubular fill any status slot you haven't
customized with its bundled content.

### C. "My own text, your colors."

You want custom status text that snaps to the theme and tracks the mode, with
none of the `#{E:...}` ceremony. Set the text **per slot** and use the
`{{token}}` shortcuts for theme colors:

```tmux
set -g prefix C-Space
set -g @tubular_prefix_key "C-Space"

# custom left: a green dot, then snap back to the mode color, then the session
set -g @tubular_status_left_text  "#S #[fg={{copy}}]●#[default] "
# custom right: zoom indicator + pane count (only when zoomed), path, clock
set -g @tubular_status_right_text "#{?window_zoomed_flag,{{zoom_indicator}}#{window_panes} , }#{b:pane_current_path} 󰃰 %I:%M"
# keep tubular's pill-styled window list
set -g @tubular_window_tab_text " #W "

set -g @plugin 'dabstractor/tubular-tmux'
```

A slot whose `@tubular_*_text` you **set** is always rendered by tubular (with
tokens expanded). A slot you **don't** set is left to your own native value —
or, if you also turn on `@tubular_manage_content`, to the bundled default.

> **How the decision is made, per slot** (status-left, status-right, window tab):
> 1. You set `@tubular_<slot>_text` → tubular renders it (tokens expanded). ✅
> 2. Else if `@tubular_manage_content` is `on` → tubular renders the bundled default.
> 3. Else → your native value is left completely untouched.

---

## Theme color reference

When you write your own status text (bucket C), you can reach into the theme
two ways: the **`{{token}}` shortcuts** (easy) or the **raw variables**
(power). Either works inside `@tubular_status_left_text`,
`@tubular_status_right_text`, and `@tubular_window_tab_text`.

### The easy way: `{{token}}` shortcuts

Write a token and tubular expands it to the correct tmux snippet **once, at
load time** — so tmux only ever sees a normal format string (no shell at render
time). You never have to think about which variables are dynamic:

| Token | Expands to | What it is |
|---|---|---|
| `{{mode_bg}}` `{{mode_fg}}` | the current mode's bg / fg | **dynamic** — changes with the mode |
| `{{pill_bg}}` `{{pill_fg}}` `{{icon_fg}}` | pill / icon colors | **dynamic** |
| `{{prefix}}` `{{copy}}` `{{zoom}}` `{{active}}` | those mode palette colors | static `#rrggbb` |
| `{{bg}}` `{{bg_max}}` `{{bg_min}}` | background palette | static |
| `{{fg}}` `{{fg_active}}` `{{fg_focus}}` | foreground palette | static |
| `{{neutral_visible}}` `{{neutral_hidden}}` | subdued / faint text | static |
| `{{zoom_indicator}}` | the zoom indicator char, only when zoomed | convenience widget |

```tmux
# a copy-colored dot that's the same green in every mode, then back to theme:
set -g @tubular_status_left_text "#S #[fg={{copy}}]●#[default] "
```

### The `#[default]` trick (no token needed)

The single most useful coloring primitive needs **no token at all**: paint a
word, then `#[default]` snaps the rest of the segment back to the current mode
color — dynamically, with no variable reference.

```tmux
# red ALERT, then the rest snaps back to whatever the current mode is:
set -g @tubular_status_left_text "#[fg=red]ALERT#[default] #S "
```

This works because every segment's `*-style` is set to the mode colors, so
`#[default]` always means "back to the theme."

### The power way: raw variables (and the `E:` rule)

You can also reference the variables directly. There is **one rule that bites
everyone**: the dynamic variables hold a *conditional*, so they must be
force-expanded with `#{E:…}`. Static palette colors are plain `#rrggbb` and
take **no** `E:`.

```tmux
# DYNAMIC  → MUST use E:  (this is the #1 footgun)
#[fg=#{E:@tubular_mode_fg}]     ✅ resolves to the live mode fg
#[fg=#{@tubular_mode_fg}]       ❌ renders the raw conditional as garbage

# STATIC    → no E: needed
#[fg=#{@tubular_copy_color}]    ✅ plain #98bb6c
```

The dynamic variables are `@tubular_mode_bg`, `@tubular_mode_fg`,
`@tubular_pill_bg`, `@tubular_pill_fg`, `@tubular_icon_fg`. Everything else in
the configuration list below is a static literal. **If you'd rather not
remember this, just use the `{{token}}` shortcuts above — they handle it for
you.**

---

## Bring your own status line

The combination that lets you keep a fully custom status line *and* get the
mode effects is: leave `@tubular_manage_content` off (the default), set the
`@tubular_*_text` options for whichever slots you want tubular to render, and
let the rest fall through to your native tmux values.

```tmux
set -g @tubular_manage_content off          # don't clobber anything by default
set -g @tubular_status_left_text  "#S #[fg={{copy}}]●#[default] "
set -g @tubular_status_right_text "󰃰 %I:%M"
# window-status-format and separator stay as YOUR native values
```

A seamless, fully mode-reactive custom segment:

```tmux
# three dots while the prefix is held; otherwise a mode-colored dot + session
set -g @tubular_status_left_text "\
#{?client_prefix,\
●#[fg={{copy}}]●#[fg={{mode_fg}}]●,\
#[fg=#{?pane_in_mode,{{mode_fg}},{{copy}}}]● #[fg={{mode_fg}}]}\
 #S "
```

---

## Window alerts (activity & bell)

tubular styles the two per-window alert states tmux tracks — but only your
**window list** shows them (never status-left/right), and only when more than
one window is open.

- **Activity** — a window you're not viewing produced output. Its tab text
  turns brighter so you notice it. Window flag: `#`.
- **Bell** — a window received a bell character (`\a`) — e.g. a build finished
  or a REPL wants input. Its tab gets the same brighter text **plus a bell
  glyph ()** in the icon spot, so you can tell a real bell apart from plain
  activity even with only two tabs. Window flag: `!`.

Both styles are mode-aware: the brighter text shows on the dark **normal** bar
(where it reads as a clear cue), and snaps back to the mode's normal text color
on the bright **prefix/copy/zoom** bars — so an alert is never invisible
(white-on-white). The bell glyph rides along, so it's visible in every mode.

Turn the monitors on (activity is off by default in tmux):

```tmux
setw -g monitor-activity on
setw -g monitor-bell on
```

Ring a bell yourself to try it, from any pane:

```bash
printf '\a'
```

A styled tab persists until you select that window (that's tmux clearing the
alert once you've seen it). The bell glyph is configurable:

```tmux
set -g @tubular_bell_icon "󰂚"   # any glyph; default is the Nerd Font bell
```

> **Where did that bell come from?** Bells originate from a pane writing `\a` —
> a finishing build, a chat client, a REPL prompting, etc. — not from tubular.
> To find the culprit at any moment:
> ```bash
> tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name} bell=#{window_bell_flag}'
> ```

---

## Configuration reference

All options are set **before** the plugin loads. Colors are `#rrggbb`.

### The content switch

```tmux
set -g @tubular_manage_content off   # default. colors only; your text is king.
# set to `on` to also get tubular's bundled content for any unset slot.
```

### Mode colors (the ones that light up the bar)

```tmux
set -g @tubular_prefix_color "#d9c1a6"   # bar bg while prefix is active
set -g @tubular_copy_color   "#3d7ba9"   # bar bg in copy/selection mode
set -g @tubular_zoom_color   "#e1cc79"   # bar bg when the pane is zoomed
set -g @tubular_active_color "#a2c9d7"   # active border / current-tab pill

# optional: text color on the lit-up bar (defaults to @tubular_bg)
set -g @tubular_prefix_fg "#1f1f28"
set -g @tubular_copy_fg   "#1f1f28"
set -g @tubular_zoom_fg   "#1f1f28"
```

Priority when more than one applies: **prefix > copy > zoom > normal.**

### Background & foreground palette

```tmux
set -g @tubular_bg              "#1f1f28"  # main background
set -g @tubular_bg_max          "#181822"  # darker (the resting status bar)
set -g @tubular_bg_min          "#24242e"  # lighter
set -g @tubular_fg              "#dcd7ba"  # main text
set -g @tubular_fg_active       "#cde4ed"  # active window text
set -g @tubular_fg_focus        "#dddddd"  # focused text
set -g @tubular_neutral_visible "#787878"  # subdued UI (time, paths)
set -g @tubular_neutral_hidden  "#54546d"  # faint indicators (pane counts)
```

### Content (used when tubular manages a slot)

```tmux
set -g @tubular_status_left_text  " #S  "
set -g @tubular_status_right_text "  󰃰  %I:%M  "
set -g @tubular_window_tab_text   " #W "
set -g @tubular_separator "   "     # between inactive window tabs
set -g @tubular_tab_start  ""       # cap before the current-window pill (Powerline rounded)
set -g @tubular_tab_end    ""       # cap after  the current-window pill (Powerline rounded)
set -g @tubular_zoom_indicator "+"
```

#### Tab caps (the rounded pill around the current window)

`@tubular_tab_start` and `@tubular_tab_end` wrap the current-window tab to
give it its pill shape. The defaults are the Powerline **rounded** half-circles
(`U+E0B6` / `U+E0B4` — `` / ``), which need a [Nerd Font][] to render.

To use the **sharp** Powerline caps instead:

```tmux
set -g @tubular_tab_start ""   # U+E0B0
set -g @tubular_tab_end   ""   # U+E0B2
```

To use **square** caps:

```tmux
set -g @tubular_tab_start ""   # U+E0BC
set -g @tubular_tab_end   ""   # U+E0BE
```

To go back to a **flat** tab (no caps at all), set them to empty strings:

```tmux
set -g @tubular_tab_start ""
set -g @tubular_tab_end   ""
```

Only the current window is wrapped — inactive tabs always sit flat between
`@tubular_separator`, regardless of the caps.

[nerd font]: https://www.nerdfonts.com/

### Icons (Nerd Font glyphs, 10 chars for indices/counts 1–10)

```tmux
set -g @tubular_pane_icons   "󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘"
set -g @tubular_window_icons "󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞"
# circled alternatives:
# set -g @tubular_pane_icons   "①②③④⑤⑥⑦⑧⑨⑩"
# set -g @tubular_window_icons "❶❷❸❹❺❼❽❾❿"
```

### Pane borders

`pane-border-lines` cannot be a format, so the line style is fixed at load
time; only colors and bold change per mode.

```tmux
set -g @tubular_normal_border_lines "single"   # single|double|heavy|simple|number|rounded
set -g @tubular_normal_extra_bold "0"          # fill inactive border bg (0/1)
set -g @tubular_active_extra_bold "1"          # active pane, normal/zoom
set -g @tubular_prefix_extra_bold "1"          # active pane, prefix (cascades from active)
set -g @tubular_copy_extra_bold   "0"          # active pane, copy   (cascades from active)
```

---

## How it works

### Mode highlighting

Tubular detects the active window's state on every redraw from inside the
format strings themselves — no shell, no cached state:

- **prefix** — `client_prefix`
- **copy** — `#{==:#{W:#{?window_active,#{pane_in_mode},}},1}` (scans the window list so any tab being rendered can read the *active* window's mode)
- **zoom** — `#{m:*Z*,#{W:#{?window_active,#{window_flags},}}}`

The whole bar becomes one solid block of the mode color because `status-style`
and every per-segment `*-style` are set to that color, and segments that don't
declare their own `#[fg=/bg=]` inherit it.

### Why no shell at render time

Earlier versions shelled out for centering and mode detection; the async jank
against tmux's synchronous format expansion was visible. Everything drawn here
is now a pure tmux format. The `{{token}}` shortcuts are expanded **once**, in
bash, when the plugin loads — by render time they're already plain tmux format.
`run-shell` / `#(...)` in a status format is never used.

---

## Theme gallery

### Tokyo Night

```tmux
set -g @tubular_prefix_color "#bb9af7"
set -g @tubular_copy_color   "#9ece6a"
set -g @tubular_zoom_color   "#e0af68"
set -g @tubular_active_color "#7aa2f7"
set -g @tubular_bg "#1a1b26" ; set -g @tubular_bg_max "#16161e"
set -g @tubular_fg "#c0caf5"
set -g @tubular_neutral_visible "#565f89" ; set -g @tubular_neutral_hidden "#3b4261"
```

### Catppuccin Mocha

```tmux
set -g @tubular_prefix_color "#f5c2e7"
set -g @tubular_copy_color   "#a6e3a1"
set -g @tubular_zoom_color   "#f9e2af"
set -g @tubular_active_color "#89b4fa"
set -g @tubular_bg "#1e1e2e" ; set -g @tubular_bg_max "#11111b"
set -g @tubular_fg "#cdd6f4"
set -g @tubular_neutral_visible "#7f849c" ; set -g @tubular_neutral_hidden "#45475a"
```

### Minimal monochrome

```tmux
set -g @tubular_prefix_color "#ffffff"
set -g @tubular_copy_color   "#d0d0d0"
set -g @tubular_zoom_color   "#b0b0b0"
set -g @tubular_active_color "#c0c0c0"
set -g @tubular_bg "#0a0a0a" ; set -g @tubular_fg "#e0e0e0"
set -g @tubular_neutral_visible "#808080" ; set -g @tubular_neutral_hidden "#404040"
```

### Solarized Dark

```tmux
set -g @tubular_prefix_color "#d33682"
set -g @tubular_copy_color   "#859900"
set -g @tubular_zoom_color   "#b58900"
set -g @tubular_active_color "#268bd2"
set -g @tubular_bg "#002b36" ; set -g @tubular_bg_max "#073642"
set -g @tubular_fg "#839496"
set -g @tubular_neutral_visible "#586e75" ; set -g @tubular_neutral_hidden "#073642"
```

---

## Troubleshooting

### Colors not applying

Set options **before** the plugin loads:

```tmux
set -g @tubular_prefix_key "C-b"
set -g @tubular_prefix_color "#d27e99"
# ...then...
set -g @plugin 'dabstractor/tubular-tmux'
```

Reload with `tmux source ~/.tmux.conf`.

### Prefix highlighting not working

Prefix highlighting requires `@tubular_prefix_key`, and it **must match your
tmux `prefix`** — the plugin sets `prefix None` and rebinds the key itself, so a
mismatch means the highlight never fires (or your prefix stops working):

```tmux
set -g prefix C-Space                # your tmux prefix
set -g @tubular_prefix_key "C-Space" # tell tubular the same key
```

This is not auto-detected: once the plugin takes the key over, the original
prefix can't be read back on reload, so it must be stated explicitly.

### My `status-bg` / `status-fg` seem to fight the mode colors

They do — the legacy `status-bg`/`status-fg` silently override `status-style`
and pin the bar. Tubular unsets them on load; make sure nothing in your own
config sets them afterward.

### Icons not displaying

Install a Nerd Font and set it in your terminal emulator.

---

## License

MIT
