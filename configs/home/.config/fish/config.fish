###################
### ENVIRONMENT ###
###################

set -gx PATH $HOME/.local/bin $PATH
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SYSTEMD_EDITOR nvim
#set -gx XDG_DATA_DIRS $XDG_DATA_DIRS /var/lib/flatpak/exports/share /home/$USER/.local/share/flatpak/exports/share
#set -gx WEBKIT_DISABLE_COMPOSITING_MODE 1

# === Syntax Highlighting ===
# bat: modern cat replacement (uses dynamically generated Hyprstyle theme)
#set -gx BAT_THEME Hyprstyle

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
alias theme='cd ~/Documents/arch-backup/hyprstyle && ./hyprstyle.sh $argv && cd -'
alias feh='feh --scale-down --auto-zoom $argv'
alias cdb='cd ~/Documents/arch-backup'
alias cds='cd ~/Documents/arch-backup/hyprstyle'
alias cdc='cd ~/.config'
alias cdlb='cd ~/.local/bin'

# Tools
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --grid --group-directories-first'
alias la='eza -lah --icons --group-directories-first'
alias tree='eza --tree --icons'

alias cat='bat --paging=never'

alias grep='rg'

alias find='fd'

alias df='duf'

alias du='dust'

alias top='btop'

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
#abbr -a doc cd ~/Documents
#abbr -a dev cd ~/Developer
#abbr -a down cd ~/Downloads
#abbr -a cfg cd ~/.config

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

    # Fzf
    fzf --fish | source

    # Zoxide
    zoxide init fish --cmd cd | source

    # === Mise (tool version manager) ===
    mise activate fish | source

    # === Glow (markdown viewer) ===
    glow completion fish | source

    if set -q SSH_CONNECTION
        set -gx TERM xterm-256color
        fastfetch
    end
end
