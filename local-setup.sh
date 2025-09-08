#!/bin/bash

set -e

echo "=== Local VPS Setup Script ==="

# Get VPS details
read -p "Enter VPS IP address or hostname: " VPS_HOST
read -p "Enter SSH port (default 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
read -p "Enter SSH username (default root): " SSH_USER
SSH_USER=${SSH_USER:-root}

# Check for mosh
if ! command -v mosh &> /dev/null; then
    echo "Error: mosh is not installed. Please install it first."
    exit 1
fi

# Add to known_hosts
ssh-keyscan -p ${SSH_PORT} -H ${VPS_HOST} >> ~/.ssh/known_hosts 2>/dev/null
echo "Added ${VPS_HOST} to known_hosts"

# Check for SSH key
if [ ! -f ~/.ssh/id_rsa.pub ] && [ ! -f ~/.ssh/id_ed25519.pub ]; then
    echo "No SSH key found. Generating new ED25519 key..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
fi

# Copy SSH key to VPS
echo "Copying SSH key to VPS (you'll be prompted for password)..."
ssh-copy-id -p ${SSH_PORT} ${SSH_USER}@${VPS_HOST}

# Add entry to SSH config
echo ""
read -p "Enter SSH config alias for this VPS (e.g., contabo, myserver): " SSH_ALIAS

# Determine which identity file to use
if [ -f ~/.ssh/id_ed25519 ]; then
  IDENTITY_FILE="~/.ssh/id_ed25519"
elif [ -f ~/.ssh/id_rsa ]; then
  IDENTITY_FILE="~/.ssh/id_rsa"
else
  IDENTITY_FILE="~/.ssh/id_ed25519"  # Default, even if generating new
fi

# Create SSH config directory if it doesn't exist
mkdir -p ~/.ssh

# Create new entry in temporary file
cat > ~/.ssh/config.tmp << EOF
Host ${SSH_ALIAS}
  User mark
  HostName ${VPS_HOST}
  IdentityFile ${IDENTITY_FILE}
EOF

# Add port if non-standard
if [ "${SSH_PORT}" != "22" ]; then
  echo "  Port ${SSH_PORT}" >> ~/.ssh/config.tmp
fi

# Add blank line separator
echo "" >> ~/.ssh/config.tmp

# Append existing config if it exists
if [ -f ~/.ssh/config ]; then
  cat ~/.ssh/config >> ~/.ssh/config.tmp
fi

# Replace original config
mv ~/.ssh/config.tmp ~/.ssh/config
chmod 600 ~/.ssh/config

echo "Added SSH config entry for '${SSH_ALIAS}'"
echo "You'll be able to connect with: ssh ${SSH_ALIAS}"

echo ""
echo "Copying setup files to VPS..."

# Check if files exist before copying
FILES_TO_COPY=""
for file in vps-setup.sh vimrc neovimrc tmux.conf; do
  if [ -f "$file" ]; then
    FILES_TO_COPY="$FILES_TO_COPY $file"
  else
    echo "Warning: $file not found, skipping"
  fi
done

if [ -n "$FILES_TO_COPY" ]; then
    scp -P ${SSH_PORT} $FILES_TO_COPY ${SSH_USER}@${VPS_HOST}:~/
    echo "Files copied successfully!"
    
    # Make the script executable on the remote server
    ssh -p ${SSH_PORT} ${SSH_USER}@${VPS_HOST} "chmod +x vps-setup.sh"
    
    echo ""
    echo "Ready! Now SSH in and run the setup:"
    echo "  ssh -p ${SSH_PORT} ${SSH_USER}@${VPS_HOST}"
    echo "  ./vps-setup.sh"
else
    echo "Error: No files to copy. Make sure vps-setup.sh exists."
    exit 1
fi
