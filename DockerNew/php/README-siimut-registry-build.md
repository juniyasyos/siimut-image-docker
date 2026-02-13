# SIIMUT Registry Image - Build & Runtime Documentation

## 📋 Overview

Image ini adalah **production-ready** SIIMUT application image untuk registry deployment. Didesain untuk:
- ✅ Self-contained (semua dependencies included)
- ✅ Immutable (tidak ada perubahan di runtime)
- ✅ Fast startup (minimal initialization)
- ✅ Secure (non-root user, no dev dependencies)

---

## 🏗️ Build Pipeline: 3 Stages

### Stage 1: `base` - Foundation Layer
```dockerfile
FROM php:8.4-fpm-alpine AS base
```

**Tujuan:** Setup PHP environment dengan semua PHP extensions yang diperlukan

**Yang diinstall:**
- ✅ System tools: bash, shadow, ca-certificates, unzip, su-exec, git, curl
- ✅ Build dependencies: icu-dev, oniguruma-dev, libzip-dev, zlib-dev, libpng-dev, libjpeg-turbo-dev, freetype-dev, libxml2-dev, postgresql-dev
- ✅ Node.js & npm (untuk frontend build)
- ✅ Timezone configuration: Asia/Jakarta
- ✅ PHP Extensions:
  - International: `intl`
  - String: `mbstring`
  - Database: `pdo`, `pdo_mysql`, `pdo_pgsql`, `pgsql`
  - File: `zip`, `gd` (image processing)
  - Math: `bcmath`
  - Media: `exif`
  - System: `pcntl`, `sockets`
  - Performance: `opcache`
  - Cache: `apcu`, `igbinary`
- ✅ Composer binary (copied from composer:2 image)
- ✅ Non-root user: `www` (UID 1000, GID 1000)

**Size:** ~300MB (alpine base)

---

### Stage 2: `deps` - Dependency Build Layer
```dockerfile
FROM base AS deps
```

**Tujuan:** Install PHP & Frontend dependencies, copy application code

**Proses:**

#### Step 1: Pre-install PHP Dependencies (Cacheable)
```bash
COPY site/siimut/composer.json site/siimut/composer.lock /tmp/composer-files/
composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts --no-autoloader
```
- ✅ Copy hanya composer.json & composer.lock (layer caching optimal)
- ✅ Install tanpa dev dependencies (`--no-dev`)
- ✅ Use distribution packages (`--prefer-dist` = faster)
- ✅ Skip scripts (`--no-scripts` = avoid premature execution)
- ✅ Hasil: `vendor/` directory disimpan

**Keuntungan:** Jika composer.json tidak berubah, layer ini tidak direbuild (cache hit)

#### Step 2: Add Build Timestamp
```bash
RUN echo "Build timestamp: ${BUILD_TIMESTAMP}" > /tmp/build.info
```
- Force cache invalidation untuk source code layer
- Ini adalah **intentional** untuk memastikan source code selalu fresh

#### Step 3: Copy Full Source Code
```bash
COPY . .
```
- Copy seluruh monorepo (tidak ada caching di layer ini)
- Layer ini selalu direbuild (intentional)

#### Step 4: Extract Application dari Monorepo
```bash
cp -r "site/siimut/." "/app/"
```
- Extract aplikasi dari folder `site/siimut/`
- Output: `/app/` berisi aplikasi lengkap

#### Step 5: Finalize Composer Setup
```bash
composer dump-autoload --optimize --classmap-authoritative
```
- Generate optimized autoloader
- Hasil: `vendor/autoload.php` siap untuk production
- Lebih cepat dari `composer install` yang full

**Size:** ~500MB (dengan vendor/ dan node_modules)

---

### Stage 3: `runtime` - Final Production Image
```dockerfile
FROM base AS runtime
```

**Tujuan:** Setup production environment dan copy dependencies

**Proses:**

