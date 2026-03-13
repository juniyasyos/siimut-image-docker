# Multi-App Setup - Implementation Summary

## ✅ What Changed

### 1. Updated `docker-compose-multi-apps.yml`
- **Added**: 3 IKP services (app-ikp, queue-ikp, scheduler-ikp)
- **Updated**: Nginx configuration untuk 3 ports (8000, 8001, 8002)
- **Added**: IKP volumes (ikp_storage, ikp_bootstrap_cache, ikp_public)
- **Removed**: Database service (now in compose.base.yml)
- **Removed**: Network definition (inherited from base.yml)
- **Renamed**: Compose name dari `service-app` menjadi `service-app-multi`

### 2. Created `Dockerfile.ikp-registry`
- Self-contained image untuk IKP app
- Same pattern dengan SIIMUT Dockerfile
- Production-optimized dengan OPCache & APCu
- Located: `DockerNew/php/Dockerfile.ikp-registry`

### 3. Infrastructure Setup
- **Base compose** (`compose/compose.base.yml`): Caddy, Database, phpMyAdmin, shared network
- **Apps compose** (`docker-compose-multi-apps.yml`): Nginx + multiple Laravel apps

## 🎯 How to Use

### Build & Start
```bash
# Build
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml build

# Start
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml up -d

# Logs
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml logs -f
```

### Run Migrations
```bash
# SIIMUT
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-siimut php artisan migrate

# IKP
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp php artisan migrate
```

### Scaling Resources
Edit di `docker-compose-multi-apps.yml` untuk setiap service:
```yaml
deploy:
  resources:
    limits:
      memory: 1.5G    # ← ubah sesuai kebutuhan
      cpus: "1.5"     # ← ubah sesuai kebutuhan
```

## 📊 Services Breakdown

| Service | Role | Port | Resources |
|---------|------|------|-----------|
| web (Nginx) | Router | 8000, 8001 | 256MB mem, 0.2 CPU |
| app-siimut | SIIMUT App | - | 1.5GB mem, 1.5 CPU |
| queue-siimut | SIIMUT Queue | - | 512MB mem, 1.0 CPU |
| scheduler-siimut | SIIMUT Scheduler | - | 256MB mem, 0.25 CPU |
| app-ikp (NEW!) | IKP App | - | 1.5GB mem, 1.5 CPU |
| queue-ikp (NEW!) | IKP Queue | - | 512MB mem, 1.0 CPU |
| scheduler-ikp (NEW!) | IKP Scheduler | - | 256MB mem, 0.25 CPU |
| database | MariaDB (from base) | internal | 512MB mem, 1.0 CPU |
| web (Caddy - from base) | SSL/TLS | 8080, 443 | - |
| phpmyadmin (from base) | DB Admin | 9000 | - |

## 🔄 Migration Path

**Old Setup (untuk reference)**:
- Single compose file: `docker-compose.yml` atau `docker-compose-multi-apps.yml` (2 apps only)
- Manual database management

**New Setup**:
- Base infra: `compose/compose.base.yml` (shared resources)
- Apps layer: `docker-compose-multi-apps.yml` (scales untuk banyak apps)
- Easy to add app ke-4, ke-5, dst

## ⚠️ Important Notes

### Untuk Repository IKP
```bash
# Clone IKP ke folder yang benar
git clone https://github.com/juniyasyos/ikp.git site/ikp

# Pastikan ada:
# - site/ikp/composer.json
# - site/ikp/composer.lock
# - site/ikp/.env (atau auto-generate via entrypoint)
```

### Nginx Configuration
Perlu update `DockerNew/nginx/nginx-multi-apps.conf` untuk route:
```nginx
# SIIMUT (port 8000)
upstream siimut { server app-siimut:9000; }
server {
    listen 8000;
    # ... forward to siimut upstream
}

# IKP (port 8001)
upstream ikp { server app-ikp:9000; }
server {
    listen 8001;
    # ... forward to ikp upstream
}
```

### Database Credentials

**SIIMUT**:
- User: `siimut_user`
- Password: `siimut-password`
- Database: `siimut_db`

**IKP** (NEW):
- User: `ikp_user`
- Password: `ikp-password`
- Database: `ikp_db`

## 🗑️ Files to Clean Up

- `docker-compose-three-apps.yml` ← Can be deleted, merged into docker-compose-multi-apps.yml
- `SETUP-THREE-APPS.md` ← Can be archived, replaced by README-MULTI-APP.md

## 📖 Documentation

- **README-MULTI-APP.md**: Panduan lengkap multi-app setup
- **docker-compose.yml**: Single app development (unchanged)
- **compose/compose.base.yml**: Base infrastructure (existing, now required)

## 🔍 Quick Verification

```bash
# Check all services running
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml ps

# Expected output:
# SIIMUT services: app-siimut, queue-siimut, scheduler-siimut
# IKP services: app-ikp, queue-ikp, scheduler-ikp  
# Nginx: web
# Database: database-service (atau nama yang lain dari base)
# Plus services dari base: web (Caddy), db, phpmyadmin

# Test app connectivity
curl http://localhost:8000  # SIIMUT
curl http://localhost:8001  # IKP

# Test database
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp \
  mysql -h database-service -u ikp_user -pikp-password ikp_db -e "SELECT 1"
```

## 🎓 Learning Points

1. **Multi-application orchestration**: Multiple compose files bekerja together
2. **Separation of concerns**: Base infra terpisah dari app layer
3. **Easy scaling**: Add app baru hanya perlu tambah 3 services (app, queue, scheduler)
4. **Resource management**: Per-service limits untuk predictable performance
5. **Network isolation**: All services on shared network, tapi database tidak expose externally

## 🚀 Next Steps

1. ✅ Clone IKP repo: `git clone https://github.com/juniyasyos/ikp.git site/ikp`
2. ⏳ Update nginx config untuk IKP routing
3. ⏳ Build: `docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml build`
4. ⏳ Start: `docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml up -d`
5. ⏳ Migrate: `docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp php artisan migrate`
6. ✅ Verify: `curl http://localhost:8001`

---

**Last Updated**: March 13, 2026
