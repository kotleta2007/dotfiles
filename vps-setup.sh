#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "=== VPS Setup Script ==="

# Update and install packages
apt-get update
apt-get install -y mosh vim neovim zsh tmux ripgrep curl wget git sudo build-essential python3-pip

# Create user mark
if ! id -u mark &>/dev/null; then
  useradd -m -s /bin/bash mark
  usermod -aG sudo mark
  echo "Set password for user 'mark':"
  passwd mark
fi

# Copy SSH keys from root to mark
if [ -f /root/.ssh/authorized_keys ]; then
  mkdir -p /home/mark/.ssh
  mv /root/.ssh/authorized_keys /home/mark/.ssh/
  chmod 700 /home/mark/.ssh
  chmod 600 /home/mark/.ssh/authorized_keys
  chown -R mark:mark /home/mark/.ssh
  echo "SSH keys moved to mark (root no longer has key access)"
fi

# Ask about additional users
read -p "Create additional users? (y/n): " CREATE_MORE
if [[ $CREATE_MORE == "y" ]]; then
  while true; do
    read -p "Username (or 'done'): " USERNAME
    [[ $USERNAME == "done" ]] && break
    
    if ! id -u $USERNAME &>/dev/null; then
      useradd -m -s /bin/bash $USERNAME
      read -p "Add to sudo? (y/n): " ADD_SUDO
      [[ $ADD_SUDO == "y" ]] && usermod -aG sudo $USERNAME
      passwd $USERNAME
    fi
  done
fi

# Setup Vim (assuming vimrc file exists)
if [ -f ~/vimrc ]; then
  cp ~/vimrc /etc/vim/vimrc.local
  echo "Vim configured"
else
  echo "Warning: vimrc file not found"
fi

# Setup Neovim (assuming neovimrc file exists)
if [ -f ~/neovimrc ]; then
  mkdir -p /etc/xdg/nvim
  cp ~/neovimrc /etc/xdg/nvim/init.vim
  echo "Neovim configured"
else
  echo "Warning: neovimrc file not found"
fi

# Install Oh My Zsh for root
export RUNZSH=no
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /root/.zshrc
echo 'export EDITOR=vim' >> /root/.zshrc
chsh -s $(which zsh) root

# Install Oh My Zsh for mark  
sudo -u mark bash -c 'cd /home/mark && HOME=/home/mark sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="agnoster"/' /home/mark/.zshrc
echo 'export EDITOR=nvim' >> /home/mark/.zshrc

# Add tmux auto-start for mark
cat >> /home/mark/.zshrc << 'EOF'

# Auto-start tmux
if [[ -z "$TMUX" ]] && [[ "$SSH_TTY" ]] && [[ ! "$TERMINAL_EMULATOR" ]]; then
    tmux attach-session -t default || tmux new-session -s default
fi
EOF

chsh -s $(which zsh) mark
chown -R mark:mark /home/mark

# Setup tmux for mark (assuming tmux.conf file exists)
if [ -f ~/tmux.conf ]; then
  cp ~/tmux.conf /home/mark/.tmux.conf
  chown mark:mark /home/mark/.tmux.conf
  
  # Install TPM for mark
  sudo -u mark git clone https://github.com/tmux-plugins/tpm /home/mark/.tmux/plugins/tpm
  
  # Install plugins
  sudo -u mark /home/mark/.tmux/plugins/tpm/bin/install_plugins
  
  echo "tmux configured for mark"
else
  echo "Warning: tmux.conf file not found"
fi

# Install uv system-wide
export UV_INSTALL_DIR="/usr/local/bin"
curl -LsSf https://astral.sh/uv/install.sh | sh

# SSH keys for GitHub
read -p "Generate SSH keys for GitHub? (y/n): " GEN_SSH
if [[ $GEN_SSH == "y" ]]; then
  read -p "Enter email for SSH key: " SSH_EMAIL
  
  sudo -u mark bash -c "
    ssh-keygen -t ed25519 -C \"$SSH_EMAIL\" -f /home/mark/.ssh/id_ed25519 -N ''
    eval \"\$(ssh-agent -s)\"
    ssh-add /home/mark/.ssh/id_ed25519
    echo ''
    echo 'Public SSH key for GitHub:'
    cat /home/mark/.ssh/id_ed25519.pub
  "
fi

echo ""
echo "Setup complete!"
echo "Log out and back in as 'mark' to activate Zsh"

