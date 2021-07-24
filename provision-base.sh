#!/bin/bash
set -euxo pipefail

# prevent apt-get et al from asking questions.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# # make sure the system does not uses swap (a kubernetes requirement).
# # NB see https://kubernetes.io/docs/tasks/tools/install-kubeadm/#before-you-begin
# swapoff -a
# sed -i -E 's,^([^#]+\sswap\s.+),#\1,' /etc/fstab

# show mac/ip addresses and the machine uuid to troubleshoot they are unique within the cluster.
ip addr
cat /sys/class/dmi/id/product_uuid

# update the package cache.
apt-get update

# install jq.
apt-get install -y jq

# install curl.
apt-get install -y curl

# install the bash completion.
apt-get install -y bash-completion

# install vim.
apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF

# configure the shell.
cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF
