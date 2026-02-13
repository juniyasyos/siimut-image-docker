# 🎯 IMPLEMENTATION PLANNING & RECOMMENDATIONS

## Executive Summary
**Rekomendasi: Gunakan OPSI A (Separate Dev/Prod configs)**
- Paling clear & maintainable
- Tidak perlu trik docker-compose override
- Easy untuk CI/CD
- Development ready (no SSO)

---

## 📋 IMPLEMENTATION ROADMAP

### Phase 1: Create Separate Config Files (15 min)

#### 1.1 Create `.env.dev.siimut` (NEW)

```bash
# Copy from current .env.siimut, but with dev values only
cp env/.env.siimut env/.env.dev.siimut
```

Then update `env/.env.dev.siimut`:

**Remove/Fix:**
- ❌ Remove the first `APP_ENV=production` (line 34)
- ❌ Remove duplicate `APP_NAME` if exists
- ❌ Remove duplicate `APP_ENV` assignments

**Keep/Ensure:**
```bash
# env/.env.dev.siimut

# Build Configuration
APP_ENV=local          (single assignment!)
ENABLE_XDEBUG=false
RUN_MIGRATIONS=false

# Laravel Application Environment - Development
APP_NAME="SI-IMUT"
APP_DEBUG=true
LOG_LEVEL=debug
CACHE_DRIVER=database

# Database Connection
DB_HOST=db
DB_DATABASE=siimut_prod26

# Identity & Access Management
USE_SSO=false
IAM_ENABLED=false
IAM_HOST=http://127.0.0.1:8000

# All other settings for development...
```

#### 1.2 Update `env/.env.siimut` (KEEP for PRODUCTION)

**Ensure production-ready values:**
```bash
# env/.env.siimut

# Build Configuration
APP_ENV=production     (single assignment!)

# Laravel Application Environment - Production
APP_NAME="SIIMUT"
APP_DEBUG=false
LOG_LEVEL=warning
CACHE_DRIVER=file

# Database Connection
DB_HOST=database-service
DB_DATABASE=siimut_db

# Identity & Access Management
USE_SSO=true
IAM_ENABLED=true
IAM_HOST=http://192.168.1.9:8100

# All other production settings...
```

#### 1.3 Create Reference Files

```bash
# Create .env.example files for documentation
cp env/.env.dev.siimut env/.env.dev.siimut.example
cp env/.env.siimut env/.env.siimut.example

# Update git - track examples, not actual files
git add env/.env.dev.siimut.example
git add env/.env.siimut.example
git add -u env/.env.siimut
git add -u env/.env.dev.siimut
```

---

### Phase 2: Update Docker Compose (10 min)

#### 2.1 Update `docker-compose-multi-apps.yml`

**Change:**
```yaml
# OLD:
app-siimut:
  env_file:
    - ./env/.env.siimut           ❌
  environment:
    APP_ENV: production           ❌ (override!)
    ...

# NEW:
app-siimut:
  env_file:
    - ./env/.env.dev.siimut       ✅ (for development)
  environment:
    APP_WORKDIR: /var/www/siimut
    PUBLIC_VOLUME: /var/www/public-shared-siimut
    DB_HOST: database-service
    # Remove: APP_ENV override!
    # Remove: USE_SSO, IAM_ENABLED overrides!
```

**Rationale:**
- `.env.dev.siimut` sudah punya semua konfigurasi yang diperlukan
- Tidak perlu docker-compose override jika env file sudah benar
- Lebih transparan & maintainable

#### 2.2 Create Alternative Compose for Production

```bash
# Create production variant
cp docker-compose-multi-apps.yml docker-compose-multi-apps.prod.yml
```

Update `docker-compose-multi-apps.prod.yml`:
```yaml
app-siimut:
  env_file:
    - ./env/.env.siimut           ✅ (for production)
  environment:
    # ... same as dev
```

---

### Phase 3: Update Setup Scripts (10 min)

#### 3.1 Update `prepare-siimut.sh` (Optional Enhancement)

```bash
# Current behavior is OK
# Optional: add validation step

# Add validation at end of script:
echo "🔍 Validating environment..."
if [ -f "${SITE_DIR}/.env" ]; then
  # Check key variables
  grep -q "USE_SSO" "${SITE_DIR}/.env" && echo "  ✓ USE_SSO found" || echo "  ⚠️ USE_SSO missing"
  grep -q "APP_ENV" "${SITE_DIR}/.env" && echo "  ✓ APP_ENV found" || echo "  ⚠️ APP_ENV missing"
fi
```

#### 3.2 Enhance `switch-auth-mode.sh` (Optional)

Already upgraded! ✓ The script already:
- Updates both `.env` files
- Handles when running from any directory
- Shows which files were updated

