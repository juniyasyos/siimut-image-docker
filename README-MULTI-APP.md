# Multi-App Docker Compose Setup

Dokumen ini menjelaskan cara menjalankan **multiple Laravel applications** dengan setup yang aman dan terstruktur.

## 📋 Overview

Setup ini menggunakan **2 compose files secara bersamaan**:

```bash
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml up -d
```

### Arsitektur

```
┌─────────────────────────────────────────────────────────────────┐
│              compose/compose.base.yml                           │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Shared Infrastructure                                   │   │
│  │  - Caddy Web Server (port 8080, 443)                     │   │
│  │  - MariaDB Database (shared)                             │   │
│  │  - phpMyAdmin (port 9000)                                │   │
│  │  - Default network & volumes                             │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            ↓ (combined with)
┌─────────────────────────────────────────────────────────────────┐
│          docker-compose-multi-apps.yml                          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐    │
│  │   SIIMUT     │  │   IKP        │  │   IAM (optional)  │    │
│  │              │  │              │  │                   │    │
│  │ - app        │  │ - app        │  │ - app             │    │
│  │ - queue      │  │ - queue      │  │                   │    │
│  │ - scheduler  │  │ - scheduler  │  │                   │    │
│  └──────────────┘  └──────────────┘  └───────────────────┘    │
│                                                                 │
│  Nginx: 8000 (SIIMUT) | 8001 (IKP) | 8100 (IAM optional)      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Cara Menggunakan

### 1. Persiapan

```bash
# Pastikan repository IKP sudah ada
git clone https://github.com/juniyasyos/ikp.git site/ikp

# Dan SIIMUT
git clone <siimut-repo> site/siimut
```

### 2. Konfigurasi Environment

Buat file `.env` di root directory:

```bash
# Stack naming
STACK_NAME=myapp

# MariaDB (dari compose.base.yml)
MYSQL_ROOT_PASSWORD=your-secure-root-password
MYSQL_DATABASE=app_db
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password

# Optional: untuk S3/MinIO
AWS_ACCESS_KEY_ID=admin
AWS_SECRET_ACCESS_KEY=password
```

### 3. Build & Run

```bash
# Build all images
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml build

# Start services
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml up -d

# Check status
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml ps
```

### 4. Migrations & Setup

```bash
# SIIMUT
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-siimut php artisan migrate

# IKP
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp php artisan migrate
```

## 📁 File Structure

```
siimut-image-docker/
├── compose/
│   └── compose.base.yml              ← Shared infrastructure (DB, web server, etc)
├── docker-compose-multi-apps.yml     ← Multiple Laravel apps (SIIMUT, IKP, IAM)
├── DockerNew/
│   ├── php/
│   │   ├── Dockerfile.siimut-registry
│   │   ├── Dockerfile.ikp-registry
│   │   ├── entrypoint-registry.sh
│   │   └── ...
│   ├── nginx/
│   │   ├── nginx.conf
│   │   └── nginx-multi-apps.conf
│   ├── caddy/
│   │   └── Caddyfile
│   └── db/
│       └── my.cnf
├── site/
│   ├── siimut/
│   ├── ikp/
│   └── iam-server/ (optional)
└── ...
```

## 🔧 Services Breakdown

### Base Infrastructure (compose.base.yml)
- **Caddy**: Web server (port 8080, 443)
- **MariaDB**: Database (port tidak exposed - internal only)
- **phpMyAdmin**: Database admin (port 9000)

### Multi-App (docker-compose-multi-apps.yml)
- **Nginx**: Router untuk 3 apps (port 8000, 8001, 8002)
- **SIIMUT**: Legacy app (port 8000)
- **IKP**: New app (port 8001)
- **IAM**: Optional SSO server (port 8100 - commented)

Setiap app memiliki:
- **app**: Main PHP-FPM service
- **queue**: Background job worker
- **scheduler**: Task scheduler

## 📊 Resource Allocation

### Per Service
```
Nginx:
  - Memory: 256MB limit, 128MB reservation
  - CPU: 0.2 limit, 0.1 reservation