#### Step 1: Copy Application dari deps stage
```dockerfile
COPY --from=deps --chown=www:www /app ${APP_WORKDIR}
```
- Copy `/app/` dari stage deps ke `/var/www/siimut`
- Set ownership ke user `www` (non-root)
- Laravel dependencies sudah siap

#### Step 2: Configure PHP untuk Production
```ini
# /usr/local/etc/php/conf.d/laravel.ini
memory_limit=512M
upload_max_filesize=64M
post_max_size=64M
max_execution_time=120
max_input_time=120
max_input_vars=3000
date.timezone=Asia/Jakarta
expose_php=Off          # Security: hide PHP version
display_errors=Off      # Security: no error output to client
log_errors=On           # Log errors to file
error_log=/var/log/php_errors.log
```

#### Step 3: Configure OPCache untuk Performance
```ini
# /usr/local/etc/php/conf.d/opcache.ini
opcache.enable=1
opcache.enable_cli=0    # Disabled for CLI (artisan commands)
opcache.jit=1255        # JIT Compilation enabled
opcache.jit_buffer_size=128M
opcache.memory_consumption=256M
opcache.interned_strings_buffer=32M
opcache.max_accelerated_files=100000
opcache.revalidate_freq=0       # Production: no file time checks
opcache.validate_timestamps=0
opcache.save_comments=1         # Keep for reflection
opcache.enable_file_override=1
```

#### Step 4: Configure APCu untuk Caching
```ini
# /usr/local/etc/php/conf.d/apcu.ini
apc.enabled=1
apc.shm_size=128M
apc.enable_cli=0
apc.ttl=3600            # 1 hour TTL
```

#### Step 5: Tune PHP-FPM untuk Production
```bash
pm = dynamic
pm.max_children = 50
pm.start_servers = 8
pm.min_spare_servers = 4
pm.max_spare_servers = 16
pm.max_requests = 1000  # Recycle after 1000 requests
clear_env = no          # Keep environment variables
```

#### Step 6: Setup Directory Permissions
```bash
mkdir -p storage/framework/cache/data
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/logs
mkdir -p storage/app/public
mkdir -p bootstrap/cache
chown -R www:www storage bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache
chmod -R 775 storage/framework/views
chmod -R 755 public
```
- Laravel cache directories writable oleh user `www`
- Public assets readable by web server

#### Step 7: Copy Entrypoint Script
```dockerfile
COPY DockerNew/php/entrypoint-registry.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
```

#### Step 8: Setup Health Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD php -r "exit(extension_loaded('opcache') && extension_loaded('apcu') ? 0 : 1);"
```
- Check setiap 30 detik
- Start check setelah 60 detik (warm-up time)
- Verify PHP extensions loaded

**Final Size:** ~450MB (alpine optimized, dev deps removed)

---

## 🚀 Runtime: Entrypoint Execution Flow

### Startup Order

```
entrypoint-registry.sh
├── 1. Validate Environment
│   ├── Check artisan exists
│   ├── Check .env (production only)
│   └── Print configuration
│
├── 2. Setup Authentication (SIIMUT specific)
│   └── ./switch-auth-mode.sh dev
│
├── 3. Sync Public Assets
│   └── rsync/cp public/ → ${PUBLIC_VOLUME}
│       └── For Caddy to serve static files
│
├── 4. Wait for Database
│   └── fsockopen() loop (60s timeout)
│       └── Verify DB_HOST:DB_PORT ready
│
├── 5. Fix Permissions
│   ├── Create cache directories
│   ├── Clear stale cache files
│   ├── chown -R www:www
│   └── chmod -R ug+rwX
│
├── 6. Build Frontend Assets
│   ├── npm install
│   └── npm run build
│
├── 7. Warm Laravel Caches
│   ├── php artisan cache:clear
│   ├── php artisan config:cache
│   ├── php artisan route:cache
│   ├── php artisan view:cache
│   ├── php artisan event:cache
│   └── php artisan optimize
│
└── 8. Start PHP-FPM
    └── php-fpm -F (foreground)
