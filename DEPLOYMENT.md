# Deployment Guide

This guide covers deploying Mist Webhook Monitor using containers (Podman or Docker).

## Quick Start with Docker Compose / Podman Compose

### Prerequisites
- Docker/Podman and Docker Compose/Podman Compose installed
- Access to a Mist Cloud account with organization admin privileges

### Steps

1. **Generate encryption keys** (required for production):
   ```bash
   # Generate MONGO_ENC_KEY
   openssl rand -base64 32

   # Generate MONGO_SIG_KEY
   openssl rand -base64 64
   ```

2. **Create environment file**:
   ```bash
   cp .env.example .env
   ```

   Edit `.env` and set at minimum:
   - `NODE_HOSTNAME` - Your server's public hostname/IP
   - `MONGO_ENC_KEY` - Generated in step 1
   - `MONGO_SIG_KEY` - Generated in step 1
   - `MONGO_USER` - MongoDB username
   - `MONGO_PASSWORD` - MongoDB password (strong password recommended)

3. **Start the application**:

   **With Docker Compose:**
   ```bash
   docker-compose up -d
   ```

   **With Podman Compose:**
   ```bash
   podman-compose up -d
   ```

4. **Access the application**:

   Open your browser to `http://<NODE_HOSTNAME>:3000`

5. **View logs**:
   ```bash
   # Docker
   docker-compose logs -f webhook-monitor

   # Podman
   podman-compose logs -f webhook-monitor
   ```

## Manual Container Build and Run

### Build the container image

**With Docker:**
```bash
docker build -t mist-webhook-monitor -f Containerfile .
```

**With Podman:**
```bash
podman build -t mist-webhook-monitor -f Containerfile .
```

### Run with Podman

1. **Create a network**:
   ```bash
   podman network create mist-webhook-network
   ```

2. **Start MongoDB**:
   ```bash
   podman run -d \
     --name mist-webhook-mongodb \
     --network mist-webhook-network \
     -e MONGO_INITDB_ROOT_USERNAME=mongo_user \
     -e MONGO_INITDB_ROOT_PASSWORD=mongo_password \
     -v mongodb_data:/data/db \
     mongo:7
   ```

3. **Start Mist Webhook Monitor**:
   ```bash
   podman run -d \
     --name mist-webhook-monitor \
     --network mist-webhook-network \
     -p 3000:3000 \
     -p 3443:3443 \
     -e NODE_HOSTNAME=localhost \
     -e MONGO_HOST=mist-webhook-mongodb \
     -e MONGO_DB=webhook_mon \
     -e MONGO_USER=mongo_user \
     -e MONGO_PASSWORD=mongo_password \
     -e MONGO_ENC_KEY=your_enc_key_here \
     -e MONGO_SIG_KEY=your_sig_key_here \
     mist-webhook-monitor
   ```

### Run with Docker

Same as Podman, just replace `podman` with `docker` in all commands.

## Configuration Options

### Using Environment Variables (Recommended)

All configuration can be done through environment variables. See `.env.example` for the full list of available options.

### Using Config File

Alternatively, you can use a configuration file:

1. Copy the example config:
   ```bash
   cp src/config_example.js src/config.js
   ```

2. Edit `src/config.js` with your settings

3. Mount the config file when running:
   ```bash
   # Add to your docker-compose.yml volumes section:
   volumes:
     - ./src/config.js:/app/config.js:ro

   # Or with podman run:
   podman run -d \
     -v ./src/config.js:/app/config.js:ro \
     ... other options ...
     mist-webhook-monitor
   ```

## HTTPS Configuration

To enable HTTPS:

1. Place your SSL certificate and key in a `certs` directory:
   - `certs/your-cert.pem`
   - `certs/your-key.key`

2. Set environment variables:
   ```bash
   NODE_HTTPS=true
   NODE_HTTPS_CERT=your-cert.pem
   NODE_HTTPS_KEY=your-key.key
   ```

3. Mount the certs directory:
   ```bash
   # In docker-compose.yml:
   volumes:
     - ./certs:/app/certs:ro

   # Or with podman run:
   podman run -d \
     -v ./certs:/app/certs:ro \
     ... other options ...
     mist-webhook-monitor
   ```

## Exposed Ports

- **3000** - HTTP port (default)
- **3443** - HTTPS port (when NODE_HTTPS=true)

## Volumes

### MongoDB Data
The MongoDB container uses a volume `mongodb_data` to persist data. This volume is automatically created by Docker Compose/Podman Compose.

### Optional Mounts
- `/app/config.js` - Configuration file (read-only)
- `/app/certs` - SSL certificates directory (read-only)

## Health Checks

The application includes health checks:
- **MongoDB**: Checks database connectivity every 10s
- **Webhook Monitor**: Checks HTTP endpoint every 30s

## Troubleshooting

### Check container logs
```bash
# Docker Compose
docker-compose logs -f

# Podman Compose
podman-compose logs -f

# Single container
podman logs -f mist-webhook-monitor
```

### Verify MongoDB connection
```bash
podman exec -it mist-webhook-mongodb mongosh -u mongo_user -p mongo_password
```

### Common Issues

1. **Cannot connect to MongoDB**
   - Ensure MongoDB container is running: `podman ps`
   - Check network connectivity: Both containers must be on the same network
   - Verify MONGO_HOST matches MongoDB container name

2. **Port already in use**
   - Change the host port mapping: `-p 8080:3000` instead of `-p 3000:3000`
   - Update NODE_PORT_HTTP environment variable accordingly

3. **Webhooks not received from Mist Cloud**
   - Ensure NODE_WEBHOOK_HOSTNAME is set to your public IP/hostname
   - Check firewall allows incoming connections on configured port
   - Verify NAT/port forwarding if behind a router

## Production Recommendations

1. **Always set strong encryption keys** (MONGO_ENC_KEY, MONGO_SIG_KEY)
2. **Use HTTPS** for production deployments
3. **Set a strong MongoDB password**
4. **Use a reverse proxy** (nginx, Traefik) for SSL termination and load balancing
5. **Enable MongoDB authentication** (included in the compose file)
6. **Backup MongoDB data volume** regularly
7. **Set appropriate NODE_WEBHOOK_HOSTNAME** to your public FQDN

## Updating the Application

```bash
# Pull latest code
git pull

# Rebuild the container
docker-compose build

# Restart services
docker-compose up -d
```

## Stopping the Application

```bash
# Docker Compose
docker-compose down

# To remove volumes as well (WARNING: This deletes MongoDB data)
docker-compose down -v
```
