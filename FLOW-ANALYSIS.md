# 🔍 Analisis Flow: prepare → build → entrypoint → compose

## Executive Summary
- **Tidak SSO**: Gunakan `USE_SSO=false` di `.env` files
- **Env yang jelas**: Ada 3 layer env yang berbeda dengan priority berbeda  
- **Immutable vs Dynamic**: Dockerfile layer immutable, runtime override dynamic
- **Untuk Dev**: Ada 2 `.env` files (app & docker) yang harus synchronized

---

## 1️⃣  PREPARE STAGE (./prepare-siimut.sh)

### 📋 Flow:
```
prepare-siimut.sh
├─ Baca: env/.env.siimut (untuk APP_DIR & REPO_URL)
├─ Clone/Pull: site/siimut/ dari git
└─ Copy: .env.example → site/siimut/.env (jika belum ada)
```

### 📝 File yang Dibaca/Ditulis:
| File | Aksi | Status |
|------|------|--------|
| `env/.env.siimut` | **READ** | Sumber konfigurasi utama untuk build setup |
| `site/siimut/` | **CREATE** | Folder aplikasi (cloned dari git) |
| `site/siimut/.env` | **CREATE** (jika belum ada) | Copy dari `.env.example` |

### ⚠️ Issues Saat Ini:
1. `.env.siimut` punya `APP_ENV=local` dan `APP_ENV=production` (double!)
   - Line 34: `APP_ENV=production` (untuk build)
   - Line 40: `APP_ENV=local` (untuk Laravel)
2. `.env.siimut` punya `USE_SSO=false` (sesuai untuk dev)
3. Tapi saat prepare, `.env` tidak dicopy dengan nilai `.env.siimut`
   - Hanya copy `.env.example` (yang mungkin punya nilai default)

---

## 2️⃣ BUILD STAGE (docker build)

### 📋 Flow:
```
docker build -f DockerNew/php/Dockerfile.siimut-registry \
  --build-arg APP_DIR=siimut \
  --build-arg APP_ENV=production \
  .
```

### 🏗️ Dockerfile Stages:

#### Stage 1: **base**
- Daftar: PHP extensions, composer, www user
- **Immutable** (built into image)

#### Stage 2: **deps**  
- Baca: `site/siimut/composer.json`
- Jalankan: `composer install --no-dev`
- Copy: Source code dari `site/siimut/`
- **Immutable** (built into image)

#### Stage 3: **runtime**
- Copy app dari `deps` stage ke `/var/www/siimut` (in image)
- Set permissions, create directories
- Copy entrypoint script
- **Immutable** (built into image)

### 📝 .env Handling di Build:
| Layer | .env Read? | Ketika | 
|-------|-----------|--------|
| **Dockerfile BUILD** | ❌ **NO** | Config build-time, tidak baca `.env` |
| **Composer install** | ❌ **NO** | Installer Laravel package, tidak perlu `.env` |
| **Entrypoint script embedded** | ❌ **NO** | Script sudah ada di image, siap jalan |

### ⚠️ Issue:
- **Dockerfile TIDAK membaca `.env` files sama sekali!**
- Hanya copy source code as-is ke image
- Semua konfigurasi Laravel diapply saat runtime (entrypoint), bukan build time

---

## 3️⃣ ENTRYPOINT STAGE (saat container start)

### 📋 Flow (entrypoint-registry.sh):
```
Container START
├─ Read: APP_ENV, APP_WORKDIR dari ENV vars (docker-compose)
├─ Run: switch-auth-mode.sh dev (BARU - dari script kami)
│   └─ Update: site/siimut/.env (volume mount)
├─ Wait: Database connection
├─ Build: npm install + npm run build (frontend)
├─ Warm: php artisan cache:clear, config:cache, route:cache (Laravel)
├─ Set: Permissions storage/ bootstrap/cache/
└─ Start: php-fpm -F (main process)
```

### 📝 .env Handling di Runtime:

#### Sumber ENV Variables (Priority Order):

