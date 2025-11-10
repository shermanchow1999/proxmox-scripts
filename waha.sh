#!/usr/bin/env bash

# WAHA LXC Installation Script for Proxmox VE
# Author: Sherman (AI-assisted)
# License: MIT

# Color definitions
YW='\033[33m'
BL='\033[36m'
RD='\033[01;31m'
BGN='\033[4;92m'
GN='\033[1;92m'
DGN='\033[32m'
CL='\033[m'
CHECKMARK='\033[0;32m\xE2\x9C\x94\033[0m'
CROSS='\033[0;31m\xE2\x9C\x97\033[0m'
INFO='\033[0;34mℹ\033[0m'

# Default settings
APP="WAHA"
CTID=""
HOSTNAME="waha"
DISK_SIZE="8"
CORES="2"
RAM="2048"
BRIDGE="vmbr0"
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

# Functions
msg_info() {
  echo -e "${BL}[INFO]${CL} $1"
}

msg_ok() {
  echo -e "${GN}[OK]${CL} $1"
}

msg_error() {
  echo -e "${RD}[ERROR]${CL} $1"
  exit 1
}

# Header
clear
cat <<"EOF"
 _       ___    __  _____
| |     / / |  / / / /   |
| | /| / /| | / / / / /| |
| |/ |/ / | |/ / / / ___ |
|__/|__/  |___/ /_/_/  |_|

WAHA LXC Installer for Proxmox VE
EOF
echo ""

# Get next available CTID
CTID=$(pvesh get /cluster/nextid)
echo -e "${YW}Next available CTID: ${GN}$CTID${CL}"
read -p "Use this CTID or enter custom (press Enter for $CTID): " CUSTOM_CTID
CTID=${CUSTOM_CTID:-$CTID}

# Confirm settings
echo ""
echo -e "${YW}Container Settings:${CL}"
echo -e "  CTID: ${GN}$CTID${CL}"
echo -e "  Hostname: ${GN}$HOSTNAME${CL}"
echo -e "  Disk: ${GN}${DISK_SIZE}GB${CL}"
echo -e "  Cores: ${GN}$CORES${CL}"
echo -e "  RAM: ${GN}${RAM}MB${CL}"
echo -e "  Bridge: ${GN}$BRIDGE${CL}"
echo ""
read -p "Continue with these settings? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  msg_error "Installation cancelled"
fi

# Check if template exists
msg_info "Checking for Debian 12 template..."
if ! pveam list $STORAGE | grep -q "debian-12"; then
  msg_info "Downloading Debian 12 template..."
  pveam download local debian-12-standard_12.7-1_amd64.tar.zst
fi
msg_ok "Template ready"

# Create container
msg_info "Creating LXC container..."
pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --memory $RAM \
  --cores $CORES \
  --rootfs $STORAGE:$DISK_SIZE \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --unprivileged 0 \
  --features nesting=1,keyctl=1 \
  --onboot 1 \
  --start 0

if [ $? -ne 0 ]; then
  msg_error "Failed to create container"
fi
msg_ok "Container created (CTID: $CTID)"

# Configure container for Docker
msg_info "Configuring container for Docker..."
pct set $CTID -features nesting=1,keyctl=1
pct set $CTID -onboot 1

# Start container
msg_info "Starting container..."
pct start $CTID

# Wait for container to start
msg_info "Waiting for container to start..."
sleep 5
msg_ok "Container started"

# Installation script
msg_info "Installing WAHA..."
pct exec $CTID -- bash -c 'cat > /tmp/install.sh' << 'INSTALL_EOF'
#!/bin/bash

# Update system
echo "Updating system..."
apt-get update &>/dev/null
apt-get upgrade -y &>/dev/null

# Install dependencies
echo "Installing dependencies..."
apt-get install -y curl sudo mc &>/dev/null

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh &>/dev/null
rm get-docker.sh

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
curl -SL https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose &>/dev/null
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# Setup WAHA
echo "Setting up WAHA..."
mkdir -p /opt/waha/sessions /opt/waha/media

