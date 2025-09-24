# SIIMUT Docker dengan Git Clone

Setup Docker yang menggunakan git clone untuk mengambil kode Laravel dari repository, bukan menggunakan image yang sudah di-build.

## 🏗️ Arsitektur Baru

### Perubahan Utama:
- ✅ **Git Clone**: Kode di-clone dari repository, bukan di-copy ke image
- ✅ **Mount Volume**: Folder `application/` di-mount ke container `/var/www`
- ✅ **Fleksibel**: Bisa ganti repository dan branch dengan mudah
- ✅ **Performa**: Lebih cepat karena tidak perlu rebuild image saat update kode

### Struktur Folder:
```
siimut-image-docker/
├── application/              # ← Laravel project (git clone hasil)
│   ├── app/
│   ├── config/
│   ├── composer.json
│   └── ...
├── Docker/
│   ├── php/
│   │   ├── Dockerfile.alpine.new
│   │   └── entrypoint-new.sh
│   ├── nginx/
│   └── db/
├── docker-compose-new.yml    # ← Docker compose baru
├── setup-siimut-new.sh      # ← Setup script
└── .env
```

## 🚀 Quick Start

### 1. Setup Environment
```bash
# Clone setup baru
./setup-siimut-new.sh

# Atau dengan repository dan branch custom
./setup-siimut-new.sh --repo https://github.com/juniyasyos/siimut.git --branch develop
```

### 2. Start Services
```bash
# Start semua services
docker-compose -f docker-compose-new.yml up -d

# View logs
docker-compose -f docker-compose-new.yml logs -f php
```

### 3. Access Application
- **Application**: http://localhost:8000
- **phpMyAdmin**: http://localhost:8080

## ⚙️ Konfigurasi

### Environment Variables (.env)
```env
# Repository Settings
SIIMUT_REPO=https://github.com/juniyasyos/siimut.git
SIIMUT_BRANCH=master

# App Settings
APP_PORT=8000
VITE_PORT=5173

# Database
MYSQL_DATABASE=siimut_prod
MYSQL_USER=siimut
MYSQL_PASSWORD=password-siimut
MYSQL_PORT=3306

# Redis
REDIS_PORT=6379

# phpMyAdmin
PMA_PORT=8080
```

## 🔧 Commands

### Development
```bash
# Update kode dari repository
cd application && git pull origin master

# Masuk ke container PHP
docker-compose -f docker-compose-new.yml exec php bash

# Run artisan commands
docker-compose -f docker-compose-new.yml exec php php artisan migrate
docker-compose -f docker-compose-new.yml exec php php artisan queue:work

# Install composer packages
docker-compose -f docker-compose-new.yml exec php composer install
```

### Production
```bash
# Deploy dengan branch production
./setup-siimut-new.sh --repo https://github.com/juniyasyos/siimut.git --branch production

# Start dengan production config
docker-compose -f docker-compose-new.yml up -d

# Run optimizations
docker-compose -f docker-compose-new.yml exec php php artisan optimize
```

## 📂 Volume Mapping

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `./application` | `/var/www` | Laravel source code |
| `./Docker/db/data` | `/var/lib/mysql` | Database data |
| `./Docker/redis/data` | `/data` | Redis data |
| `./Docker/logs` | `/var/log/mysql` | MySQL logs |

## 🔄 Updating Code

### Method 1: Git Pull (Recommended)
```bash
cd application
git pull origin master
docker-compose -f docker-compose-new.yml restart php worker
```

### Method 2: Fresh Clone
```bash
./setup-siimut-new.sh --repo https://github.com/juniyasyos/siimut.git --branch master
docker-compose -f docker-compose-new.yml up -d --force-recreate
```

## 🐛 Troubleshooting

### Container tidak bisa start
```bash
# Check logs
docker-compose -f docker-compose-new.yml logs php

# Check permissions
sudo chown -R $USER:$USER application/
```

### Database connection error
```bash
# Wait for database
docker-compose -f docker-compose-new.yml logs db

# Check database is ready
docker-compose -f docker-compose-new.yml exec db mysql -u root -proot -e "SHOW DATABASES;"
```

### Permission errors
```bash
# Fix Laravel permissions
docker-compose -f docker-compose-new.yml exec php chown -R www-data:www-data /var/www
docker-compose -f docker-compose-new.yml exec php chmod -R 775 /var/www/storage /var/www/bootstrap/cache
```

## 🚀 Keuntungan Setup Baru

### Performa:
- ✅ **Faster deployment**: Tidak perlu rebuild image
- ✅ **Faster updates**: Cukup git pull
- ✅ **Smaller images**: Image hanya berisi environment, bukan kode

### Development:
- ✅ **Live editing**: Edit kode langsung di host
- ✅ **Version control**: Full git history tersedia
- ✅ **Branch switching**: Mudah ganti branch

### Production:
- ✅ **CI/CD friendly**: Mudah integrasi dengan pipeline
- ✅ **Rollback**: Mudah rollback ke commit sebelumnya
- ✅ **Multi-environment**: Bisa deploy ke berbagai environment

## 📝 Migration dari Setup Lama

1. **Backup data lama**:
   ```bash
   docker-compose exec db mysqldump -u root -proot siimut_prod > backup.sql
   ```

2. **Stop containers lama**:
   ```bash
   docker-compose down
   ```

3. **Setup baru**:
   ```bash
   ./setup-siimut-new.sh
   ```

4. **Restore data**:
   ```bash
   docker-compose -f docker-compose-new.yml exec -T db mysql -u root -proot siimut_prod < backup.sql
   ```

## 🔐 Security Notes

- Folder `application/` berisi kode source, pastikan permissions yang tepat
- File `.env` berisi credentials, jangan commit ke repository
- Volume database di-mount ke host untuk persistence