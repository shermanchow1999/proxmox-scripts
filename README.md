# WAHA LXC for Proxmox VE

This script creates an LXC container for WAHA (WhatsApp HTTP API) on Proxmox VE, following the community-scripts.github.io format.

## Features

- Automated LXC container creation
- Docker and Docker Compose installation
- WAHA (devlikeapro/waha) setup
- Systemd service for automatic startup
- MOTD with useful information
- Update script included

## Default Container Specs

- **OS**: Debian 12
- **RAM**: 2GB
- **CPU**: 2 cores
- **Disk**: 4GB
- **Port**: 3000

## Installation

### Method 1: Run from Proxmox Shell

```bash
bash -c "$(wget -qLO - https://github.com/YOUR-REPO/waha.sh)"
```

### Method 2: Manual Installation

1. Copy both scripts to your Proxmox host
2. Make them executable:
```bash
chmod +x waha.sh waha-install.sh
```

3. Run the build script:
```bash
./waha.sh
```

### Method 3: Direct from GitHub (when hosted)

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/YOUR-REPO/main/ct/waha.sh)"
```

## Post-Installation

### Access WAHA

- **Swagger UI**: http://YOUR-LXC-IP:3000/
- **API Endpoint**: http://YOUR-LXC-IP:3000/api
- **Health Check**: http://YOUR-LXC-IP:3000/health

### Start a WhatsApp Session

```bash
# Enter the LXC container
pct enter CONTAINER-ID

# Create a session and get QR code
curl -X POST http://localhost:3000/api/sessions/start \
  -H "Content-Type: application/json" \
  -d '{
    "name": "default",
    "config": {
      "noweb": {
        "store": {
          "enabled": true
        }
      }
    }
  }'

# View logs to see QR code
docker compose -f /opt/waha/docker-compose.yml logs -f
```

Scan the QR code with WhatsApp to connect.

## Configuration

### Enable API Authentication

Edit `/opt/waha/docker-compose.yml` and uncomment:

```yaml
environment:
  - WHATSAPP_API_KEY=your-secret-key-here
  - WHATSAPP_API_KEY_HEADER=X-Api-Key
```

Then restart:
```bash
systemctl restart waha
```

### Configure Webhooks

Edit `/opt/waha/docker-compose.yml` and uncomment:

```yaml
environment:
  - WHATSAPP_HOOK_URL=https://your-webhook-url.com/
  - WHATSAPP_HOOK_EVENTS=message,session.status
```

Then restart:
```bash
systemctl restart waha
```

## Management Commands

### Inside the LXC Container

```bash
# View logs
docker compose -f /opt/waha/docker-compose.yml logs -f

# Restart WAHA
systemctl restart waha

# Stop WAHA
systemctl stop waha

# Start WAHA
systemctl start waha

# Check status
systemctl status waha

# Pull latest WAHA image
cd /opt/waha
docker compose pull
docker compose up -d
```

### From Proxmox Host

```bash
# Enter container
pct enter CONTAINER-ID

# Start container
pct start CONTAINER-ID

# Stop container
pct stop CONTAINER-ID

# View container logs
pct console CONTAINER-ID
```

## Update WAHA

### Automatic Update Script

From within the container:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/YOUR-REPO/main/install/waha-install.sh)" -s update
```

### Manual Update

```bash
cd /opt/waha
docker compose pull
docker compose up -d
```

## API Examples

### Send Text Message

```bash
curl -X POST http://localhost:3000/api/sendText \
  -H "Content-Type: application/json" \
  -d '{
    "session": "default",
    "chatId": "1234567890@c.us",
    "text": "Hello from WAHA!"
  }'
```

### Send Image

```bash
curl -X POST http://localhost:3000/api/sendImage \
  -H "Content-Type: application/json" \
  -d '{
    "session": "default",
    "chatId": "1234567890@c.us",
    "file": {
      "mimetype": "image/jpeg",
      "filename": "image.jpg",
      "url": "https://example.com/image.jpg"
    }
  }'
```

### Get Sessions

```bash
curl http://localhost:3000/api/sessions
```

### Get QR Code

```bash
curl http://localhost:3000/api/sessions/default/auth/qr
```

## Troubleshooting

### View WAHA Logs

```bash
docker compose -f /opt/waha/docker-compose.yml logs -f
```

### Check Service Status

```bash
systemctl status waha
```

### Restart Everything

```bash
systemctl restart waha
```

### Check Docker Status

```bash
docker ps
docker compose -f /opt/waha/docker-compose.yml ps
```

### Sessions Not Persisting

Check permissions on sessions directory:
```bash
ls -la /opt/waha/sessions
chmod -R 755 /opt/waha/sessions
```

## File Locations

- **Configuration**: `/opt/waha/docker-compose.yml`
- **Sessions Data**: `/opt/waha/sessions`
- **Media Files**: `/opt/waha/media`
- **Service File**: `/etc/systemd/system/waha.service`
- **Logs**: `docker compose logs`

## Resources

- **WAHA Documentation**: https://waha.devlike.pro/
- **WAHA GitHub**: https://github.com/devlikeapro/waha
- **API Documentation**: http://YOUR-LXC-IP:3000/ (Swagger UI)
- **Community Scripts**: https://community-scripts.github.io/ProxmoxVE/

## Security Notes

1. **Change the default API key** if enabling authentication
2. Consider using **reverse proxy** (nginx/traefik) with SSL for production
3. **Firewall rules**: Restrict port 3000 access if needed
4. **Regular backups**: Backup `/opt/waha/sessions` directory
5. **Update regularly**: Keep WAHA image updated

## License

MIT License - Same as community-scripts

## Credits

Script format inspired by [community-scripts](https://github.com/community-scripts/ProxmoxVE)
