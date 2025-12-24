set -gx PATH $HOME/.local/bin $PATH
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SYSTEMD_EDITOR nvim

if status is-interactive
    # Commands to run in interactive sessions can go here
end
