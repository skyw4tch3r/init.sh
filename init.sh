#!/bin/bash

# ==========================
# |  Usage Instructions   |
# ==========================
# bash -c "$(wget -O- https://raw.githubusercontent.com/skyw4tch3r/init.sh/refs/heads/main/init.sh)"
# After installation, open tmux and press Prefix+I to install the theme

set -e  # Exit on error

cd ~

# ==========================
# | 1. Install Essential Packages |
# ==========================
echo "[*] Installing essential packages..."
sudo NEEDRESTART_MODE=a apt update && \
  sudo NEEDRESTART_MODE=a apt upgrade -y && \
  sudo NEEDRESTART_MODE=a apt dist-upgrade -y && \
  sudo NEEDRESTART_MODE=a apt autoremove -y && \
  sudo NEEDRESTART_MODE=a apt autoclean -y

sudo NEEDRESTART_MODE=a apt install -y \
  tmux zsh vim curl git xclip wget htop net-tools \
  python3-pip python3-dev libssl-dev libffi-dev build-essential unzip python3-venv \
  fzf eza golang-go cargo pipx massdns libpcap-dev docker.io docker-compose autojump source-highlight

# ==========================
# | 1.1 Install NeoVIM |
# ==========================
#curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && sudo rm -rf /opt/nvim && sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
#mkdir -p ~/.config/nvim
#git clone https://github.com/folke/lazy.nvim.git --branch=stable ~/.local/share/nvim/lazy/lazy.nvim
#nvim ~/.config/nvim/init.lua

#eval "$(pipx ensurepath)"

# ==========================
# | 2. Install ProjectDiscovery Toolkit |
# ==========================
echo "[*] Installing ProjectDiscovery toolkit..."
export PATH="$PATH:$HOME/go/bin"
go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
"$HOME/go/bin/pdtm" -ia

# ==========================
# | 3. (Optional) Install Starship and Docker |
# ==========================
# Uncomment to install Starship prompt and Docker
#sudo sh -c "$(wget -qO- https://starship.rs/install.sh)" "" -y
# 

# ==========================
# | 4. Write .tmux.conf    |
# ==========================
mkdir -p ~/.tmux
mkdir -p ~/.tmux/plugins
mkdir -p ~/.tmux/plugins/tpm
cat > ~/.tmux/yank.sh <<'EOS'
#!/bin/sh
xclip -selection clipboard
EOS


chmod +x ~/.tmux/yank.sh

echo "[*] Writing .tmux.conf..."

cat > ~/.tmux.conf <<'EOF'
# ==========================
# ===  General settings  ===
# ==========================

set -g default-terminal "screen-256color"
set -g history-limit 20000
set -g buffer-limit 20
set -sg escape-time 0
set -g display-time 1500
set -g remain-on-exit off
set -g repeat-time 300
setw -g allow-rename off
setw -g automatic-rename off
setw -g aggressive-resize on

# Change prefix key to C-a, easier to type, same to "screen"
unbind C-b
set -g prefix C-a
bind C-a send-prefix

bind n next-window
bind p previous-window
bind l last-window

# Set parent terminal title to reflect current window in tmux session 
set -g set-titles on
set -g set-titles-string "#I:#W"

# Start index of window/pane with 1, because we're humans, not computers
set -g base-index 1
setw -g pane-base-index 1

# Enable mouse support
set -g mouse on


# ==========================
# ===   Key bindings     ===
# ==========================

# Unbind default key bindings, we're going to override

unbind %    # split-window -h
unbind '"'  # split-window
#unbind }    # swap-pane -D
#unbind {    # swap-pane -U
#unbind [    # paste-buffer
#unbind ]    
#unbind "'"  # select-window
#unbind n    # next-window
#unbind p    # previous-window
#unbind l    # last-window
#unbind M-n  # next window with alert
#unbind M-p  # next window with alert
#unbind o    # focus thru panes
unbind &    # kill-window
#unbind "#"  # list-buffer 
#unbind =    # choose-buffer
unbind z    # zoom-pane
#unbind M-Up  # resize 5 rows up
#unbind M-Down # resize 5 rows down
#unbind M-Right # resize 5 rows right
#unbind M-Left # resize 5 rows left

# Split panes
bind | split-window -h -c "#{pane_current_path}"
bind _ split-window -v -c "#{pane_current_path}"

# Zoom pane
bind + resize-pane -Z

# Reload tmux configuration 
bind C-r source-file ~/.tmux.conf \; display "Config reloaded"

# new window and retain cwd
bind c new-window -c "#{pane_current_path}"

