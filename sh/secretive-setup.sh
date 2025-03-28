#!/bin/bash

# ================================
# Secretive SSH Setup (macOS only)
# ================================

set -e
# If running with sudo, determine the original user
if [ "$SUDO_USER" ]; then
  TARGET_USER="$SUDO_USER"
else
  TARGET_USER="$(whoami)"
fi
TARGET_GROUP=$(id -gn "$TARGET_USER")
HOME_DIR=$(eval echo "~$TARGET_USER")
SSH_CONFIG="$HOME_DIR/.ssh/config"

# Ensure SSH config file exists with correct permissions
if [ ! -f "$SSH_CONFIG" ]; then
  echo "📁 SSH config not found. Creating..."
  sudo touch "$SSH_CONFIG"
  sudo chown "$TARGET_USER":"$TARGET_GROUP" "$SSH_CONFIG"
fi
echo "🔐 Setting correct permissions..."
sudo chmod 600 "$SSH_CONFIG"


# ================================
# Ensure Global Block is at the Top
# ================================

if ! grep -q "Host !github.com" "$SSH_CONFIG"; then
  echo "🧱 Adding global SSH settings at top..."
  GLOBAL_BLOCK="Host !github.com
    ServerAliveCountMax 3
    ServerAliveInterval 60
"
  TEMP_CONFIG=$(mktemp)
  # Prepend global block + rest of config
  echo "$GLOBAL_BLOCK" | cat - "$SSH_CONFIG" > "$TEMP_CONFIG"
  sudo cp "$TEMP_CONFIG" "$SSH_CONFIG"
  sudo chmod 600 "$SSH_CONFIG"
  rm "$TEMP_CONFIG"
else
  echo "✅ Global SSH settings already exist."
fi


# ================================
# Host selection prompt
# ================================

# Host selection prompt
echo "🔧 What type of host do you want to configure?"
echo "1) SSH Server"
echo "2) GitHub Host"
read -p "Enter 1 or 2: " HOST_TYPE

if [[ "$HOST_TYPE" == "1" ]]; then
  HOST_KIND="ssh"
elif [[ "$HOST_TYPE" == "2" ]]; then
  HOST_KIND="github"
else
  echo "❌ Invalid selection. Exiting."
  exit 1
fi

# Friendly alias prompt
echo "🆔 Server name:"
read SERVER_NAME
SERVER_TITLE="$(tr '[:lower:]' '[:upper:]' <<< "${SERVER_NAME:0:1}")${SERVER_NAME:1}"
HOST_ALIAS="$HOST_KIND.$SERVER_NAME.com"

# Secretive public key
echo "🔑 Path to Secretive public key:"
read SECRETIVE_PUBLIC_KEY_PATH

# Setup GitHub Host
if [[ "$HOST_KIND" == "github" ]]; then
  CONFIG_BLOCK=$(cat <<EOF

Host $HOST_ALIAS
    IdentityAgent $HOME_DIR/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
    IdentityFile $SECRETIVE_PUBLIC_KEY_PATH
    IdentitiesOnly yes
    HostName github.com
EOF
)

# Setup SSH Host
else
  HOST_NAME=$(hostname)

  echo "🌐 Hostname or IP:"
  read IP


  echo "📦 SSH User:"
  read SSH_USER

  echo "📦 SSH Port [default 22]:"
  read PORT
  PORT=${PORT:-22}

  CONFIG_BLOCK=$(cat <<EOF

Host $HOST_ALIAS
    IdentityAgent $HOME_DIR/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
    IdentityFile $SECRETIVE_PUBLIC_KEY_PATH
    IdentitiesOnly yes
    HostName $IP
    User $SSH_USER
    Port $PORT
EOF
)

fi

# Check for duplicate
if grep -q "Host $HOST_ALIAS" "$SSH_CONFIG"; then
  echo -e "\n⚠️  SSH config already contains an entry for $HOST_ALIAS — skipping append."
else
  echo -e "$CONFIG_BLOCK" | sudo tee -a "$SSH_CONFIG" > /dev/null
  sudo chown "$TARGET_USER":"$TARGET_GROUP" "$SSH_CONFIG"
  echo "✅ SSH config block added for $HOST_ALIAS."
fi

# Optional: Upload public key for SSH hosts
if [[ "$HOST_KIND" == "ssh" ]]; then
  echo -e "\n📤 Upload public key to server for passwordless login? [y/N]"
  read SHOULD_UPLOAD_KEY
  if [[ "$SHOULD_UPLOAD_KEY" =~ ^[Yy]$ ]]; then
    echo "🚀 Uploading key to $HOST_ALIAS..."
    ssh "$HOST_ALIAS" "
      mkdir -p ~/.ssh && chmod 700 ~/.ssh
      touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
      echo \"$(cat $SECRETIVE_PUBLIC_KEY_PATH) $HOST_ALIAS@secretive.$HOST_NAME.local\" >> ~/.ssh/authorized_keys
    "
    echo "✅ Public key uploaded successfully!"
  else
    echo "⏭️  Skipping key upload."
  fi
fi

# ================================
# 🔀 Call Node.js Script to Clean & Sort SSH Config File
# ================================
echo -e "\n🧼 Sorting SSH config with Node.js..."

# URL to your Node.js script on GitHub (raw version)
NODE_SCRIPT_URL="https://raw.githubusercontent.com/windstealth/server-script/refs/heads/main/js/sort-ssh-config.js"

# Download the Node.js script from GitHub
curl -fsSL "$NODE_SCRIPT_URL" -o /tmp/sort-ssh-config.js

# Run the Node.js script
node /tmp/sort-ssh-config.js "$SSH_CONFIG"

# Ensuring correct ownership and permissions for SSH config file
echo "🔐 Ensuring correct ownership and permissions..."
sudo chown "$TARGET_USER":"$TARGET_GROUP" "$SSH_CONFIG"
sudo chmod 600 "$SSH_CONFIG"
echo "✅ Ownership and permissions updated for $SSH_CONFIG."

# Optionally, remove the downloaded script
rm /tmp/sort-ssh-config.js

echo "✅ SSH config sorted and updated using Node.js!"
