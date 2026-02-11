# SIIMUT Standalone Setup (No SSO)

Dokumentasi lengkap untuk menjalankan SIIMUT sebagai aplikasi standalone dengan menggunakan Nginx dan tanpa SSO (Single Sign-On).

## 📋 Daftar Isi

- [Fitur](#fitur)
- [Prasyarat](#prasyarat)
- [Setup & Installation](#setup--installation)
- [Menjalankan Aplikasi](#menjalankan-aplikasi)
- [Konfigurasi](#konfigurasi)
- [Monitoring & Troubleshooting](#monitoring--troubleshooting)
- [Struktur Services](#struktur-services)

---

## ✨ Fitur

- ✅ **SIIMUT App Only**: Hanya menjalankan aplikasi SIIMUT, tanpa IAM Server
- ✅ **Nginx Web Server**: Menggunakan Nginx Alpine untuk produksi
- ✅ **Local Authentication**: Autentikasi berbasis database lokal (bukan SSO)
- ✅ **No Bash Switch**: Script `switch-auth-mode.sh` tidak dijalankan
- ✅ **Queue & Scheduler**: Job queue dan task scheduler untuk SIIMUT
- ✅ **Database Management**: MariaDB + phpMyAdmin untuk database management
- ✅ **Resource Optimized**: Konfigurasi resource limits untuk produksi

---

## 🔧 Prasyarat

- Docker & Docker Compose terinstall
- Git untuk repository
- Minimal 2GB RAM yang tersedia
- Port 8000, 8081, 3306 tersedia di host

---

## 🚀 Setup & Installation

### 1. Clone Repository & Setup Environment

```bash
# Clone atau masuk ke project directory
cd /path/to/siimut-image-docker

# Copy env untuk standalone
cp env/.env.db .env.db
cp env/.env.siimut-standalone .env
```

### 2. Configure Environment Variables

Edit file `.env` dengan konfigurasi Anda:

```bash
# Database
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_DATABASE=siimut
MYSQL_USER=siimut
MYSQL_PASSWORD=your_db_password

# Web Server
SIIMUT_PORT=8000          # Port untuk akses SIIMUT
PMA_PORT=8081             # Port untuk phpMyAdmin
APP_URL=http://localhost:8000

# Timezone
TZ=Asia/Jakarta
```

### 3. Build & Start Services

```bash
# Build images (pertama kali saja)
docker compose -f docker-compose-siimut-only.yml build

# Jalankan services
docker compose -f docker-compose-siimut-only.yml up -d

# Check status
docker compose -f docker-compose-siimut-only.yml ps
```

### 4. Initialize Database & Application

```bash
# Run migrations (jika diperlukan)
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan migrate

# Create admin user (jika diperlukan)
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan tinker
# Di dalam tinker shell:
# App\Models\User::create(['nip' => 'admin', 'password' => bcrypt('password')])
```

---

## 🏃 Menjalankan Aplikasi

### Start Services

```bash
# Jalankan di background
docker compose -f docker-compose-siimut-only.yml up -d

# Jalankan di foreground (untuk development)
docker compose -f docker-compose-siimut-only.yml up
```

### Access Aplikasi

- **SIIMUT Application**: http://localhost:8000
- **phpMyAdmin**: http://localhost:8081
  - Username: `siimut`
  - Password: sesuai `MYSQL_PASSWORD` di .env

### Stop Services

```bash
docker compose -f docker-compose-siimut-only.yml down

# Stop dan hapus volumes (HATI-HATI! Data akan hilang)
docker compose -f docker-compose-siimut-only.yml down -v
```

### View Logs

```bash
# Semua services
docker compose -f docker-compose-siimut-only.yml logs -f

# Specific service
docker compose -f docker-compose-siimut-only.yml logs -f app-siimut
docker compose -f docker-compose-siimut-only.yml logs -f queue-siimut
docker compose -f docker-compose-siimut-only.yml logs -f scheduler-siimut
docker compose -f docker-compose-siimut-only.yml logs -f web
```

---

## ⚙️ Konfigurasi

### Environment Configuration

File konfigurasi utama: `env/.env.siimut-standalone`

**Penting:**
- `USE_SSO=false` - Menonaktifkan SSO
- `IAM_ENABLED=false` - Menonaktifkan IAM integration
- `QUEUE_CONNECTION=database` - Queue menggunakan database
- `SESSION_DRIVER=database` - Session menggunakan database

### Nginx Configuration

Nginx menggunakan config dari `Docker/nginx/default.conf`:

```nginx
server {
  listen 80;
  index index.php index.html;
  root /var/www/public;
  
  location ~ \.php$ {
    fastcgi_pass php:9000;    # Diarahkan ke app-siimut container
    ...
  }
}
```

### PHP Configuration

Configurasi PHP production-optimized di dalam Dockerfile:
- Memory limit: 512M
- OPCache enabled dengan JIT compilation
- APCu enabled untuk user-land caching
- FPM tuned untuk dynamic process management

---

## 🔍 Monitoring & Troubleshooting

### Check Service Health

```bash
# Lihat status semua services
docker compose -f docker-compose-siimut-only.yml ps

# Check specific service health
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan --version

# Check database connection
docker compose -f docker-compose-siimut-only.yml exec app-siimut php -r "
  \$host = getenv('DB_HOST');
  \$fp = fsockopen(\$host, 3306, \$errno, \$errstr, 2);
  if (\$fp) { echo 'Database: OK'; } else { echo 'Database: FAILED'; }
"
```

### Common Issues

#### 1. Port Already in Use
```bash
# Check port usage
lsof -i :8000
lsof -i :8081
lsof -i :3306

# Change port di .env
SIIMUT_PORT=8080  # Ganti ke port lain
```

#### 2. Permission Issues
```bash
# Fix storage permissions
docker compose -f docker-compose-siimut-only.yml exec app-siimut \
  chmod -R 775 storage bootstrap/cache
```

#### 3. Database Connection Failed
```bash
# Check if database is ready
docker compose -f docker-compose-siimut-only.yml logs database-service | tail -20

# Restart database
docker compose -f docker-compose-siimut-only.yml restart database-service
```

#### 4. Queue Not Processing
```bash
# Check queue status
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan queue:failed

# Retry failed jobs
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan queue:retry all

# Check queue logs
docker compose -f docker-compose-siimut-only.yml logs queue-siimut
```

### Cache Clearing

```bash
# Clear all caches
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan cache:clear
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan config:clear
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan route:clear
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan view:clear

# Rebuild caches
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan config:cache
docker compose -f docker-compose-siimut-only.yml exec app-siimut php artisan route:cache
```

---

## 📊 Struktur Services

```
┌─────────────────────────────────────────────┐
│         SIIMUT Standalone Architecture      │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  WEB Layer (Port 8000)                      │
│  ┌─────────────────────────────────────────┐│
│  │  Nginx:Alpine                           ││
│  │  - Static file serving                  ││
│  │  - PHP FastCGI proxy                    ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
           ↓ (FastCGI on port 9000)
┌─────────────────────────────────────────────┐
│  APP Layer                                  │
│  ┌──────────────┬────────────┬────────────┐ │
│  │ app-siimut   │queue-siimut│ scheduler  │ │
│  │              │            │ -siimut    │ │
│  │ PHP-FPM      │Job Worker  │Task       │ │
│  │ Main app     │Processing  │Scheduler  │ │
│  └──────────────┴────────────┴────────────┘ │
└─────────────────────────────────────────────┘
           ↓ (MySQL on port 3306)
┌─────────────────────────────────────────────┐
│  DB Layer (Port 3306)                       │
│  ┌─────────────────────────────────────────┐│
│  │  MariaDB 10.11                          ││
│  │  - SIIMUT Database                      ││
│  │  - Job queue table                      ││
│  │  - Session table                        ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  Management Tools (Port 8081)               │
│  ┌─────────────────────────────────────────┐│
│  │  phpMyAdmin                             ││
│  │  - Database management                  ││
│  │  - Query execution                      ││
│  │  - Data visualization                   ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

### Services Details

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| **web** | nginx:alpine | 8000 | Web server, static assets, FastCGI proxy |
| **app-siimut** | siimut-app:latest | 9000 | Main SIIMUT application (PHP-FPM) |
| **queue-siimut** | siimut-app:latest | - | Background job queue processing |
| **scheduler-siimut** | siimut-app:latest | - | Task scheduling & cron jobs |
| **database-service** | mariadb:10.11 | 3306 | MySQL/MariaDB database |
| **phpmyadmin** | phpmyadmin:latest | 8081 | Database management web UI |

---

## 📝 Key Differences dari Setup Lain

### vs Multi-Apps Setup (IAM+SIIMUT)
- ❌ Tidak ada IAM Server
- ❌ Tidak ada SSO authentication
- ✅ Lebih ringan (resource efficient)
- ✅ Tidak perlu bash switch untuk auth mode

### vs Development Setup
- ✅ Production-grade configuration
- ✅ Optimized OPCache & APCu
- ✅ Resource limits enforced
- ✅ Healthchecks configured

---

## 🔐 Security Notes

### Default Credentials (CHANGE BEFORE PRODUCTION!)

```env
MYSQL_ROOT_PASSWORD=secret123
MYSQL_PASSWORD=secret123
```

### Security Checklist

- [ ] Change all default passwords
- [ ] Update `APP_KEY` dengan `php artisan key:generate`
- [ ] Set `APP_DEBUG=false` di production
- [ ] Configure firewall rules
- [ ] Enable HTTPS with SSL certificates
- [ ] Regular backups of database
- [ ] Keep Docker images updated

---

## 📚 Additional Resources

- [SIIMUT Documentation](./README.md)
- [Laravel Documentation](https://laravel.com/docs)
- [Nginx Configuration](./Docker/nginx/nginx.conf)
- [Docker Compose Reference](https://docs.docker.com/compose/)

---

**Created**: February 2026  
**Last Updated**: February 2026  
**Version**: 1.0