# Kill pane/window/session shortcuts
bind x kill-pane
bind X kill-window
bind C-x confirm-before -p "kill other windows? (y/n)" "kill-window -a"
bind Q confirm-before -p "kill-session #S? (y/n)" kill-session

# Prompt to rename window right after it's created
#set-hook -g after-new-window 'command-prompt -I "#{window_name}" "rename-window '%%'"'

# Detach from session
bind d detach
bind D if -F '#{session_many_attached}' \
    'confirm-before -p "Detach other clients? (y/n)" "detach -a"' \
    'display "Session has only 1 client attached"'

# ================================================
# ===     Copy mode, scroll and clipboard      ===
# ================================================
set -g @copy_use_osc52_fallback on

# Prefer vi style key table
setw -g mode-keys vi

bind p paste-buffer
bind C-p choose-buffer

# trigger copy mode by
bind -n M-Up copy-mode

# Scroll up/down by 1 line, half screen, whole screen
bind -T copy-mode-vi M-Up              send-keys -X scroll-up
bind -T copy-mode-vi M-Down            send-keys -X scroll-down
bind -T copy-mode-vi M-PageUp          send-keys -X halfpage-up
bind -T copy-mode-vi M-PageDown        send-keys -X halfpage-down
bind -T copy-mode-vi PageDown          send-keys -X page-down
bind -T copy-mode-vi PageUp            send-keys -X page-up

# When scrolling with mouse wheel, reduce number of scrolled rows per tick to "2" (default is 5)
bind -T copy-mode-vi WheelUpPane       select-pane \; send-keys -X -N 2 scroll-up
bind -T copy-mode-vi WheelDownPane     select-pane \; send-keys -X -N 2 scroll-down

# wrap default shell in reattach-to-user-namespace if available
# there is some hack with `exec & reattach`, credits to "https://github.com/gpakosz/.tmux"
# don't really understand how it works, but at least window are not renamed to "reattach-to-user-namespace"
if -b "command -v reattach-to-user-namespace > /dev/null 2>&1" \
    "run 'tmux set -g default-command \"exec $(tmux show -gv default-shell) 2>/dev/null & reattach-to-user-namespace -l $(tmux show -gv default-shell)\"'"

yank="~/.tmux/yank.sh"

# Copy selected text
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "$yank"
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "$yank"
bind -T copy-mode-vi Y send-keys -X copy-line \;\
    run "tmux save-buffer - | $yank"
bind-key -T copy-mode-vi D send-keys -X copy-end-of-line \;\
    run "tmux save-buffer - | $yank"
bind -T copy-mode-vi C-j send-keys -X copy-pipe-and-cancel "$yank"
bind-key -T copy-mode-vi A send-keys -X append-selection-and-cancel \;\
    run "tmux save-buffer - | $yank"

# Copy selection on drag end event, but do not cancel copy mode and do not clear selection
# clear select on subsequence mouse click
bind -T copy-mode-vi MouseDragEnd1Pane \
    send-keys -X copy-pipe "$yank"
bind -T copy-mode-vi MouseDown1Pane select-pane \;\
   send-keys -X clear-selection
    
# iTerm2 works with clipboard out of the box, set-clipboard already set to "external"
# tmux show-options -g -s set-clipboard
# set-clipboard on|external

# =====================================
# ===    Appearence and status bar  ===
# ======================================
# Better status bar
set -g status-bg black
set -g status-fg green
set -g status-left "#[fg=green] #[bg=black,fg=cyan] #S #[bg=black,fg=green]"
set -g status-right "#[fg=yellow] %Y-%m-%d %H:%M #[fg=red] #h #[fg=yellow]LAN: #(ifconfig getifaddr eth0)"

# Right side of status bar (includes IP and time)
set -g status-right "#[bg=black,fg=cyan] #(hostname -I | awk '{print $1}') #[bg=black,fg=cyan] #h %H:%M"

# Use reattach-to-user-namespace for better macOS clipboard support
set-option -g set-clipboard on

# =====================================
# ===        Renew environment      ===
# =====================================
set -g update-environment \
  "DISPLAY\
  SSH_ASKPASS\
  SSH_AUTH_SOCK\
  SSH_AGENT_PID\
  SSH_CONNECTION\
  SSH_TTY\
  WINDOWID\
  XAUTHORITY"

bind '$' run "~/.tmux/renew_env.sh"


# ============================
# ===       Plugins        ===
# ============================
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-battery'
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'
set -g @plugin 'tmux-plugins/tmux-online-status'
set -g @plugin 'tmux-plugins/tmux-sidebar'
set -g @plugin 'tmux-plugins/tmux-copycat'
set -g @plugin 'tmux-plugins/tmux-open'
set -g @plugin 'samoshkin/tmux-plugin-sysstat'

