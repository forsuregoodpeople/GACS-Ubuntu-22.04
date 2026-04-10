# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GenieACS Auto Install — an automated deployment framework for [GenieACS](https://genieacs.com/), an open-source ACS (Auto Configuration Server) for managing CPE devices via the TR-069/CWMP protocol. Supports two deployment methods: Docker (Ubuntu 18.04–24.04) and native Ubuntu 22.04.

**Note:** Documentation and comments are in Indonesian (Bahasa Indonesia).

## Deployment Commands

### Docker (with ZeroTier VPN)
```bash
./install-genieacs-docker.sh
```

### Docker (without ZeroTier)
```bash
./docker-non-zerotier.sh
```

### Native Ubuntu 22.04
```bash
chmod +x GACS-Jammy.sh && ./GACS-Jammy.sh
```

### Docker Compose Operations
```bash
docker-compose up -d       # Start services
docker-compose restart     # Restart services
docker-compose down        # Stop services
```

### Restore MongoDB Parameters
```bash
# Docker
docker cp ./parameter/ genieacs-server:/tmp/
docker exec genieacs-server mongorestore --db genieacs --collection config --drop /tmp/parameter/config.bson
docker exec genieacs-server mongorestore --db genieacs --collection virtualParameters --drop /tmp/parameter/virtualParameters.bson
docker exec genieacs-server mongorestore --db genieacs --collection presets --drop /tmp/parameter/presets.bson
docker exec genieacs-server mongorestore --db genieacs --collection provisions --drop /tmp/parameter/provisions.bson

# Native
cd parameter && mongorestore --db genieacs --drop .
systemctl restart genieacs-cwmp genieacs-ui genieacs-nbi
```

## Architecture

### Services (managed by Supervisor inside the container)
| Service | Port | Purpose |
|---------|------|---------|
| genieacs-cwmp | 7547 | TR-069 CWMP server — CPE device communication |
| genieacs-nbi | 7557 | North Bound Interface — external integrations |
| genieacs-fs | 7567 | File Server — firmware/config distribution |
| genieacs-ui | 3000 | Web UI dashboard |

MongoDB 4.4 runs on localhost:27017 within the container, storing: `config`, `virtualParameters`, `presets`, and `provisions` collections.

### Key Files
- `Dockerfile` — Ubuntu 22.04 base, Node.js 18, MongoDB 4.4, GenieACS 1.2.13
- `docker-compose.yml` — Full stack with ZeroTier (host networking, privileged mode, 2GB memory limit)
- `docker-compose-simple.yml` — Simplified stack without ZeroTier
- `entrypoint.sh` — Startup: detects ZeroTier, generates JWT secret, starts MongoDB, launches supervisor
- `supervisord.conf` — Process manager for 4 GenieACS services with log rotation and auto-restart
- `config/genieacs.env` — Environment variables (MongoDB URL, interface bindings, log paths, JWT secret)
- `parameter/` — MongoDB BSON backups for initial data seeding

### ZeroTier Integration
The full Docker stack runs in host networking + privileged mode to allow ZeroTier VPN access. The `entrypoint.sh` detects whether ZeroTier is present and adjusts startup accordingly. Use `docker-compose-simple.yml` / `entrypoint-simple.sh` if ZeroTier is not needed.