Database (MariaDB):
  - Memory: 512MB limit, 256MB reservation
  - CPU: 1.0 limit, 0.5 reservation

Each Laravel App (app-*):
  - Memory: 1.5GB limit, 768MB reservation
  - CPU: 1.5 limit, 0.75 reservation

Each Queue Worker (queue-*):
  - Memory: 512MB limit, 128MB reservation
  - CPU: 1.0 limit, 0.25 reservation

Each Scheduler (scheduler-*):
  - Memory: 256MB limit, 128MB reservation
  - CPU: 0.25 limit, 0.125 reservation
```

### Total (3 apps + base services)
- **Memory**: ~6.5GB
- **CPU**: ~4.5-5 cores

## 🌐 Accessing Applications

```
SIIMUT:      http://localhost:8000
IKP:         http://localhost:8001
IAM:         http://localhost:8100 (if enabled)
phpMyAdmin:  http://localhost:9000
Caddy:       http://localhost:8080
```

## 🛠️ Common Commands

### View Logs
```bash
# All services
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml logs -f

# Specific service
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml logs -f app-ikp
```

### Bash into Container
```bash
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp bash
```

### Run Artisan Commands
```bash
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp php artisan tinker
```

### Stop Services
```bash
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml down
```

### Remove Everything (including data!)
```bash
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml down -v
```

## 🔐 Security Notes

1. **Database**: Maria DB tidak expose port ke host - hanya accessible dari container network
2. **Environment**: Gunakan proper `.env` dengan secrets management untuk production
3. **Nginx**: Configured untuk multiple apps tanpa konflik
4. **Network**: Semua service terhubung via bridge network `default`

## 🎯 Mengaktifkan IAM (Optional)

Untuk mengaktifkan IAM application:

1. Pastikan repository ada:
   ```bash
   git clone <iam-repo> site/iam-server
   ```

2. Uncomment section `app-iam` di `docker-compose-multi-apps.yml`

3. Update Nginx config untuk route ke IAM (port 8100)

4. Build & run:
   ```bash
   docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml build
   docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml up -d
   ```

## 📝 Troubleshooting

### Service tidak start
```bash
# Check logs
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml logs app-ikp

# Check health
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp php -v
```

### Database connection error
```bash
# Verify database is running
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml ps | grep db

# Test connection dari app
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp \
  mysql -h database-service -u ikp_user -pikp-password -e "SELECT 1"
```

### Volume issues
```bash
# List all volumes
docker volume ls | grep myapp

# Inspect specific volume
docker volume inspect myapp_ikp_storage
```

### Rebuild specific service
```bash
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml build app-ikp
docker compose -f compose/compose.base.yml -f docker-compose-multi-apps.yml up -d app-ikp
```

## 🚀 Best Practices

1. **Development**: Gunakan `docker-compose.yml` untuk single app development
2. **Testing**: Gunakan `docker-compose-multi-apps.yml` + `compose.base.yml`
3. **Production**: Deploy dengan proper secrets management dan TLS
4. **Backups**: Regular backup database volume:
   ```bash
   docker run --rm -v myapp_db_data:/data -v $(pwd):/backup \
     alpine tar czf /backup/db-backup.tar.gz /data
   ```

## 📚 Related Documentation

- [SETUP-THREE-APPS.md](./SETUP-THREE-APPS.md) - Alte setup (single compose file, keep for reference)
- [docker-compose.yml](./docker-compose.yml) - Single app development
- [compose/compose.base.yml](./compose/compose.base.yml) - Shared infrastructure

## 🤝 Integration dengan Existing Setup

Jika sudah punya setup lama dengan `docker-compose-multi-apps.yml` (two apps only), setup baru ini:

✅ Ke belakang compatible dengan Nginx/Database setup
✅ Add IKP support tanpa breaking existing SIIMUT
✅ Maintain resource isolation per app
✅ Enable easy scaling untuk app baru di masa depan
