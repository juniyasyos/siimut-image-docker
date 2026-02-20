# IAM Server - Production Deployment dengan Registry

## 📋 Overview

Setup production untuk IAM Server menggunakan Docker Registry. Image bersifat **self-contained** (semua kode ada di dalam image), tidak ada volume mount untuk development.

### Arsitektur:
- **IAM App Container**: Pull dari registry, kode sudah ada di dalam image
- **Caddy Web Server**: Serve static files dari shared volume
- **Public Assets**: IAM copy folder `public/` ke shared volume saat startup
- **Database**: MariaDB dengan persistent volume

### Keuntungan:
✅ **Production-ready**: Tidak ada mount dev files  
✅ **Registry-based**: Build sekali, deploy ke mana saja  
✅ **Ringan CPU**: Copy public assets hanya sekali saat startup  
✅ **Scalable**: Bisa deploy multiple replica dengan mudah  

---

## 🚀 Cara Penggunaan

### 1. Setup Registry (Opsional - jika belum punya)

Jika menggunakan local registry untuk testing:

```bash
# Start local registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Atau gunakan registry cloud (Docker Hub, Harbor, AWS ECR, etc)
```

### 2. Build & Push Image IAM ke Registry

```bash
# Build dan push ke local registry (default)
./build-push-iam.sh

# Atau specify custom registry
REGISTRY=myregistry.com:5000 ./build-push-iam.sh

# Atau dengan version tag
REGISTRY=myregistry.com:5000 VERSION=v1.0.0 ./build-push-iam.sh
```

Script ini akan:
1. Build image dari `DockerNew/php/Dockerfile.iam-registry`
2. Extract code dari `site/iam-server` (atau sesuai APP_DIR)
3. Install dependencies dengan composer (production mode)
4. Push ke registry dengan tag `latest` dan timestamp

### 3. Setup Environment Files

Buat file `.env` di folder `env/`:

```bash
# env/.env.iam
APP_NAME="IAM Server"
APP_ENV=production
APP_KEY=base64:xxx...
APP_DEBUG=false
APP_URL=http://your-domain.com:7000

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=iam_db
DB_USERNAME=iam_user
DB_PASSWORD=SecurePassword123

# Cache & Session (using database, no Redis)
CACHE_DRIVER=database
SESSION_DRIVER=database
QUEUE_CONNECTION=database
```

```bash
# env/.env.db
MYSQL_ROOT_PASSWORD=RootSecurePassword
MYSQL_DATABASE=iam_db
MYSQL_USER=iam_user
MYSQL_PASSWORD=SecurePassword123
```

### 4. Deploy dengan Docker Compose

```bash
# Deploy IAM server
docker-compose -f docker-compose.iam-registry.yml up -d

# Check logs
docker-compose -f docker-compose.iam-registry.yml logs -f app

# Check status
docker-compose -f docker-compose.iam-registry.yml ps
```

### 5. Update/Redeploy

Ketika ada perubahan code:

```bash
# 1. Build & push image baru
./build-push-iam.sh

# 2. Pull image terbaru
docker-compose -f docker-compose.iam-registry.yml pull app

# 3. Restart container
docker-compose -f docker-compose.iam-registry.yml up -d app

# Atau one-liner
./build-push-iam.sh && \
  docker-compose -f docker-compose.iam-registry.yml pull app && \
  docker-compose -f docker-compose.iam-registry.yml up -d app
```

---

## 🔧 Konfigurasi

### Environment Variables untuk Compose

Buat file `.env` di root project (optional):

```bash
# Registry configuration
REGISTRY=localhost:5000
VERSION=latest

# Port mapping
IAM_PORT=7000

# Resources (optional override)
```

### Custom Registry

Untuk production dengan private registry:

```bash
# Login ke registry
docker login myregistry.com

# Build & push
REGISTRY=myregistry.com/myproject ./build-push-iam.sh

# Update docker-compose.iam-registry.yml
# Atau set via .env file
echo "REGISTRY=myregistry.com/myproject" >> .env
echo "VERSION=v1.0.0" >> .env

# Deploy
docker-compose -f docker-compose.iam-registry.yml up -d

> 💡 **Env runtime**: image dibuat sekali saja; semua pengaturan Laravel (APP_URL, DB_HOST, AWS_*, dsb.) dibaca dari variabel container saat start via `environment:` atau `env_file:`. Ubah nilai di `env/.env.iam` atau di `docker-compose` tanpa perlu rebuild — entrypoint akan men-generate ulang `.env` sebelum caching.
```

---

## 📁 File Structure

