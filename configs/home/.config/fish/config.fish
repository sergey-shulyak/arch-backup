###################
### ENVIRONMENT ###
###################

set -gx PATH $HOME/.local/bin $PATH
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SYSTEMD_EDITOR nvim

###################
### ALIASES ###
###################

alias reload='source ~/.config/fish/config.fish'
alias reload-waybar='pkill waybar; nohup waybar >/dev/null 2>&1 & disown'
alias glow='glow -p'
alias music='ncmpcpp'

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

if status is-interactive
    # Disable greeting message for cleaner shell
    set fish_greeting

    # Increase history size
    set -gx HISTSIZE 10000

    # Initialize Starship prompt
    starship init fish | source
end
mise activate fish | source