```

### Detailed Steps:

#### 1️⃣ Validate Environment
```bash
echo "🚀 Starting IAM App (Production Registry Mode)"
cd "${APP_WORKDIR}"
[ -f artisan ] || exit 1      # Laravel check
[ "$APP_ENV" = "production" ] && [ ! -f ".env" ] && exit 1  # .env required in prod
```

#### 2️⃣ Setup Authentication (SIIMUT specific)
```bash
if [ -f "./switch-auth-mode.sh" ]; then
    chmod +x ./switch-auth-mode.sh
    ./switch-auth-mode.sh dev || echo "⚠️ Failed (continuing...)"
fi
```
- Untuk SIIMUT: set authentication mode (SSO/local)
- Failure tidak stop container (graceful)

#### 3️⃣ Sync Public Assets to Volume
```bash
if [ -n "${PUBLIC_VOLUME}" ] && [ -d "${PUBLIC_VOLUME}" ]; then
    # Use rsync if available (faster incremental updates)
    rsync -a --delete "${APP_WORKDIR}/public/" "${PUBLIC_VOLUME}/"
    # Fallback to cp
    chmod -R 755 "${PUBLIC_VOLUME}"
fi
```
- Copy static assets ke shared volume (untuk Caddy)
- rsync lebih efficient (delta sync)
- Public assets readable by web server

#### 4️⃣ Wait for Database
```php
$host = getenv("DB_HOST") ?: "db";
$port = getenv("DB_PORT") ?: 3306;
$timeout = 60;

while (true) {
    $fp = @fsockopen($host, $port, $errno, $errstr, 2);
    if ($fp) {
        fclose($fp);
        fwrite(STDOUT, "✅ Database connected\n");
        break;
    }
    if (time() - $start > $timeout) {
        fwrite(STDERR, "❌ Database timeout\n");
        exit(1);
    }
    fwrite(STDOUT, "… waiting for DB\n");
    sleep(2);
}
```
- TCP socket check (more reliable than ping)
- Retry every 2 seconds
- Timeout setelah 60 detik

#### 5️⃣ Fix Permissions
```bash
# Create cache directories jika belum ada
mkdir -p storage/framework/cache storage/framework/sessions ...

