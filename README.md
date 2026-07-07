# Tubular TMux

A tmux status-line theme that paints the whole bar and the pane borders with
the color of the mode you're in, so you always know what tmux is about to do
without reading a thing.

https://github.com/user-attachments/assets/a266d00f-a3f8-49ab-a8a0-deb83ed26623

## Why this exists

tmux is modal. At any moment you're in one of a few states (resting, holding
the prefix, in copy mode, or zoomed into a pane), and the difference between
them is the difference between "this keypress runs a command" and "this
keypress scrolls a buffer." tmux doesn't tell you which state you're in, so
you find out by pressing a key and watching the wrong thing happen.

You can patch this with a text indicator (`[PREFIX]`, `[COPY]`) and the habit
of looking at it. That works, but reading costs a slice of attention you were
spending on your work. Color doesn't.

Your peripheral vision picks up color before your focus lands on it, and a
learned color association fires before you can name it: the same reason a
red squiggle reads as "typo" before you've parsed the word, and a green light
gets your foot off the brake before you've finished scanning the
intersection. Tubular turns the whole status line, plus every pane border,
into one large mode signal:

| State        | The whole bar turns |
| ------------- | ------------------- |
| Prefix held  | tan                 |
| Copy mode    | yellow              |
| Pane zoomed  | blue                |
| Resting      | dark                |

Colors shown are the defaults; every one is configurable.

This is the point of the plugin. After a day or two the colors stop being
something you read and start being something you just know. The "wait, am I
in copy mode?" check drops out of your conscious path entirely, because the
already told you, in color, before you reached for the keyboard. That freed-up
attention is the whole reason tubular exists; the rest of this README is about
how to fit it onto your bar.

## What it does