```
siimut-image-docker/
├── DockerNew/
│   ├── php/
│   │   ├── Dockerfile.iam-registry       # Dockerfile untuk IAM production
│   │   └── entrypoint-registry.sh        # Entrypoint yang copy public/ ke volume
│   └── caddy/
│       └── Caddyfile.iam                 # Config Caddy untuk IAM
├── env/
│   ├── .env.iam                          # IAM app config
│   └── .env.db                           # Database config
├── docker-compose.iam-registry.yml       # Compose file production
├── build-push-iam.sh                     # Script build & push ke registry
└── README-IAM-REGISTRY.md                # Dokumentasi ini
```

---

## 🔍 Troubleshooting

### Image tidak bisa di-pull

```bash
# Check registry accessibility
curl http://localhost:5000/v2/_catalog

# Check image exists
curl http://localhost:5000/v2/iam-server/tags/list

# Login jika private registry
docker login your-registry.com
```

### Public assets tidak muncul

```bash
# Check volume public terisi
docker-compose -f docker-compose.iam-registry.yml exec app ls -la /var/www/public-shared

# Check Caddy bisa akses
docker-compose -f docker-compose.iam-registry.yml exec web ls -la /var/www/iam/public

# Restart app untuk re-sync
docker-compose -f docker-compose.iam-registry.yml restart app
```

### Database connection error

```bash
# Check db is healthy
docker-compose -f docker-compose.iam-registry.yml ps db

# Check connection from app
docker-compose -f docker-compose.iam-registry.yml exec app php artisan tinker
# >>> DB::connection()->getPdo();

# Check .env.iam settings
docker-compose -f docker-compose.iam-registry.yml exec app cat .env | grep DB_
```

---

## 🎯 Production Checklist

- [ ] Registry sudah setup (local/cloud)
- [ ] `.env.iam` sudah dikonfigurasi dengan benar (APP_KEY, DB, etc)
- [ ] `.env.db` dengan password yang aman
- [ ] Build & push image berhasil
- [ ] Test pull image dari registry
- [ ] Deploy dengan docker-compose
- [ ] Verify health checks (app & web)
- [ ] Test akses via browser: `http://your-server:7000`
- [ ] Check logs untuk errors
- [ ] Setup monitoring (optional)
- [ ] Setup backup untuk volumes (db_data, iam_storage)

---

## 📊 Monitoring

```bash
# Resource usage
docker stats iam-app iam-web iam-db

# Logs
docker-compose -f docker-compose.iam-registry.yml logs -f --tail=100

# Health checks
curl http://localhost:7000/health

# Database connections
docker-compose -f docker-compose.iam-registry.yml exec db mysql -u root -p -e "SHOW PROCESSLIST;"
```

---

## 🔄 Rollback

Jika ada masalah dengan versi baru:

```bash
# Gunakan versi timestamp yang lama
REGISTRY=localhost:5000 VERSION=20241210-143022 \
  docker-compose -f docker-compose.iam-registry.yml up -d app

# Atau tag specific version
docker tag localhost:5000/iam-server:20241210-143022 localhost:5000/iam-server:latest
docker-compose -f docker-compose.iam-registry.yml up -d app
```

---

## 💡 Tips

1. **Versioning**: Gunakan semantic versioning untuk production (v1.0.0, v1.0.1)
2. **Health Checks**: Aktifkan health endpoint di Laravel untuk monitoring
3. **Backup**: Schedule backup untuk volume `db_data` dan `iam_storage`
4. **Scaling**: Bisa add multiple replica dengan load balancer
5. **CI/CD**: Integrate build-push script ke pipeline (GitHub Actions, GitLab CI)

---

## 🔐 Security Notes

- **No .env in image**: File `.env` di-mount via `env_file`, tidak masuk ke image
- **Non-root user**: PHP-FPM run as `www` user (UID 1000)
- **Secrets**: Gunakan Docker secrets atau vault untuk production
- **Network isolation**: Gunakan custom network, jangan expose DB port
- **TLS**: Enable HTTPS di Caddy untuk production

---

## 📝 Next Steps - Deploy SIIMUT

Setelah IAM berhasil, bisa gunakan pattern yang sama untuk SIIMUT:

1. Copy `Dockerfile.iam-registry` → `Dockerfile.siimut-registry`
2. Copy `build-push-iam.sh` → `build-push-siimut.sh`
3. Update `APP_DIR` ke folder SIIMUT
4. Buat `docker-compose.siimut-registry.yml`
5. Deploy!

---

**Support**: Jika ada issue, check logs dan troubleshooting guide di atas.