# Clear stale cache files (prevent corruption)
rm -rf storage/framework/views/*.php
rm -rf storage/framework/cache/data/*
rm -rf bootstrap/cache/*.php

# Set ownership & permission
chown -R www:www storage bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache
```
- **Important:** Clear cache files before warming (prevent stale/corrupt cache)
- Penting untuk development mode jika code berubah

#### 6️⃣ Build Frontend Assets
```bash
if [ -f package.json ]; then
    npm install --no-save      # Install node dependencies
    npm run build              # Compile assets (webpack/vite)
fi
```
- Compile Laravel Mix/Vite assets
- Skip jika belum ada package.json

#### 7️⃣ Warm Laravel Caches
```bash
# Clear all caches first
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan event:clear

# Rebuild from scratch
php artisan config:cache    # Cache .env into /bootstrap/cache/config.php
php artisan route:cache     # Cache routes into /bootstrap/cache/routes.php
php artisan view:cache      # Cache views into /storage/framework/views/
php artisan event:cache     # Cache listeners

# Optimize application
php artisan optimize        # Combine all cache commands
```
- **Run as user `www`** (su-exec www)
- Failure non-fatal (continue with warning)
- Caches preloaded sebelum traffic datang

#### 8️⃣ Verify Cache Directories
```bash
for dir in storage/framework/views storage/framework/cache bootstrap/cache; do
  [ -d "$dir" ] && [ ! -w "$dir" ] && echo "⚠️ Warning: $dir is not writable"
done
```

#### 9️⃣ Start PHP-FPM
```bash
exec php-fpm -F
```
- `-F` = Foreground (Docker PID 1)
- Listen on 9000/tcp for Caddy

---

## 📊 Build Time Breakdown

| Stage | Time | Size | Purpose |
|-------|------|------|---------|
| base | ~2-3 min | 300MB | PHP + extensions |
| deps (composer) | ~1-2 min | +150MB | PHP dependencies |
| deps (source) | ~2-3 min | +100MB | Application code |
| runtime (setup) | ~30s | - | Configuration |
| **Total** | **~6-9 min** | **450MB** | Production image |

---

## 🚀 Runtime Startup Time Breakdown

| Step | Time | Notes |
|------|------|-------|
| 1. Validate | ~1s | Fast checks |
| 2. Auth setup | ~2-5s | SIIMUT specific |
| 3. Public sync | ~3-5s | Depends on file count |
| 4. DB wait | ~2-5s | Immediate if DB ready |
| 5. Permissions | ~2-3s | chmod/chown |
| 6. npm build | **~30-60s** | Slowest step (can be optimized) |
| 7. Cache warm | ~5-10s | PHP artisan commands |
| **Total** | **~45-90s** | Depends on npm build |

**Optimization Tips:**
- Pre-build npm assets di Dockerfile (jika assets static)
- Skip npm build jika tidak ada changes
- Use caching layers untuk dependencies

---

## 🔐 Security Features

✅ **Non-root User:** App runs as `www` (UID 1000)
✅ **No Dev Dependencies:** `--no-dev` di composer
✅ **No Dev Tools:** No git, npm in distroless variant
✅ **Error Handling:** `display_errors=Off` dalam production
✅ **Version Hiding:** `expose_php=Off`
✅ **File Permissions:** Restricted public directory
✅ **Environment Variables:** Only production config

---

## 📝 Environment Variables

```bash
# Required
APP_ENV=production                  # Node env
DB_HOST=db                         # Database host
DB_PORT=3306                       # Database port
DB_NAME=siimut                     # Database name
DB_USER=siimut_user                # Database user
DB_PASSWORD=***                    # Database password

# Optional
PUBLIC_VOLUME=/var/www/public-shared  # Shared volume for assets
APP_WORKDIR=/var/www/siimut            # Application directory
PHP_MEMORY_LIMIT=512M                  # PHP memory
PHP_OPCACHE_VALIDATE_TIMESTAMPS=0      # Opcache mode
TZ=Asia/Jakarta                        # Timezone
```

---

## 🐳 Docker Compose Usage

```yaml
services:
  siimut:
    image: registry.example.com/siimut:latest
    environment:
      APP_ENV: production
      DB_HOST: db
      DB_PORT: 3306
      DB_NAME: siimut
      DB_USER: siimut_user
      DB_PASSWORD: your_password
      PUBLIC_VOLUME: /var/www/public-shared
    volumes:
      - public_data:/var/www/public-shared   # Shared with Caddy
      - storage_logs:/var/www/siimut/storage/logs
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "php", "-r", "exit(extension_loaded('opcache') ? 0 : 1)"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

---

## 🔍 Troubleshooting

### Container crashes on startup
```bash
# Check logs
docker logs -f container_name

# Common issues:
# - Database not ready (increase DB_WAIT timeout)
# - Missing .env file
# - Package.json build fails (check npm logs)
# - artisan not found (wrong APP_DIR)
```

### Cache/Views not writable
```bash
# Inside container
ls -la storage/framework/views
ls -la storage/framework/cache
# Should show: drwxrwx--- www www

# Fix
docker exec -it container chmod -R ug+rwX storage bootstrap/cache
docker exec -it container chown -R www:www storage bootstrap/cache
```

### Performance issues
```bash
# Check OPCache status
docker exec -it container php -r "phpinfo();" | grep opcache

# Verify APCu
docker exec -it container php -r "echo apcu_cache_info();"

# Check PHP-FPM pools
docker exec -it container ps aux | grep fpm
```

---

## 📚 Related Files

- [entrypoint-registry.sh](entrypoint-registry.sh) - Startup script
- [Dockerfile.siimut-registry](Dockerfile.siimut-registry) - Build config
- [php.ini](php.ini) - PHP configuration
