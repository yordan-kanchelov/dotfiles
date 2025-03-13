# Tmux Configuration & TPM Setup

This is part of my dotfiles collection, specifically the `tmux` configuration folder. This setup is designed to enhance usability and aesthetics through improved status bars, clear window formatting, and the integration of useful plugins.

---

## Overview

**Tmux** is a powerful terminal multiplexer allowing users to manage multiple terminal sessions within a single window. This configuration provides mouse support, customizes the status bar for enhanced readability, and integrates several plugins to boost productivity and appearance.

---

## Prerequisites

- **Tmux**: Make sure Tmux is installed on your system
  ```shell
  # Ubuntu/Debian
  sudo apt install tmux

  # macOS (using Homebrew)
  brew install tmux

  # Arch Linux
  sudo pacman -S tmux
  ```
- **Git**: Required for installing Tmux Plugin Manager (TPM)

---

## Installation

1. **Clone or download these dotfiles** to your preferred location

2. **Set up the configuration file** using one of these methods:

   **Option A: Create a symbolic link** (recommended for easy updates):
   ```shell
   ln -s /path/to/dotfiles/tmux/.tmux.conf ~/.tmux.conf
   ```

   **Option B: Copy the file** (if you prefer a standalone copy):
   ```shell
   cp /path/to/dotfiles/tmux/.tmux.conf ~/.tmux.conf
   ```
3. **Install Tmux Plugin Manager (TPM)**:
   ```shell
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```
4. **Load the configuration**:
   - If Tmux is already running: `tmux source-file ~/.tmux.conf`
   - Or restart Tmux

---

## Configuration Details

### Mouse Support

```shell
set -g mouse on
```

- Enables mouse interaction, including pane and window selection, resizing, and scrolling.

### Status Bar Customization

```shell
# Status bar refresh interval and layout
set -g status-interval 5
set -g status-left-length 60
set -g status-right-length 20

# Customized left-side status bar
set -g status-left "#[fg=green]Session: #S #[fg=yellow]| "
```

- **Refresh Interval**: Updates the status bar every 5 seconds.
- **Length Settings**: Defines clear length limits for the status bar.
- **Session Display**: Clearly shows the current session name in green with a distinct yellow separator.

### Window Formatting

```shell
set -g window-status-format "#[fg=cyan]#I:#W#[default]"
set -g window-status-current-format "#[bg=blue,fg=white]#I:#W#[default]"
```

- Highlights the currently active window distinctly, facilitating easy navigation.

---

## Plugin Management

Managed through TPM, the following plugins are included:

### Tmux Plugin Manager (TPM)

Simplifies the installation and management of Tmux plugins.

```shell
set -g @plugin 'tmux-plugins/tpm'
```

### tmux-sensible

Provides sensible default settings for a smoother user experience.

```shell
set -g @plugin 'tmux-plugins/tmux-sensible'
```

### tmux-prefix-highlight

Visually highlights prefix key presses for enhanced feedback.

```shell
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'
```

### Dracula Theme

Adds an aesthetic and informative Dracula-themed appearance.

```shell
set -g @plugin 'dracula/tmux'

set -g @dracula-plugins "cpu-usage gpu-usage ram-usage"
set -g @dracula-show-powerline true
set -g @dracula-show-left-icon session
set -g @dracula-show-empty-plugins false
```

---

## Additional Useful Settings

### Highlight Prefix in Copy Mode

Improves visibility when entering copy mode.

```shell
set -g @prefix_highlight_show_copy_mode 'on'
```

### Reloading Tmux Configuration

Allows quick configuration reload directly from within Tmux.

```shell
bind R source-file ~/.tmux.conf \; display-message "Tmux config reloaded!"
```

### Plugin Manager Initialization

Ensures TPM initializes correctly when Tmux starts.

```shell
run "$HOME/.tmux/plugins/tpm/tpm"
```

---

## Managing Plugins with TPM

After installing the configuration and TPM as described in the Installation section, you can manage your plugins:

### Installing Plugins

All plugins are already defined in the `.tmux.conf` file. To install them:

1. Launch Tmux if it's not already running
2. Press your prefix key (`Ctrl+b` by default) followed by `I` (capital "i")
3. The plugins will be downloaded and installed automatically

### Updating Plugins

To update all plugins:

- Press your prefix key followed by `U` (capital "u")

### Adding New Plugins

1. Add the plugin to your `.tmux.conf` file:
   ```shell
   set -g @plugin 'github-username/plugin-name'
   ```
2. Press your prefix key followed by `I` to install it

### Removing Plugins

1. Remove or comment out the plugin line from your `.tmux.conf` file
2. Press your prefix key followed by `alt + u` to remove it

For more details, visit [TPM on GitHub](https://github.com/tmux-plugins/tpm).

---

## Conclusion

This optimized Tmux configuration significantly enhances your terminal workflow, combining productive plugins and a visually appealing interface. With TPM's simplified plugin management, maintaining your Tmux environment is straightforward, efficient, and enjoyable.

Happy Tmuxing!
