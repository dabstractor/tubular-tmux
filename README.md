# Tubular TMux

A stylish, highly customizable tmux statusline plugin with Kanagawa theme defaults and dynamic mode highlighting.

## Features

- **Opinionated styling** with configurable colors and content
- **Dynamic mode highlighting** for prefix, copy, and zoom states
- **TPM compatible** installation
- **Kanagawa theme** defaults
- Optimized performance with state caching

## Installation

### Via TPM (Recommended)

1. Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'dabstractor/tubular-tmux'
```

2. Install with `prefix` + <kbd>I</kbd>

### Manual Installation

```bash
git clone https://github.com/dabstractor/tubular-tmux ~/.tmux/plugins/tubular-tmux
```

Add to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tubular-tmux/tubular.tmux
```

## Configuration

### Quick Start

Add configuration options to your `~/.tmux.conf` before loading the plugin:

```tmux
# Optional: Set window list justification (left, centre, or right)
set -g status-justify "centre"

# Optional: Customize prefix key for mode highlighting
set -g @tubular_prefix_key "C-Space"

# Optional: Customize colors
set -g @tubular_prefix_color "#d27e99"
set -g @tubular_copy_color "#98bb6c"
set -g @tubular_zoom_color "#e6c384"

# Load the plugin
set -g @plugin 'dabstractor/tubular-tmux'
```

### Full Configuration Options

#### Mode-Specific Colors

```tmux
set -g @tubular_zoom_color "#e6c384"      # Background when pane is zoomed
set -g @tubular_copy_color "#98bb6c"      # Background in copy/selection mode
set -g @tubular_prefix_color "#d27e99"    # Background when prefix is active
set -g @tubular_active_color "#7aa89f"    # Active pane border color
```

#### Background & Foreground Colors

```tmux
# Background colors
set -g @tubular_bg "#1f1f28"              # Main background
set -g @tubular_bg_max "#181822"          # Darker areas (status bar)
set -g @tubular_bg_min "#24242e"          # Lighter areas

# Foreground colors
set -g @tubular_fg "#dcd7ba"              # Main text
set -g @tubular_fg_active "#cccccc"       # Active window text
set -g @tubular_fg_focus "#cccccc"        # Focused text
set -g @tubular_neutral_visible "#787878" # Subdued UI elements (time, path)
set -g @tubular_neutral_hidden "#54546d"  # Faint indicators (pane counts)
```

#### Additional Colors

```tmux
set -g @tubular_color_orange "#ffa066"    # Tab separator accent
```

#### Content Options

Control what text appears in your statusline:

```tmux
# Status bar content (supports tmux format strings)
set -g @tubular_status_left_text " #S  #{?@active_window_zoomed,    ,}"
set -g @tubular_status_right_text "  󰃰  %I:%M  "

# Window tab content
set -g @tubular_window_tab_text " #W "

# Tab decorations
set -g @tubular_tab_start ""
set -g @tubular_tab_end ""

# Window separator
set -g @tubular_separator "   "

# Zoom indicator
set -g @tubular_zoom_indicator "+"
```

#### Status Bar Color Variables

For custom color control in `status_left_text`, `status_right_text`, and `window_tab_text`:

```tmux
#{@tubular_status_bg}        # Current background
#{@tubular_status_fg}        # Primary foreground
#{@tubular_status_fg_dim}    # Dimmed foreground
#{@tubular_status_fg_muted}  # Muted foreground
```

Updated dynamically for each mode (prefix/copy/zoom/normal).

**Examples:**

```tmux
# Reset colors mid-text
set -g @tubular_status_left_text " #S #[fg=#{@tubular_status_fg},bg=#{@tubular_status_bg}] %H:%M "

# Inverted colors
set -g @tubular_status_right_text " #[fg=#{@tubular_status_bg},bg=#{@tubular_status_fg}] TMUX #[default]  %I:%M  "

# Dimmed text
set -g @tubular_status_left_text " #S #[fg=#{@tubular_status_fg_dim}] #{session_windows}W "

# Multi-level prominence
set -g @tubular_window_tab_text " #{window_index}#[fg=#{@tubular_status_fg_muted}]:#[fg=#{@tubular_status_fg}]#W "
```

#### Icon Options

Customize pane count and window number icons:

```tmux
# Pane count icons (10 characters for counts 1-10)
set -g @tubular_pane_icons "󰼏󰼐󰼑󰼒󰼓󰼔󰼕󰼖󰼗󰼘"

# Window number icons (10 characters for windows 1-10)
set -g @tubular_window_icons "󰲠󰲢󰲤󰲦󰲨󰲪󰲬󰲮󰲰󰲞"

# Alternative: Circled numbers
set -g @tubular_pane_icons "①②③④⑤⑥⑦⑧⑨⑩"
set -g @tubular_window_icons "❶❷❸❹❺❻❼❽❾❿"
```

#### Border Style Options

Configure pane border appearance for different modes:

