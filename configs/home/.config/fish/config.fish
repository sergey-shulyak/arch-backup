set -gx PATH $HOME/.local/bin $PATH
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SYSTEMD_EDITOR nvim

alias reload='source ~/.config/fish/config.fish'
alias reload-waybar='pkill waybar; nohup waybar >/dev/null 2>&1 & disown'
alias glow='glow -p'
alias music='ncmpcpp'
alias pi5ssh='sshfs sshuliak@192.168.1.105:/home/sshuliak ~/mnt/pi5'

if status is-interactive
    # Commands to run in interactive sessions can go here
end