Tubular paints the whole status line and the pane borders with the current
mode color: the prefix color while prefix is held, the copy-mode color in copy
mode, the zoom color when a pane is zoomed, and the resting background
otherwise. It does this by setting every `*-style` option to the live mode
color, so whatever text is already in your status line (yours, tmux's
defaults, or tubular's bundled look) inherits the right color on every redraw.

Everything in the draw path is a tmux format string. No shell runs at render
time, so the bar and borders can never lag behind the real mode.

**The plugin owns the color; you own the text.** Tubular sets the colors and
styles. Your existing `status-left`, `status-right`, and window list keep
their text unless you ask tubular to manage them too (see *Quick start*).

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

## Quick start

Tubular always paints the whole status line with the current mode color. You
only decide who provides the text. There are three ways to use it; pick the
one that fits and skip the rest until you want more.

### A. "Leave my status line alone." _(the default)_

You already have a `status-left` / `status-right` / window list you like. Just
add the plugin and tell it your prefix key; your text stays exactly where it is
and picks up the mode colors on top.

```tmux
set -g prefix C-Space
set -g @tubular_prefix_key "C-Space"      # MUST match your prefix (see below)
set -g @plugin 'dabstractor/tubular-tmux'
```

That's the whole config. Nothing you already have is overwritten. Press your
prefix and the whole bar, your own text included, switches to the prefix
color.

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

You want custom status text that snaps to the theme and tracks the mode
without hand-writing the `#{E:...}` conditionals. Set the text per slot and use
the `{{token}}` shortcuts for theme colors:

```tmux
set -g prefix C-Space
set -g @tubular_prefix_key "C-Space"

# custom left: a copy-colored dot, then snap back to the mode color, then the session
set -g @tubular_status_left_text  "#S #[fg={{copy}}]●#[default] "
# custom right: zoom indicator + pane count (only when zoomed), path, clock
set -g @tubular_status_right_text "#{?window_zoomed_flag,{{zoom_indicator}}#{window_panes} , }#{b:pane_current_path} 󰃰 %I:%M"
# keep tubular's pill-styled window list
set -g @tubular_window_tab_text " #W "

set -g @plugin 'dabstractor/tubular-tmux'
```

A slot whose `@tubular_*_text` you **set** is always rendered by tubular (with
tokens expanded). A slot you **don't** set is left to your own native value, or to
the bundled default if you also turn on `@tubular_manage_content`.

> **How the decision is made, per slot** (status-left, status-right, window tab):
>
> 1. You set `@tubular_<slot>_text` → tubular renders it (tokens expanded). ✅
> 2. Else if `@tubular_manage_content` is `on` → tubular renders the bundled default.
> 3. Else → your native value is left completely untouched.

---

## Theme color reference

When you write your own status text (option C above), the theme exposes two
ways to reference colors: the `{{token}}` shortcuts, or the raw variables
directly. Both work inside `@tubular_status_left_text`,
`@tubular_status_right_text`, and `@tubular_window_tab_text`.

### The easy way: `{{token}}` shortcuts

Write a token and tubular expands it to the correct tmux snippet once, at load
time. tmux then only ever sees a normal format string, and no shell runs at
render time. You never have to think about which variables are dynamic:

| Token                                           | Expands to                                | What it is                          |
| ----------------------------------------------- | ----------------------------------------- | ----------------------------------- |
| `{{mode_bg}}` `{{mode_fg}}`                     | the current mode's bg / fg                | **dynamic**: changes with the mode |
| `{{pill_bg}}` `{{pill_fg}}` `{{icon_fg}}`       | pill / icon colors                        | **dynamic**                         |
| `{{prefix}}` `{{copy}}` `{{zoom}}` `{{active}}` | those mode palette colors                 | static `#rrggbb`                    |
| `{{bg}}` `{{bg_max}}` `{{bg_min}}`              | background palette                        | static                              |
| `{{fg}}` `{{fg_active}}` `{{fg_focus}}`         | foreground palette                        | static                              |
| `{{neutral_visible}}` `{{neutral_hidden}}`      | subdued / faint text                      | static                              |
| `{{zoom_indicator}}`                            | the zoom indicator char, only when zoomed | convenience widget                  |

```tmux
# a copy-colored dot that stays the same color in every mode, then back to theme:
set -g @tubular_status_left_text "#S #[fg={{copy}}]●#[default] "
```

### The `#[default]` trick (no token needed)

The most useful coloring primitive needs no token at all. Paint a word, then
`#[default]` snaps the rest of the segment back to the current mode color,
dynamically, with no variable reference.

```tmux
# red ALERT, then the rest snaps back to whatever the current mode is:
set -g @tubular_status_left_text "#[fg=red]ALERT#[default] #S "
```

This works because every segment's `*-style` is set to the mode colors, so
`#[default]` always means "back to the theme."

### The power way: raw variables (and the `E:` rule)

You can also reference the variables directly. There is one rule that catches
people: the dynamic variables hold a conditional, so they must be
force-expanded with `#{E:…}`. Static palette colors are plain `#rrggbb` and
take no `E:`.

```tmux
# DYNAMIC  → MUST use E:  (this is the one that catches people)
#[fg=#{E:@tubular_mode_fg}]     ✅ resolves to the live mode fg
#[fg=#{@tubular_mode_fg}]       ❌ renders the raw conditional as garbage

# STATIC    → no E: needed; use the RESOLVED copies (@_tubular_*)
#[fg=#{@_tubular_copy_color}]   ✅ plain #e6c384, whether it came from a
                                #    theme or from your own option
#[fg=#{@tubular_copy_color}]    ⚠️ only works if YOU set that option —
                                #    empty when the color comes from
                                #    @tubular_theme
```

The dynamic variables are `@tubular_mode_bg`, `@tubular_mode_fg`,
`@tubular_pill_bg`, `@tubular_pill_fg`, `@tubular_icon_fg`. For static palette
colors, reference the `@_tubular_*` resolved copies (same names as the input
options, underscore-prefixed) — the plugin publishes the final palette there
after layering themes and explicit options. If you'd rather not remember any
of this, use the `{{token}}` shortcuts above instead; they expand to the right
form for you.

---

## Bring your own status line

To keep a fully custom status line and still get the mode effects, leave
`@tubular_manage_content` off (the default), set the `@tubular_*_text` options
for whichever slots you want tubular to render, and let the rest fall through
to your native tmux values.

```tmux
set -g @tubular_manage_content off          # don't clobber anything by default
set -g @tubular_status_left_text  "#S #[fg={{copy}}]●#[default] "
set -g @tubular_status_right_text "󰃰 %I:%M"
# window-status-format and separator stay as YOUR native values
```

A custom segment that tracks the mode:

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

tubular styles the two per-window alert states tmux tracks, but only your
window list shows them (never status-left/right), and only when more than one
window is open.

- **Activity**: a window you're not viewing produced output. Its tab text
  turns brighter so you notice it. Window flag: `#`.
- **Bell**: a window received a bell character (`\a`), e.g. a build finished
  or a REPL wants input. Its tab gets the same brighter text **plus a bell
  glyph ()** in the icon spot, so you can tell a real bell apart from plain
  activity even with only two tabs. Window flag: `!`.

Both styles are mode-aware. The brighter text shows on the dark normal bar,
where it reads as a clear cue, and snaps back to the mode's normal text color
on the bright prefix/copy/zoom bars, so an alert is never invisible
(white-on-white). The bell glyph rides along, so it stays visible in every
mode.

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

> **Where did that bell come from?** Bells originate from a pane writing `\a`
> (a finishing build, a chat client, a REPL prompting, etc.), not from tubular.
> To find the culprit at any moment:
>
> ```bash
> tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name} bell=#{window_bell_flag}'
> ```

---

## Configuration reference

All options are set **before** the plugin loads. Colors are `#rrggbb`.

### The content switch

```tmux
set -g @tubular_manage_content off   # default: colors only, your text is left alone.
# set to `on` to also get tubular's bundled content for any unset slot.
```

### Built-in themes (one option, every color)

```tmux
set -g @tubular_theme "kanagawa"   # the default
```

`@tubular_theme` swaps the **entire default palette** — backgrounds,
foregrounds, all four mode colors — and a matching style character (border
weight, mode boldness) with a single option. Available themes:

| theme        | character                                                            |
| ------------ | -------------------------------------------------------------------- |
| `kanagawa`   | *(default)* ink-wash; crystalBlue border, violet/yellow mode pops     |
| `tubular`    | kanagawa base with pink/green/yellow pops, heavy bold borders        |
| `gruvbox`    | warm retro; blue border, orange/lime pops, chunky filled borders     |
| `tokyonight` | deep navy neon; blue border, purple/green pops, glows bold in modes  |
| `catppuccin` | Mocha pastels; blue border, mauve/green pops, stays soft             |
| `nord`       | frosty and subdued; frost-cyan border, aurora purple/yellow pops     |
| `one-dark`   | balanced slate; cyan border, purple/green pops                       |
| `dracula`    | gothic neon; cyan border, pink/green pops, bold bands in every mode  |
| `rose-pine`  | dreamy and muted; pine border, love/gold pops, stays soft            |

Every preset follows the same design rules: colors are canonical values from
the named scheme; the scheme's most *neutral* accent sits on the default pane
border so the popping colors stay free for the modes; prefix/copy/normal keep
the highest mutual contrast (zoom — only ever seen with the pane filling the
screen — absorbs any look-alike accent); and thin normal borders always pair
with fat prefix borders so the mode change reads even without the status bar.

Precedence is strictly layered: **any `@tubular_*` option you set explicitly
always wins.** The theme only replaces the plugin's built-in defaults
underneath it, so you can pick a theme and still override one accent:

```tmux
set -g @tubular_theme "nord"
set -g @tubular_prefix_color "#bf616a"   # everything nord, but a red prefix
```

An unknown theme name falls back to `kanagawa` (with a `display-message`
warning).

#### Bring any theme (custom theme files)

Themes are plain files in the plugin's `themes/` directory, sourced once at
load time (never in the render path). `@tubular_theme` accepts either a bare
name — resolved against `themes/<name>.theme` — or any path containing a `/`
(a leading `~` expands):

```tmux
set -g @tubular_theme "~/.config/tmux/my-theme.theme"
```

A theme file assigns `th_*` variables and only needs to define what it
changes; anything it omits inherits the kanagawa defaults. The full set:

```bash
# my-theme.theme — a complete theme is ~10 lines
th_bg="#191724"; th_bg_max="#16141f"; th_bg_min="#1f1d2e"      # backgrounds
th_fg="#e0def4"; th_fg_active="#e0def4"; th_fg_focus="#e0def4" # text
th_neutral_visible="#908caa"; th_neutral_hidden="#403d52"      # subdued UI
th_zoom="#9ccfd8"; th_copy="#f6c177"                           # mode colors
th_prefix="#eb6f92"; th_active="#31748f"
th_border_lines="single"                                       # style character
th_normal_xb="0"; th_active_xb="0"; th_prefix_xb="1"; th_copy_xb="0"
```

Drop a `.theme` file into `themes/` and it works by bare name, exactly like
the bundled presets (which are the best reference — each documents its color
choices).

**Importing base16/base24 schemes.** To cover everything else, the bundled
`scripts/theme-import-base16.sh` converts any scheme from
[tinted-theming/schemes][] (250+ — essentially every color scheme in
existence) into a theme file:

```bash
~/.tmux/plugins/tubular-tmux/scripts/theme-import-base16.sh \
    rose-pine-moon.yaml > ~/.config/tmux/rose-pine-moon.theme
```

The importer maps the base16 slots deterministically (base0E purple → prefix,
base0B green → copy, base0C cyan → border, base0D blue → zoom — the classic
max-contrast assignment). Schemes that bend base16's hue conventions deserve
a quick hand-tune of the generated file; that's why the flagship themes ship
hand-tuned.

[tinted-theming/schemes]: https://github.com/tinted-theming/schemes

### Mode colors (the bar colors)

```tmux
# (defaults shown — the kanagawa theme's values)
set -g @tubular_prefix_color "#957fb8"   # bar bg while prefix is active
set -g @tubular_copy_color   "#e6c384"   # bar bg in copy/selection mode
set -g @tubular_zoom_color   "#7aa89f"   # bar bg when the pane is zoomed
set -g @tubular_active_color "#7e9cd8"   # active border / current-tab pill

# optional: text color on the mode-colored bar (defaults to @tubular_bg)
set -g @tubular_prefix_fg "#1f1f28"
set -g @tubular_copy_fg   "#1f1f28"
set -g @tubular_zoom_fg   "#1f1f28"

# optional: the focused PANE surface, per mode (distinct from the bar colors
# above, which paint the status line). Defaults keep the built-in look; set
# any to override. copy dims the bg / brightens the fg.
set -g @tubular_normal_pane_bg "#1f1f28"  # resting    (default: @tubular_bg)
set -g @tubular_normal_pane_fg "#dcd7ba"  # resting    (default: @tubular_fg)
set -g @tubular_copy_pane_bg   "#16161d"  # copy mode  (default: @tubular_bg_max)
set -g @tubular_copy_pane_fg   "#dcd7ba"  # copy mode  (default: @tubular_fg_focus)
set -g @tubular_zoom_pane_bg   "#1f1f28"  # zoomed     (default: @tubular_bg)
set -g @tubular_zoom_pane_fg   "#dcd7ba"  # zoomed     (default: @tubular_fg)
```

Priority when more than one applies: **prefix > copy > zoom > normal.**

### Background & foreground palette

```tmux
# (defaults shown — the kanagawa theme's values)
set -g @tubular_bg              "#1f1f28"  # main background
set -g @tubular_bg_max          "#16161d"  # darker (the resting status bar)
set -g @tubular_bg_min          "#2a2a37"  # lighter
set -g @tubular_fg              "#dcd7ba"  # main text
set -g @tubular_fg_active       "#dcd7ba"  # active window text
set -g @tubular_fg_focus        "#dcd7ba"  # focused text
set -g @tubular_neutral_visible "#727169"  # subdued UI (time, paths)
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
(`U+E0B6` / `U+E0B4`, `` / ``), which need a [Nerd Font][] to render.

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

Only the current window is wrapped. Inactive tabs always sit flat between
`@tubular_separator`, regardless of the caps.

[nerd font]: https://www.nerdfonts.com/

### Icons (Nerd Font glyphs, 10 chars for indices/counts 1–10)

```tmux
set -g @tubular_pane_icons   "󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘"
set -g @tubular_window_icons "󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞"
# circled alternatives:
# set -g @tubular_pane_icons   "①②③④⑤⑥⑦⑧⑨⑩"
# set -g @tubular_window_icons "❶❷❸❹❺❻❼❽❾❿"
```

### Pane borders

`pane-border-lines` cannot be a format, so the line style is fixed at load
time; only colors and bold change per mode.

```tmux
# (defaults shown — the kanagawa theme's values; other themes differ)
set -g @tubular_normal_border_lines "single"   # single|double|heavy|simple|number|rounded
set -g @tubular_normal_extra_bold "0"          # fill inactive border bg (0/1)
set -g @tubular_active_extra_bold "0"          # active pane, normal/zoom
set -g @tubular_prefix_extra_bold "1"          # active pane, prefix (cascades from active)
set -g @tubular_copy_extra_bold   "0"          # active pane, copy   (cascades from active)
```

### Pane background & transparency

By default, tubular paints the tmux pane background: inactive panes get
`@tubular_bg_max` and the active pane gets `@tubular_bg`, for an opaque,
theme-matched look with no seam between the bar and the pane content. The pane
foreground colors are always themed (dimmer on inactive panes).

The focused pane also reacts to the mode, recoloring its interior per mode:
**copy** dims the bg to `@tubular_copy_pane_bg` and brightens the text to
`@tubular_copy_pane_fg`, **zoom** uses `@tubular_zoom_pane_*`, and **normal**
uses `@tubular_normal_pane_*`. All default to the themed look; set any to
override. Priority is copy > zoom > normal.

> **Why there is no prefix pane color.** `window-active-style` caches its format
> at set-time and is never re-evaluated on redraw, so the plugin re-applies it
> on each mode change (copy via a `pane-mode-changed` hook, zoom via
> `window-layout-changed`). Prefix can't be done this way: `client_prefix` is
> per-client, but the pane interior is shared across clients, so a
> `#{?client_prefix,…}` in `window-active-style` stores but never paints. A
> key-binding swap paints on press but can't be restored reliably — there's no
> hook that fires on prefix-table exit, and bound prefix commands bypass the
> `Any` fallback, so the color sticks. The prefix **border and status bar** do
> recolor (their styles are dynamic); the pane interior does not, by design.

If you run your terminal with **transparency** or a **background image**, three
modes are available via `@tubular_pane_bg`:

```tmux
set -g @tubular_pane_bg on       # paint every pane (default)
set -g @tubular_pane_bg active   # paint ONLY the focused pane
set -g @tubular_pane_bg off      # paint nothing (full transparency)
```

| `@tubular_pane_bg` | active pane             | inactive panes              | transparency through panes |
| ------------------ | ----------------------- | --------------------------- | -------------------------- |
| `on` _(default)_   | painted (`@tubular_bg`) | painted (`@tubular_bg_max`) | covered                    |
| `active`           | painted (`@tubular_bg`) | left to the terminal        | **inactive only**          |
| `off`              | left to the terminal    | left to the terminal        | **everywhere**             |

`active` is the middle ground: the focused pane is a solid themed surface
while background panes stay translucent, so context stays visible without
competing for attention.

---

## How it works

### Mode highlighting

Tubular detects the active window's state on every redraw from inside the
format strings themselves, with no shell and no cached state:

- **prefix**: `client_prefix`
- **copy**: `#{==:#{W:#{?window_active,#{pane_in_mode},}},1}` (scans the window list so any tab being rendered can read the _active_ window's mode)
- **zoom**: `#{m:*Z*,#{W:#{?window_active,#{window_flags},}}}`

The whole bar becomes one solid block of the mode color because `status-style`
and every per-segment `*-style` are set to that color, and segments that don't
declare their own `#[fg=/bg=]` inherit it.

### Why no shell at render time

Earlier versions shelled out for centering and mode detection; the async jank
against tmux's synchronous format expansion was visible. Everything drawn here
is now a tmux format. The `{{token}}` shortcuts are expanded once, in bash,
when the plugin loads, so by render time they're already plain tmux format.
`run-shell` and `#(...)` are never used in a status format.

---

## Theme gallery

Gruvbox, Tokyo Night, Catppuccin Mocha, Nord, One Dark, Dracula, Rosé Pine,
Kanagawa, and Tubular ship built in — set them with one line (see
[Built-in themes](#built-in-themes-one-option-every-color)):

```tmux
set -g @tubular_theme "tokyonight"
```

Anything else can be imported from a base16 scheme or written as a ~10-line
theme file (see [Bring any theme](#bring-any-theme-custom-theme-files)), or
set inline via the palette options. A couple of inline recipes:

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

Set options before the plugin loads:

```tmux
set -g @tubular_prefix_key "C-b"
set -g @tubular_prefix_color "#d27e99"
# ...then...
set -g @plugin 'dabstractor/tubular-tmux'
```

Reload with `tmux source ~/.tmux.conf`.

### Prefix highlighting not working

Prefix highlighting requires `@tubular_prefix_key`, and it must match your
tmux `prefix`. The plugin sets `prefix None` and rebinds the key itself, so a
mismatch means the highlight never fires, or your prefix stops working:

```tmux
set -g prefix C-Space                # your tmux prefix
set -g @tubular_prefix_key "C-Space" # tell tubular the same key
```

This is not auto-detected: once the plugin takes the key over, the original
prefix can't be read back on reload, so it must be stated explicitly.

### My `status-bg` / `status-fg` seem to fight the mode colors

They do. The legacy `status-bg`/`status-fg` silently override `status-style`
and pin the bar. Tubular unsets them on load; make sure nothing in your own
config sets them afterward.

### Icons not displaying

Install a Nerd Font and set it in your terminal emulator.

---

## License

MIT