No further changes needed unless you want to:
- Add diff output (show what changed)
- Add backup before updating
- Add rollback option

---

### Phase 4: Configuration Validation (15 min)

#### 4.1 Pre-Flight Checks

```bash
#!/bin/bash
# File: ./.github/scripts/validate-config.sh (optional CI check)

echo "🔍 Validating SIIMUT Configuration..."

# Check files exist
[ -f "env/.env.dev.siimut" ] || { echo "❌ env/.env.dev.siimut missing"; exit 1; }
[ -f "env/.env.siimut" ] || { echo "❌ env/.env.siimut missing"; exit 1; }

# Check assignments are single (not double)
if grep -c "^APP_ENV=" "env/.env.dev.siimut" | grep -q "^1$"; then
  echo "✓ env/.env.dev.siimut: Single APP_ENV assignment"
else
  echo "❌ env/.env.dev.siimut: Multiple APP_ENV assignments!"
  exit 1
fi

# Check values are correct for mode
if grep "APP_ENV=local" "env/.env.dev.siimut" > /dev/null; then
  echo "✓ env/.env.dev.siimut: APP_ENV=local"
else
  echo "❌ env/.env.dev.siimut: APP_ENV not 'local'"
  exit 1
fi

if grep "USE_SSO=false" "env/.env.dev.siimut" > /dev/null; then
  echo "✓ env/.env.dev.siimut: USE_SSO=false"
else
  echo "❌ env/.env.dev.siimut: USE_SSO not 'false'"
  exit 1
fi

echo ""
echo "✅ All configuration validations passed!"
```

#### 4.2 Runtime Checks

```bash
# After docker-compose up, verify:

$ docker-compose exec app-siimut php artisan route:list | grep -E "(login|sso)"

# Expected output for DEV:
#   GET|HEAD   login iam.sso.login › ...
#   GET|HEAD   siimut/login filament.siimut.auth.login › ...
#   (NO /sso/login route)

# Expected output for PROD:
#   GET|HEAD   sso/login sso.login › ...
#   (NO /login or /siimut/login routes visible without SSO)
```

---

## 📊 Implementation Checklist

### Before Implementation
- [ ] Read both FLOW-ANALYSIS.md and FLOW-DIAGRAMS.md
- [ ] Backup current ./env folder: `cp -r ./env ./env.backup`
- [ ] Check git status is clean: `git status`

### Phase 1: Config Files
- [ ] Create env/.env.dev.siimut (copy from existing)
- [ ] Remove double APP_ENV from both files
- [ ] Ensure env/.env.dev.siimut has all DEV values
- [ ] Ensure env/.env.siimut has all PROD values
- [ ] Create .example files for reference
- [ ] Git add the changes

### Phase 2: Docker Compose
- [ ] Update docker-compose-multi-apps.yml env_file
- [ ] Remove APP_ENV override from environment:
- [ ] Test syntax: `docker-compose config`
- [ ] (Optional) Create docker-compose-multi-apps.prod.yml

### Phase 3: Scripts
- [ ] Verify switch-auth-mode.sh works: `./site/siimut/switch-auth-mode.sh status`
- [ ] (Optional) Enhance prepare-siimut.sh with validation
- [ ] Test: `./prepare-siimut.sh`

### Phase 4: Validation
- [ ] Run pre-flight checks
- [ ] Clean up: `docker system prune`
- [ ] Build image: `docker compose build`
- [ ] Start: `docker compose up`
- [ ] Run runtime checks: `php artisan route:list`
- [ ] Test endpoint: `curl http://localhost:8088/login`

### After Implementation
- [ ] Commit to git
- [ ] Update README with dev/prod mode info
- [ ] Document in team wiki/docs
- [ ] Update CI/CD pipeline if exists

---

## 🚀 QUICK START COMMANDS

### For Development (No SSO)

```bash
# Setup
./prepare-siimut.sh

# Build
docker compose build

# Start
docker compose up -d

# Verify
docker compose exec app-siimut php artisan route:list | grep login
# Expected: /login, /siimut/login (no /sso/login)

# Manual switch (if already running)
docker compose exec app-siimut ./switch-auth-mode.sh dev

# Check cache was cleared
docker compose logs app-siimut | tail -20
```

### For Production (With SSO)

```bash
# Setup
./prepare-siimut.sh

# Update compose to use .env.siimut
# cp docker-compose-multi-apps.yml docker-compose-multi-apps.prod.yml
# (or manually update env_file in docker-compose.yml)

# Build
docker compose -f docker-compose-multi-apps.prod.yml build

# Start
docker compose -f docker-compose-multi-apps.prod.yml up -d

# Verify
docker compose exec app-siimut php artisan route:list | grep login
# Expected: /sso/login only

# Manual switch (if already running)
docker compose exec app-siimut ./switch-auth-mode.sh prod
```