```tmux
# Border line style (applies to all panes)
set -g @tubular_normal_border_lines "single"

# Extra-bold effect (fills background same as foreground)
set -g @tubular_normal_extra_bold "0"       # Non-active panes
set -g @tubular_active_extra_bold "1"       # Active pane in normal/zoom mode

# Active pane (prefix mode)
set -g @tubular_prefix_border_lines "heavy"
set -g @tubular_prefix_extra_bold "1"

# Active pane (copy mode)
set -g @tubular_copy_border_lines "heavy"
set -g @tubular_copy_extra_bold "1"
```

Border line styles: `single`, `double`, `heavy`, `simple`, `number`, `rounded`

## How It Works

### Mode Highlighting

Tubular automatically detects and highlights different tmux modes:

- **Normal Mode** - Cyan border on active pane
- **Prefix Mode** - Pink background when prefix key is active
- **Copy Mode** - Green background during text selection
- **Zoom Mode** - Yellow background when pane is zoomed

### Opinionated Design

The plugin handles layout, positioning, and mode-based styling. You configure colors and text content.

## Customization Examples

### Tokyo Night Theme

```tmux
# Mode colors
set -g @tubular_prefix_color "#bb9af7"     # Purple
set -g @tubular_copy_color "#9ece6a"       # Green
set -g @tubular_zoom_color "#e0af68"       # Orange
set -g @tubular_active_color "#7aa2f7"     # Blue

# Background/Foreground
set -g @tubular_bg "#1a1b26"
set -g @tubular_bg_max "#16161e"
set -g @tubular_fg "#c0caf5"
set -g @tubular_neutral_visible "#565f89"
set -g @tubular_neutral_hidden "#3b4261"
```

### Catppuccin Mocha

```tmux
# Mode colors
set -g @tubular_prefix_color "#f5c2e7"     # Pink
set -g @tubular_copy_color "#a6e3a1"       # Green
set -g @tubular_zoom_color "#f9e2af"       # Yellow
set -g @tubular_active_color "#89b4fa"     # Blue

# Background/Foreground
set -g @tubular_bg "#1e1e2e"
set -g @tubular_bg_max "#11111b"
set -g @tubular_fg "#cdd6f4"
set -g @tubular_neutral_visible "#7f849c"
set -g @tubular_neutral_hidden "#45475a"
```

### Minimal Monochrome

```tmux
# Mode colors
set -g @tubular_prefix_color "#ffffff"     # White
set -g @tubular_copy_color "#d0d0d0"       # Light gray
set -g @tubular_zoom_color "#b0b0b0"       # Medium gray
set -g @tubular_active_color "#c0c0c0"     # Gray

# Background/Foreground
set -g @tubular_bg "#0a0a0a"
set -g @tubular_fg "#e0e0e0"
set -g @tubular_neutral_visible "#808080"
set -g @tubular_neutral_hidden "#404040"
```

### Solarized Dark

```tmux
# Mode colors
set -g @tubular_prefix_color "#d33682"     # Magenta
set -g @tubular_copy_color "#859900"       # Green
set -g @tubular_zoom_color "#b58900"       # Yellow
set -g @tubular_active_color "#268bd2"     # Blue

# Background/Foreground
set -g @tubular_bg "#002b36"
set -g @tubular_bg_max "#073642"
set -g @tubular_fg "#839496"
set -g @tubular_neutral_visible "#586e75"
set -g @tubular_neutral_hidden "#073642"
```

## Design

Colors are defined directly without intermediate variables. The plugin stores them as internal tmux options (`#{@_tubular_prefix_color}`) for dynamic evaluation.

## File Structure

```
tubular-tmux/
├── tubular.tmux              # Plugin entry point
├── scripts/
│   ├── prefix-highlight.sh   # Mode detection & highlighting
│   ├── pane-count-icon.sh    # Pane count indicators
│   ├── window-index-icon.sh  # Window index indicators
│   └── select-icon.sh        # Icon selection utility
└── README.md                 # This file
```

## Requirements

- tmux 3.0+
- [Nerd Font](https://www.nerdfonts.com/) (for icons)
- bash

## Troubleshooting

### Colors Not Applying

Ensure your configuration options are set **before** loading the plugin in `~/.tmux.conf`:

```tmux
set -g @tubular_prefix_key "C-b"
set -g @tubular_prefix_color "#d27e99"
# ... other options ...
set -g @plugin 'dabstractor/tubular-tmux'
```

Then reload: `tmux source ~/.tmux.conf`

### Prefix Highlighting Not Working

If prefix mode highlighting isn't working, ensure you've set the prefix key option:

```tmux
set -g @tubular_prefix_key "C-Space"  # or your preferred prefix key
```

The plugin binds this key to enable mode highlighting. If you have custom prefix bindings elsewhere, they may need adjustment.

### Icons Not Displaying

Install a Nerd Font and configure your terminal emulator to use it.

### Scripts Not Found

Verify the plugin installed correctly:

```bash
ls ~/.tmux/plugins/tubular-tmux/scripts/
```

Should show `prefix-highlight.sh`, `pane-count-icon.sh`, `window-index-icon.sh`, and `select-icon.sh`.

## License

MIT License

---

**Made with ❤️  for tmux users who want control without complexity**
