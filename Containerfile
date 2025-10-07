# Multi-stage build for Mist Webhook Monitor

# Stage 1: Build Angular frontend
FROM node:20.15.0-slim AS angular-builder

WORKDIR /build

# Copy Angular app source
COPY ./mist-webhook-monitor/package*.json ./
RUN npm install

COPY ./mist-webhook-monitor/ ./

# Build Angular app with production configuration
RUN npm run build -- --deploy-url /ng/


# Stage 2: Build final image with Node.js backend
FROM node:20.15.0-slim

LABEL fr.mist-lab.mwm.version="0.0.1"
LABEL fr.mist-lab.mwm.release-date="2022-03-21"
LABEL maintainer="Mist Webhook Monitor"

# Copy backend source
COPY ./src /app/

# Copy built Angular app from builder stage
COPY --from=angular-builder /build/dist/mist-webhook-monitor /app/public/ng/
COPY --from=angular-builder /build/dist/mist-webhook-monitor/index.html /app/views/index.html

WORKDIR /app

# Install backend dependencies
RUN npm install --omit=dev

# Create directory for SSL certificates (if needed)
RUN mkdir -p /app/certs

# Expose HTTP and HTTPS ports
EXPOSE 3000 3443

# Environment variables with default values
ENV NODE_PORT_HTTP=3000 \
    NODE_PORT_HTTPS=3443 \
    MONGO_DB=webhook_mon

# Start the application
ENTRYPOINT ["npm", "start"]