# Plugin properties
set -g @sidebar-tree 't'
set -g @sidebar-tree-focus 'T'
set -g @sidebar-tree-command 'tree -C'

set -g @open-S 'https://www.google.com/search?q='

#run '~/.tmux/plugins/tpm/tpm'
EOF

# ==========================
# | 5. Install Oh My Zsh   |
# ==========================
echo "[*] Installing Oh My Zsh..."
rm -rf $HOME/.oh-my-zsh
sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended

# ==========================
# | 6. Install Zsh Plugins |
# ==========================
wget  https://raw.githubusercontent.com/zthxxx/jovial/refs/heads/master/jovial.zsh-theme -O ~/.oh-my-zsh/themes/jovial.zsh-theme

# ==========================
# | 6. Install Zsh Plugins |
# ==========================
echo "[*] Installing Zsh plugins..."
plugins_name="zsh-autosuggestions zsh-syntax-highlighting git zsh-fzf-history-search"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || true
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || true
git clone --depth=1 https://github.com/joshskidmore/zsh-fzf-history-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-fzf-history-search || true
#sed -E  "s/plugins=\((.+)\)/plugins=\(${plugins_name}\)/g" -i ~/.zshrc

# ==========================
# | 7. Write .zshrc        |
# ==========================
echo "[*] Writing .zshrc..."

cat > ~/.zshrc <<'EOF'
# ==========================
# ===   Zsh Configuration  ===
# ==========================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="jovial"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
source $ZSH/oh-my-zsh.sh

alias ls='exa --icons'
alias l='exa --icons -lh'
alias ll='exa --icons -lah'
alias la='exa --icons -A'
alias lm='exa --icons -m'
alias lr='exa --icons -R'
alias lg='exa --icons -l --group-directories-first'
alias vi='nvim'

##PWNDOC NG Settings###
#alias pwn-start='sudo docker-compose -f  ~/scripts/pwndoc-ng/docker-compose.yml start'
#alias pwn-stop='sudo docker-compose -f  ~/scripts/pwndoc-ng/docker-compose.yml stop'

alias nano='nvim'
export PATH="$PATH:$HOME/.pdtm/go/bin:/usr/local/go/bin/nuclei:/opt/nvim-linux-x86_64/bin:$HOME/.local/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin"
export TERM=xterm-256color
export LANG=C.UTF-8

export VISUAL="vim"
alias xclip="xclip -selection clipboard"
alias clear='clear -x'

# ===========================
# | Python Virtual Environment
# ===========================
venv() { python3 -m venv $1 && source $1/bin/activate; }

echo -e "\033]6;1;bg;red;brightness;40\a"
echo -e "\033]6;1;bg;green;brightness;44\a"
echo -e "\033]6;1;bg;blue;brightness;52\a"

EOF

# ==========================
# | 8. Change Default Shell|
# ==========================
echo '[+] Changing default shell to zsh'
sudo chsh -s "$(command -v zsh)" "$USER"

# ==========================
# | 9. (Optional) Install Nerd Font |
# ==========================
# Uncomment to install Caskaydia Cove Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/CascadiaCode.zip -O /tmp/CascadiaCode.zip
mkdir -p ~/.local/share/fonts ;  unzip /tmp/CascadiaCode.zip 'Caskaydia Cove Nerd Font Complete.ttf' -d ~/.local/share/fonts

#wget https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip -O /tmp/fira_code_font.zip
#mkdir -p ~/.local/share/fonts ;  unzip /tmp/fira_code_font.zip 'Fira Code.ttf' -d ~/.local/share/fonts


# ==========================
# | 10. enabling and starting SSH daemon|
# ==========================

echo "[+] Configuring SSH to allow password authentication..."
sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "[+] Enabling and starting default SSH daemon..."
sudo systemctl enable ssh
sudo systemctl start ssh


# ==========================
# | 11. Installing offsec Tools|
# ==========================
sudo apt remove impacket-scripts -y || true
echo "[*] Installing Offsec tools..."
python3 -m pipx install git+https://github.com/fortra/impacket.git
echo "[*] Installing pipx packages..."
python3 -m pipx ensurepath

echo "[*] Installing bbot..."
pipx install bbot

# ==========================
# | 12. Finalizing and restarting shell |
# ========================== 
echo "[*] Finalizing setup..." 
exec zsh -il

echo "[*] Setup complete! Please restart your terminal or source your shell config."