---

## ⚠️ POTENTIAL ISSUES & SOLUTIONS

### Issue 1: "env/.env.dev.siimut not found"
**Cause:** File was never created
**Solution:** 
```bash
cp env/.env.siimut env/.env.dev.siimut
# Edit and set variables to development values
```

### Issue 2: "Routes still show /sso/login in dev mode"
**Cause:** Entrypoint didn't run switch-auth-mode.sh, or cache not cleared
**Solution:**
```bash
docker compose exec app-siimut ./switch-auth-mode.sh dev
docker compose restart app-siimut
# or manually clear:
docker compose exec app-siimut php artisan config:clear
docker compose exec app-siimut php artisan route:clear
```

### Issue 3: "Changes in .env.dev.siimut not reflected in container"
**Cause:** Container env was already set at startup, doesn't reload
**Solution:**
```bash
# Restart to pick up new env vars
docker compose restart app-siimut

# Or rebuild if you changed env_file in compose
docker compose up -d --force-recreate
```

### Issue 4: "Database connection fails"
**Cause:** .env files have different DB_HOST values
**Solution:**
- Dev: DB_HOST should be where dev database is (localhost, db service, etc)
- Prod: DB_HOST should be database-service
- Ensure entrypoint correctly handles both cases

### Issue 5: "I accidentally modified env/.env.siimut"
**Solution:**
```bash
# Restore from backup
cp env.backup/.env.siimut env/.env.siimut

# Or git restore
git restore env/.env.siimut
```

---

## 📚 DOCUMENTATION UPDATES

Create/Update these files after implementation:

### 1. Updated README.md (added section)

```markdown
## Development vs Production Mode

### Quick Mode Switch

Development (No SSO, Custom Login):
$ docker-compose -f docker-compose-multi-apps.yml up
# Uses: env/.env.dev.siimut
# Login: /login or /siimut/login

Production (SSO):
$ docker-compose -f docker-compose-multi-apps.prod.yml up
# Uses: env/.env.siimut
# Login: /sso/login (redirects to IAM)

### Manual Mode Switch

Inside container:
$ ./switch-auth-mode.sh dev       # Switch to development
$ ./switch-auth-mode.sh prod      # Switch to production
$ ./switch-auth-mode.sh status    # Check current mode

### Environment Files

- `env/.env.dev.siimut` - Development configuration (master for dev)
- `env/.env.siimut` - Production configuration (master for prod)
- `site/siimut/.env` - Auto-synced by entrypoint (do not manually edit)
```

### 2. New file: ENVIRONMENT-GUIDE.md

(Document for developers explaining which file to edit when)

---

## ✅ FINAL VALIDATION

After all implementation, run this checklist:

```bash
# 1. Check file structure
$ ls -la env/ | grep -E "\.env"
# Expected: .env.dev.siimut, .env.siimut, .env.*.example

# 2. Check no double assignments
$ grep "^APP_ENV=" env/.env.dev.siimut | wc -l
# Expected: 1

$ grep "^APP_ENV=" env/.env.siimut | wc -l
# Expected: 1

# 3. Verify values
$ grep "USE_SSO=" env/.env.dev.siimut
# Expected: USE_SSO=false

$ grep "USE_SSO=" env/.env.siimut
# Expected: USE_SSO=true

# 4. Docker validation
$ docker-compose config | grep -A 10 "env_file:"
# Expected: ./env/.env.dev.siimut (for dev)

# 5. Runtime test
$ docker-compose up -d
$ docker-compose exec app-siimut php artisan route:list | grep login
# Expected: /login, /siimut/login (no /sso/login)

# 6. Cleanup
$ docker-compose down
$ rm -rf env.backup (if satisfied with changes)
```

---

## 📝 SUMMARY

**Current Issue:** 3 `.env` files with conflicting values, unclear which is "master"

**Solution (Opsi A):** 
- Create `env/.env.dev.siimut` (master for development)
- Keep `env/.env.siimut` (master for production)
- Let `site/siimut/.env` be auto-synced by entrypoint

**Benefit:**
- ✓ Clear separation of concerns
- ✓ Single source of truth per mode
- ✓ Easy to switch modes
- ✓ CI/CD friendly
- ✓ Team-friendly (obvious which file to edit)

**Time to Implement:** ~45 minutes total
**Complexity:** Low (mostly reorganizing existing configs)
**Risk:** Very low (can easily rollback if needed)

---

## 🚀 Ready to Implement?

If you want to proceed, I can:
1. Create the `.env.dev.siimut` file for you
2. Update `docker-compose-multi-apps.yml` 
3. Create validation/helper scripts
4. Update documentation

Just confirm you're ready! 🎯
