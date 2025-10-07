# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mist Webhook Monitor is a full-stack application that captures and displays webhook events from the Mist Cloud platform. The application consists of:

1. **Backend (Node.js/Express)** - Located in `src/`
   - Webhook collector that receives events from Mist Cloud
   - API server for authentication and session management
   - WebSocket server for real-time event forwarding to browsers
   - MongoDB for session persistence and data storage

2. **Frontend (Angular)** - Located in `mist-webhook-monitor/`
   - Single-page application for displaying webhook events
   - Real-time dashboard with WebSocket communication
   - Authentication with Mist Cloud API

## Build and Development Commands

### Container Deployment (Recommended)

**Build container image:**
```bash
# With Podman
podman build -t mist-webhook-monitor -f Containerfile .

# With Docker
docker build -t mist-webhook-monitor -f Containerfile .
```

**Run with Docker Compose/Podman Compose:**
```bash
# Copy and configure environment variables
cp .env.example .env
# Edit .env with your settings

# Start all services (app + MongoDB)
docker-compose up -d
# or
podman-compose up -d

# View logs
docker-compose logs -f webhook-monitor
```

See `DEPLOYMENT.md` for detailed container deployment instructions.

### Backend (Node.js)
```bash
# Install dependencies
cd src
npm install

# Start the backend server
npm start

# The server runs on port 3000 (HTTP) or 3443 (HTTPS if configured)
```

### Frontend (Angular)
```bash
# Install dependencies
cd mist-webhook-monitor
npm install

# Start development server with proxy
npm start
# Access at http://localhost:4200

# Build for production
npm run build

# Run tests
npm test
```

### Build Angular and Deploy to Backend
The `angular-build.sh` script builds the Angular app and copies it to the backend's public directory:
```bash
./angular-build.sh
```
This script:
1. Builds the Angular app with deploy URL `/ng/`
2. Copies build artifacts to `src/public/ng/`
3. Copies `index.html` to `src/views/index.html`

## Architecture

### Backend Architecture

**Entry Point**: `src/bin/www` starts both HTTP/HTTPS and WebSocket servers

**Core Components**:

1. **Application Setup** (`src/app.js`)
   - Loads configuration from `src/config.js` or environment variables
   - Initializes MongoDB connection and session store
   - Sets up Express middleware and routes
   - Creates PubSubManager instance for webhook distribution

2. **Route Handlers** (`src/routes/`)
   - `monitor.js` - Serves the Angular frontend
   - `api.js` - Authentication and session management endpoints
   - `webhook.js` - Receives webhook events from Mist Cloud

3. **Webhook System** (`src/bin/`)
   - `webhook_pubsub.js` - PubSubManager class manages WebSocket subscriptions by org_id and topic
   - `webhook_sub.js` - Creates webhook configuration in Mist Org when user subscribes
   - `webhook_unsub.js` - Removes webhook configuration when user unsubscribes
   - `mist_webhook.js` - Handles webhook lifecycle (create/delete in Mist Cloud)
   - `websocket.js` - WebSocket connection handler, processes subscribe/unsubscribe messages

4. **Mist API Integration** (`src/bin/`)
   - `mist_login.js` - Handles Mist Cloud authentication (including 2FA)
   - `mist_token.js` - Creates Org API tokens for webhook management
   - `req.js` - HTTP request wrapper for Mist API calls

5. **Data Models** (`src/bin/models/`)
   - `session.js` - Stores browser session subscriptions (session_id, org_id, topics)
   - `webhook.js` - Stores webhook configurations

### Frontend Architecture

**Entry Point**: `mist-webhook-monitor/src/main.ts` bootstraps the Angular app

**Routing** (`app-routing.module.ts`):
- `/login` - Authentication with Mist Cloud
- `/monitor` - Dashboard for viewing webhook events
- All other routes redirect to `/login`

**Components**:
1. **Login Component** - Authenticates users against Mist Cloud API
2. **Dashboard Component** - Main view with:
   - `config/` - Configuration panel for selecting org and webhook topics
   - `diagram/` - Visual representation of webhook flow
   - `raw_data/` - Table displaying webhook messages in real-time

**Services**:
- `auth.service.ts` - Handles authentication state and API calls to backend

### Communication Flow

1. User authenticates via Angular frontend → Backend API (`/api/login`) → Mist Cloud API
2. Frontend establishes WebSocket connection to backend
3. User selects org and topics → Backend calls `webhook_sub.js` → Creates webhook in Mist Org
4. Mist Cloud sends webhook events → Backend webhook collector (`/wh-collector/`)
5. Backend PubSubManager publishes to subscribed WebSocket clients
6. Frontend displays webhook events in real-time table

### Webhook Topics
The application supports monitoring these Mist webhook topics:
- `alarms`
- `audits`
- `device-events`
- `device-updowns`
- `mxedge-events`

## Configuration

Configuration is handled via `src/config.js` (see `src/config_example.js` for template). Key settings:

- **NODE_HOSTNAME** - Server FQDN for the web UI
- **NODE_WEBHOOK_HOSTNAME** - Public IP/FQDN for receiving webhooks from Mist Cloud
- **MONGO_HOST** - MongoDB connection string
- **MONGO_ENC_KEY/MONGO_SIG_KEY** - Encryption keys for sensitive data (generate with `openssl rand -base64 32` and `openssl rand -base64 64`)

Environment variables override config file settings (see README.md for full list).

## Database Schema

**Sessions Collection**:
- `session_id` - Browser session identifier
- `org_id` - Mist organization ID
- `topics` - Array of subscribed webhook topics
- `last_ping` - Timestamp for cleanup

**Webhooks Collection**:
- Stores webhook configurations per org/topic combination

## Important Notes

- The application creates Org API Tokens in Mist Cloud that must be manually deleted by administrators (programmatic deletion not supported by Mist API)
- WebSocket connections persist across server restarts by reloading sessions from MongoDB
- The cleanup job (`src/bin/clean.js`) runs every 15 minutes to remove stale sessions
- Multiple simultaneous sessions from the same org share a single webhook configuration in Mist Cloud
