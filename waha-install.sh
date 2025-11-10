#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Sherman (AI-assisted)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD bash <(curl -fsSL https://get.docker.com)
msg_ok "Installed Docker"

msg_info "Installing Docker Compose"
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
LATEST=$(curl -sL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
$STD curl -SL https://github.com/docker/compose/releases/download/$LATEST/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
msg_ok "Installed Docker Compose"

msg_info "Setting Up WAHA"
mkdir -p /opt/waha
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

mkdir -p /opt/waha/sessions
mkdir -p /opt/waha/media
msg_ok "WAHA Setup Complete"

msg_info "Creating Service"
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

systemctl enable -q --now waha.service
msg_ok "Created Service"

msg_info "Starting WAHA"
cd /opt/waha
$STD docker compose up -d
msg_ok "Started WAHA"

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"

motdgen() {
  cat <<'EOF'
 _       ___    __  _____
| |     / / |  / / / /   |
| | /| / /| | / / / / /| |
| |/ |/ / | |/ / / / ___ |
|__/|__/  |___/ /_/_/  |_|

WAHA - WhatsApp HTTP API

EOF
  if systemctl is-active --quiet waha.service; then
    echo -e " ${CHECKMARK} WAHA is running"
  else
    echo -e " ${CROSS} WAHA is not running (systemctl start waha)"
  fi
  echo ""
  echo -e " ${INFO} WAHA API: http://$(hostname -I | awk '{print $1}'):3000"
  echo -e " ${INFO} Swagger UI: http://$(hostname -I | awk '{print $1}'):3000/"
  echo ""
  echo -e " ${INFO} Configuration: /opt/waha/docker-compose.yml"
  echo -e " ${INFO} Sessions: /opt/waha/sessions"
  echo -e " ${INFO} Media: /opt/waha/media"
  echo ""
  echo -e " ${INFO} View logs: docker compose -f /opt/waha/docker-compose.yml logs -f"
  echo -e " ${INFO} Restart: systemctl restart waha"
  echo ""
}

motd_ssh
customize

msg_info "Waiting for WAHA to start (30s)"
sleep 30
msg_ok "WAHA should be ready"

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL:
         ${BL}http://${IP}:3000${CL} \n"