cat <<'EOF' >/opt/waha/docker-compose.yml
version: '3'
services:
  waha:
    image: devlikeapro/waha:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - WAHA_PRINT_QR=True
      - WHATSAPP_DEFAULT_ENGINE=NOWEB
      # Uncomment below to enable API authentication
      # - WHATSAPP_API_KEY=your-secret-key-here
      # - WHATSAPP_API_KEY_HEADER=X-Api-Key
      # Uncomment below to configure webhook
      # - WHATSAPP_HOOK_URL=https://your-webhook-url.com/
      # - WHATSAPP_HOOK_EVENTS=message,session.status
    volumes:
      - ./sessions:/app/.sessions
      - ./media:/app/media
    networks:
      - waha-network

networks:
  waha-network:
    driver: bridge
EOF

# Create systemd service
cat <<'EOF' >/etc/systemd/system/waha.service
[Unit]
Description=WAHA (WhatsApp HTTP API)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/waha
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose restart

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now waha.service &>/dev/null

# Start WAHA
cd /opt/waha
docker compose pull &>/dev/null
docker compose up -d &>/dev/null

# Create MOTD
cat <<'EOF' >/etc/update-motd.d/99-waha
#!/bin/bash
cat <<"MOTD"
 _       ___    __  _____
| |     / / |  / / / /   |
| | /| / /| | / / / / /| |
| |/ |/ / | |/ / / / ___ |
|__/|__/  |___/ /_/_/  |_|

WAHA - WhatsApp HTTP API
MOTD

if systemctl is-active --quiet waha.service; then
  echo " ✓ WAHA is running"
else
  echo " ✗ WAHA is not running (systemctl start waha)"
fi
echo ""
echo " ℹ WAHA API: http://$(hostname -I | awk '{print $1}'):3000"
echo " ℹ Swagger UI: http://$(hostname -I | awk '{print $1}'):3000/"
echo ""
echo " ℹ Configuration: /opt/waha/docker-compose.yml"
echo " ℹ Sessions: /opt/waha/sessions"
echo " ℹ View logs: docker compose -f /opt/waha/docker-compose.yml logs -f"
echo " ℹ Restart: systemctl restart waha"
echo ""
EOF
chmod +x /etc/update-motd.d/99-waha
rm -f /etc/update-motd.d/10-uname

echo "Installation complete!"
INSTALL_EOF

pct exec $CTID -- bash /tmp/install.sh
if [ $? -ne 0 ]; then
  msg_error "Installation failed"
fi
msg_ok "WAHA installed successfully"

# Get container IP
msg_info "Retrieving container IP..."
sleep 3
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
msg_ok "Container IP: $IP"

# Cleanup
pct exec $CTID -- rm /tmp/install.sh

# Final message
echo ""
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${GN}${CHECKMARK} WAHA Installation Complete!${CL}"
echo -e "${GN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo ""
echo -e "${YW}Access WAHA at:${CL}"
echo -e "  ${BL}http://${IP}:3000${CL} (Swagger UI)"
echo ""
echo -e "${YW}Quick Start:${CL}"
echo -e "  1. Access container: ${GN}pct enter $CTID${CL}"
echo -e "  2. View logs: ${GN}docker compose -f /opt/waha/docker-compose.yml logs -f${CL}"
echo -e "  3. Create session via API and scan QR code"
echo ""
echo -e "${YW}Useful Commands:${CL}"
echo -e "  Start: ${GN}pct start $CTID${CL}"
echo -e "  Stop: ${GN}pct stop $CTID${CL}"
echo -e "  Console: ${GN}pct console $CTID${CL}"
echo -e "  Shell: ${GN}pct enter $CTID${CL}"
echo ""
echo -e "${INFO} Configuration: /opt/waha/docker-compose.yml"
echo -e "${INFO} Documentation: https://waha.devlike.pro/"
echo ""
