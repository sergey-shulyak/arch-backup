#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Parable development certificates
export APN_CERT_PATH="/home/sshuliak/Developer/parable/rails_certs/dummy_apn_cert.pem"
export ENCRYPTION_KEY_PATH="/home/sshuliak/Developer/parable/rails_certs/dummy_encryption_key.key"
