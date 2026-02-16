# SIIMUT Docker Deployment Guide

## Overview
This guide covers building, pushing, and deploying SIIMUT application using Docker.

## Architecture
- **Image**: Self-contained production-ready image with all code, dependencies, and assets
- **Tag**: `siimut:dev` (development/testing version)
- **Registry**: Configurable via `REGISTRY_URL` in `.env`

## Prerequisites

### Local Build Machine
- Docker installed
- Git
- PHP 8.1+
- Composer
- Node.js 16+ & npm

### Production Server
- Docker & Docker Compose installed
- Access to Docker registry
- Network access to database

## Workflow

### 1. Prepare & Build Locally

```bash
# Step 1: Prepare - Pull code, build frontend, publish Livewire assets
./prepare-siimut.sh

# Step 2: Build & Push to registry
# Edit .env first to set your REGISTRY_URL
./build-push-dev.sh
```

**What happens:**
- ✅ Pull latest code from Git
- ✅ Run `composer install`
- ✅ Run `npm install && npm run build`
- ✅ Publish Livewire assets to `public/vendor/livewire/`
- ✅ Build Docker image: `siimut:dev`
- ✅ Tag for registry: `${REGISTRY_URL}/siimut:dev`
- ✅ Push to registry

### 2. Deploy to Server

#### Option A: Pull & Run (Recommended)

On production server:

```bash
# Step 1: Set registry URL
export REGISTRY_URL=localhost:5000  # Change to your registry

# Step 2: Pull image
docker pull ${REGISTRY_URL}/siimut:dev

# Step 3: Create .env file (if not exists)
cp .env.example .env
# Edit .env for database, APP_URL, etc.

# Step 4: Run with compose
docker compose -f docker-compose-multi-apps.yml up -d

# Step 5: Check status
docker compose -f docker-compose-multi-apps.yml ps
docker compose -f docker-compose-multi-apps.yml logs app-siimut
```

#### Option B: Deploy with .env

```bash
# Copy this file to server:
# - docker-compose-multi-apps.yml
# - .env (configure DB, ports, etc.)
# - DockerNew/nginx/ (nginx configs)

# On server:
REGISTRY_URL=your-registry-url docker compose -f docker-compose-multi-apps.yml up -d
```

### 3. Post-Deployment

```bash
# Run migrations (first time only)
docker compose -f docker-compose-multi-apps.yml exec app-siimut php artisan migrate --force

# Seed database (first time only)
docker compose -f docker-compose-multi-apps.yml exec app-siimut php artisan db:seed --force

# Check health
curl http://localhost:8000/health
```

## Configuration

### Registry Configuration (`.env`)

```env
# Local registry
REGISTRY_URL=localhost:5000

# Docker Hub
REGISTRY_URL=docker.io/yourusername

# GitHub Container Registry
REGISTRY_URL=ghcr.io/yourusername

# GitLab Container Registry
REGISTRY_URL=registry.gitlab.com/yourproject
```

### Docker Compose Environment Variables

Edit `docker-compose-multi-apps.yml` or override via `.env`:

```yaml
environment:
  APP_ENV: production
  APP_URL: "http://your-domain.com:8000"
  DB_HOST: database-service
  DB_USERNAME: siimut_user
  DB_PASSWORD: siimut-password
  DB_DATABASE: siimut_db
  USE_SSO: "false"
  IAM_ENABLED: "false"
```

## Troubleshooting

### Build Issues

**Problem**: npm build fails
```bash
# Solution: Clean and retry
cd site/siimut
rm -rf node_modules package-lock.json
npm install
npm run build
```

**Problem**: Livewire JS 404
```bash
# Solution: Publish assets
cd site/siimut
php artisan livewire:publish --assets
```

### Runtime Issues

**Problem**: Login POST method not allowed
```bash
# Check if Livewire assets loaded
docker compose -f docker-compose-multi-apps.yml exec app-siimut ls -la /var/www/siimut/public/livewire

# Verify symlink
docker compose -f docker-compose-multi-apps.yml exec app-siimut ls -la /var/www/siimut/public/livewire
```

**Problem**: Database connection failed
```bash
# Check DB service
docker compose -f docker-compose-multi-apps.yml ps database-service

# Check environment variables
docker compose -f docker-compose-multi-apps.yml exec app-siimut env | grep DB_
```

### Clear Cache

```bash
docker compose -f docker-compose-multi-apps.yml exec app-siimut php artisan cache:clear
docker compose -f docker-compose-multi-apps.yml exec app-siimut php artisan config:clear
docker compose -f docker-compose-multi-apps.yml exec app-siimut php artisan view:clear
docker compose -f docker-compose-multi-apps.yml restart app-siimut
```

## Image Details

### What's Included
- ✅ PHP 8.4 FPM (Alpine)
- ✅ Laravel framework & vendor dependencies
- ✅ Frontend assets (npm build output)
- ✅ Livewire JavaScript assets
- ✅ All application code (app/, config/, routes/, resources/, database/)
- ✅ Optimized for production (OPcache, APCu, JIT)

### What's NOT Included (Volumes)
- ❌ `storage/` - Uses Docker volume (persistent uploads, logs)
- ❌ `bootstrap/cache/` - Uses Docker volume (cached configs)
- ❌ `public/` - Uses Docker volume (shared with Nginx)

## Registry Setup

### Local Registry (for testing)

```bash
# Start local registry
docker run -d -p 5000:5000 --name registry registry:2

# Build & push
REGISTRY_URL=localhost:5000 ./build-push-dev.sh

# Pull on another machine
docker pull localhost:5000/siimut:dev
```

### Docker Hub

```bash
# Login
docker login

# Update .env
REGISTRY_URL=docker.io/yourusername

# Build & push
./build-push-dev.sh
```

### GitHub Container Registry

```bash
# Create PAT (Personal Access Token) with write:packages permission
# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Update .env
REGISTRY_URL=ghcr.io/yourusername

# Build & push
./build-push-dev.sh
```

## Quick Reference

### Build Commands
```bash
./prepare-siimut.sh              # Prepare local artifacts
./build-push-dev.sh              # Build & push to registry
```

### Deploy Commands
```bash
docker compose -f docker-compose-multi-apps.yml pull  # Pull latest
docker compose -f docker-compose-multi-apps.yml up -d # Start services
docker compose -f docker-compose-multi-apps.yml ps    # Check status
docker compose -f docker-compose-multi-apps.yml logs -f app-siimut  # View logs
```

### Maintenance Commands
```bash
# Restart app
docker compose -f docker-compose-multi-apps.yml restart app-siimut

# Update image
docker compose -f docker-compose-multi-apps.yml pull app-siimut
docker compose -f docker-compose-multi-apps.yml up -d app-siimut

# Shell access
docker compose -f docker-compose-multi-apps.yml exec app-siimut sh
```

## Server Requirements

### Minimum
- CPU: 1 core
- RAM: 2GB
- Disk: 10GB

### Recommended
- CPU: 2 cores
- RAM: 4GB
- Disk: 20GB SSD

## Notes

- Image is **self-contained** - no code volume mounts needed on server
- Only **data volumes** (storage, cache) persist between container restarts
- Update workflow: Build locally → Push to registry → Pull on server → Restart container
- For production, use proper secrets management (not .env files in repo)
