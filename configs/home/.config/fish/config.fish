###################
### ENVIRONMENT ###
###################

set -gx PATH $HOME/.local/bin $PATH
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SYSTEMD_EDITOR nvim
set -gx XDG_DATA_DIRS $XDG_DATA_DIRS /var/lib/flatpak/exports/share /home/$USER/.local/share/flatpak/exports/share

# === Syntax Highlighting ===
# bat: modern cat replacement (uses dynamically generated Hyprstyle theme)
set -gx BAT_THEME "Hyprstyle"
#set -gx BAT_OPTS "--number --style full"

# less: syntax highlighting via pygmentize
set -gx LESSOPEN "| /usr/bin/pygmentize -f 256 -o - %s"
set -gx LESS " -R"

# === FZF Options with Bat Preview ===
set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --line-range :500 {}'"
set -gx FZF_ALT_C_OPTS "--preview 'ls -lah {}'"

###################
### ALIASES ###
###################

alias reload='source ~/.config/fish/config.fish'
alias reload-hyprland='hyprctl reload'
alias reload-waybar='pkill waybar; nohup waybar >/dev/null 2>&1 & disown'
alias glow='glow -p'
alias music='ncmpcpp'
alias caffeine='systemctl --user stop hypridle'
alias decaf='systemctl --user start hypridle'
alias theme='cd ~/Documents/arch-backup/hyprstyle && ./hyperstyle.sh $argv && cd -'
alias feh='feh --scale-down --auto-zoom $argv'

###################
### FUNCTIONS ###
###################

# Open kitty TUI applications as floating windows (for Waybar)
function kfloat
    if test (count $argv) -eq 0
        echo "Usage: kfloat <command> [args...]"
        echo "Examples: kfloat btop, kfloat pulsemixer"
        return 1
    end

    set cmd $argv[1]
    kitty --title $cmd $cmd $argv[2..]
end

###################
### ABBREVIATIONS ###
###################

# Git shortcuts - auto-expand as you type
abbr -a gs git status
abbr -a gc git commit
abbr -a ga git add
abbr -a gp git push
abbr -a gb git branch
abbr -a gd git diff
abbr -a gl git log --oneline
abbr -a gco git checkout

# Common directories
abbr -a doc cd ~/Documents
abbr -a dev cd ~/Developer
abbr -a down cd ~/Downloads
abbr -a cfg cd ~/.config

# Useful shortcuts
abbr -a ll ls -lah
abbr -a la ls -la
abbr -a cp cp -i
abbr -a mv mv -i
abbr -a rm rm -i
abbr -a mkdir mkdir -p

###################
### INTERACTIVE ###
###################

if status is-interactive
    # Disable greeting message for cleaner shell
    set fish_greeting

    # Increase history size
    set -gx HISTSIZE 10000

    # Initialize Starship prompt
    starship init fish | source

    # === FZF Shell Integration ===
    # Disable default fzf keybindings and set custom ones
    set -gx FZF_CTRL_T_COMMAND ''  # Disable default CTRL+T
    set -gx FZF_CTRL_R_COMMAND ''  # Disable default CTRL+R
    set -gx FZF_ALT_C_COMMAND ''   # Disable default ALT+C
    fzf --fish | source

    # Custom FZF keybindings
    bind \co fzf-file-widget        # CTRL+O: Open files
    bind -M insert \co fzf-file-widget

    # === Nvim keybinding ===
    bind \ce 'nvim'                 # CTRL+E: Open nvim
    bind -M insert \ce 'nvim'

    # === Mise (tool version manager) ===
    mise activate fish | source
end