| Priority | Source | Ketika Dibaca |
|----------|--------|-----------------|
| **1 (Highest)** | `docker-compose environment:` | Container start |
| **2** | `docker-compose env_file:` | Container start |
| **3 (Lowest)** | `site/siimut/.env` | When PHP/Artisan run |

### Contoh Priority:

```yaml
# docker-compose-multi-apps.yml
app-siimut:
  env_file:
    - ./env/.env.siimut          # Priority 2
  environment:
    APP_ENV: production          # Priority 1 (OVERRIDE!)
    USE_SSO: "false"             # Priority 1 (OVERRIDE!)
```

**Jadi jika ada conflict, `environment:` menang!**

---

## 4️⃣ RUNTIME CONFIGURATION FLOW

### 📋 Saat Container Jalankan `php artisan`:

```
php artisan route:list
├─ Load: Env vars dari $_ENV (set oleh Docker)
├─ Load: .env file dari working directory
├─ Priority: $_ENV > .env
└─ Use: USE_SSO, IAM_ENABLED, etc untuk conditional routes
```

### Contoh Route Conditional (web.php):

```php
$ssoEnabled = config('iam.enabled', false) || env('USE_SSO', false);

if ($ssoEnabled) {
    // SSO routes
    Route::get('/sso/login', ...);
} else {
    // Custom login routes
    Route::get('/siimut/login', ...);
}
```

---

## 5️⃣ MANA ENV YANG DIGUNAKAN?

### Untuk Development (No SSO):

```
Saat ./prepare-siimut.sh:
  ✓ env/.env.siimut → Gunakan untuk APP_DIR, REPO_URL
  
Saat docker build:
  ✓ ARG APP_ENV=production (static, built-in)
  ✗ .env files NOT read
  
Saat docker-compose up (RUNTIME):
  ✓ env/.env.siimut → env_file (priority 2)
  ✓ environment: APP_ENV=production (priority 1) ⚠️
  ✓ site/siimut/.env → Load by Laravel (priority 3)
  
Saat php artisan jalankan:
  ✓ $_ENV (dari Docker) → Priority 1
  ✓ .env → Priority 2
  ✗ env/.env.siimut (hanya untuk Docker, bukan Laravel internal)
```

### 🎯 Key Point:
- **Docker compose** membaca `env/.env.siimut` → set container ENV vars
- **Laravel (inside container)** membaca `site/siimut/.env` → app config
- Keduanya harus **synchronized** untuk hasil konsisten!

---

## 6️⃣ IMMUTABLE vs DYNAMIC

### Docker Image (Immutable):

```latex
Built-in (dalam image, tidak bisa diubah tanpa rebuild):
  ✓ Source code (site/siimut/)
  ✓ Composer dependencies (vendor/)
  ✓ Entrypoint script
  ✓ PHP/Node config
```

### Container Runtime (Dynamic):

```latex
Dapat diubah/override saat runtime:
  ✓ .env file (volume mount, bisa edit langsung)
  ✓ ENV variables (docker-compose override)
  ✓ Storage & cache directories (persistent volumes)
```

### Untuk "Make Container Not Immutable":

Container sudah NOT immutable karena:
- Source code mount sebagai volume: `./site/siimut:/var/www/siimut` ✓
- .env dapat diedit langsung di host ✓
- ENV variables override possible via compose ✓

---

## 7️⃣ SAAT INI: ISSUE & REKOMENDASI

### ❌ Current Issues:

1. **env/.env.siimut double APP_ENV**
   ```
   Line 34: APP_ENV=production    (untuk Docker build context)
   Line 40: APP_ENV=local          (untuk Laravel actual use)
   ```
   Confusing! Double assignment.

2. **env/.env.siimut tidak dicopy ke container .env**
   ```
   prepare-siimut.sh hanya copy .env.example
   .env.siimut tetap di env/ folder (Docker exclusive)
   ```

3. **docker-compose environment: APP_ENV=production**
   ```
   Ini OVERRIDE env_file, jadi Laravel see APP_ENV=production
   Padahal .env.siimut set use_sso=false (development!)
   ```

4. **entrypoint-registry.sh jalankan switch-auth-mode.sh dev**
   ```
   Tapi ini update .env yang volume-mount dari host
   Host harus punya artisan untuk cache:clear
   ```

### ✅ Rekomendasi:

#### **Opsi A: Separate Dev/Prod Configs (RECOMMENDED)**

```
env/.env.dev.siimut           (new file - development configs)
  APP_ENV=local
  USE_SSO=false
  APP_DEBUG=true
  LOG_LEVEL=debug

env/.env.siimut               (existing - production configs)
  APP_ENV=production
  USE_SSO=true
  APP_DEBUG=false
  LOG_LEVEL=warning
```

Docker compose select:
```yaml
env_file:
  - ./env/.env.dev.siimut    # For development
  # OR
  - ./env/.env.siimut         # For production
```

#### **Opsi B: Single .env.siimut + docker-compose override**

```
env/.env.siimut (single, kept simple)
  USE_SSO=false
  APP_DEBUG=true
  
docker-compose-multi-apps.yml:
  environment:
    APP_ENV: local           # (not production!)
    APP_DEBUG: "true"
    LOG_LEVEL: debug
```

#### **Opsi C: Dynamic selection via script**

```bash
# prepare-siimut.sh
if [ "$MODE" = "dev" ]; then
    cp env/.env.dev.siimut ./actual.env
    docker-compose -f docker-compose.dev.yml up
else
    cp env/.env.siimut ./actual.env
    docker-compose -f docker-compose.prod.yml up
fi
```

---

## 📊 DECISISON MATRIX

| Aspek | Opsi A | Opsi B | Opsi C |
|-------|--------|--------|--------|
| **Clarity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Simplicity** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Flexibility** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Setup burden** | Medium | Low | High |
| **CI/CD friendly** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

### Rekomendasi untuk Anda (Dev Mode, No SSO):
**OPSI A** adalah yang terbaik:
- Transparan mana untuk dev, mana untuk prod
- Easy to maintain & switch
- CI/CD friendly
- Tidak perlu docker-compose override trik

---

## 📋 ACTION ITEMS (Planning)

### Phase 1: Clarify Current Setup (ANALYZE)
- [ ] Tentukan mode: dev only atau need prod ready?
- [ ] Lihat apakah ada CI/CD pipeline
- [ ] Check apakah ada multiple environments

### Phase 2: Clean Up Configs (IMPLEMENT)
- [ ] Create `.env.dev.siimut` (copy dari `.env.siimut`)
  - Set `USE_SSO=false`, `APP_ENV=local`, `APP_DEBUG=true`
- [ ] Keep `.env.siimut` untuk production
  - Set `USE_SSO=true`, `APP_ENV=production`, `APP_DEBUG=false`
- [ ] Update `docker-compose-multi-apps.yml`
  - Point ke `./env/.env.dev.siimut`
  - Remove conflicting `environment: APP_ENV: production`
- [ ] Update `.switch-auth-mode.sh` (optional)
  - Add logic untuk update beiden `.env` files

### Phase 3: Validate & Test
- [ ] Run `./prepare-siimut.sh`
- [ ] Run `docker compose up`
- [ ] Check `php artisan route:list | grep login`
- [ ] Verify hanya custom login routes muncul (no SSO route)

### Phase 4: Document & Maintain
- [ ] Create `.env.*.example` files untuk reference
- [ ] Update README untuk explain dev/prod mode
- [ ] Create script untuk easy mode switching

---

## 📝 Notes

- **Docker layer caching**: Dockerfile build ARG tidak impact container env
- **Volume mount**: Makes container NOT immutable (good for dev)
- **Priority**: Docker env vars > env files > .example files
- **For SSO switching**: Update BOTH `.env.dev.siimut` AND `site/siimut/.env`
