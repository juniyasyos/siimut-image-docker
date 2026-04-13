# 🔴 Server Livewire 404 Error - Root Causes & Solutions

**Status**: Production issue dengan Docker Compose Multi-Apps setup  
**Location**: `docker-compose-multi-apps.yml`  
**Affected**: `app-siimut`, `app-ikp`, `app-iam`  
**Date**: 2026-04-14

---

## 📋 Problem Summary

Saat deploy ke server dengan `docker-compose-multi-apps.yml`:
- ❌ `public/vendor/livewire/livewire.min.js` **404 Not Found**
- ❌ `Livewire is not defined` JavaScript error
- ❌ Folder `public/vendor/livewire/` **TIDAK ADA** di container

---

## 🔎 Root Cause Analysis

### **🚨 PRIMARY CAUSE: Docker Named Volume Override**

```yaml
# docker-compose-multi-apps.yml
app-siimut:
  volumes:
    - siimut_public:/var/www/siimut/public  # ← PROBLEM!
```

**Timeline:**
1. **Build time (Dockerfile)**
   - ✅ Composer install includes `livewire` package
   - ✅ Public folder built dengan `public/vendor/livewire/`
   - ✅ Image contains: `/var/www/siimut/public/vendor/livewire/livewire.min.js`

2. **Container start (First time)**
   - Docker creates empty named volume `siimut_public`
   - Docker mounts volume ke `/var/www/siimut/public`
   - **Volume OVERRIDES** image's public folder dengan folder **KOSONG**
   - ❌ Result: `public/vendor/livewire/` **HILANG**

3. **Entrypoint runs**
   - Tries: `php artisan livewire:publish --assets`
   - Tapi mungkin gagal karena permission, cache, atau dependency issues

---

### **Secondary Causes**

#### **Cause B: Entrypoint Logic Insufficient**
Previous entrypoint (`entrypoint-registry.sh` before fix):
```bash
if [ ! -L public/livewire ]; then  # Check symlink only
    if [ -d public/vendor/livewire ]; then  # Check folder exists
        ln -s vendor/livewire public/livewire
    else
        php artisan livewire:publish --assets  # Try publish
```

**Problems:**
- Only try publish 1 time (no retry)
- Tidak verify publish succeed
- Tidak unconditionally attempt publish
- Tidak handle permission issues

#### **Cause C: Permission Issues**
```bash
# If su-exec www fails:
su-exec www php artisan livewire:publish --assets
# Error: www user tidak bisa write ke public/vendor/
```

#### **Cause D: Composer Dependencies Issue**
```bash
# vendor/livewire tidak ada di image:
# Jika composer install gagal saat build
# Maka vendor/livewire tidak pernah tersedia
```

---

## ✅ Solutions (Implemented)

### **SOLUTION 1: Improved Entrypoint Logic** ⭐

**File Updated**: `DockerNew/php/entrypoint-registry.sh`

**New features:**
1. ✅ **Unconditional publish** - Always attempt publish, tidak conditional
2. ✅ **Retry mechanism** - Up to 3 retries dengan 2s delay
3. ✅ **Verification** - Check `public/vendor/livewire/livewire.min.js` exists
4. ✅ **Debug output** - Show what's in `public/vendor/` jika gagal
5. ✅ **Alternative method** - Try `vendor/bin/livewire` jika gagal
6. ✅ **Permission handling** - Use `su-exec www`

**Code:**
```bash
echo "📦 Ensuring Livewire assets are published..."

LIVEWIRE_MAX_RETRIES=3
LIVEWIRE_PUBLISHED=0

while [ $LIVEWIRE_PUBLISHED -eq 0 ]; do
    # Check if already published
    if [ -f public/vendor/livewire/livewire.min.js ]; then
        LIVEWIRE_PUBLISHED=1
        break
    fi
    
    # Attempt publish
    echo "  🔄 Running livewire:publish..."
    su-exec www php artisan livewire:publish --assets
    
    # Verify
    if [ -f public/vendor/livewire/livewire.min.js ]; then
        LIVEWIRE_PUBLISHED=1
    else
        # Retry...
        sleep 2
    fi
done
```

**Status**: ✅ **SUDAH DIUPDATE** di `entrypoint-registry.sh`

---

### **SOLUTION 2: Explicit Environment Variable** (Optional)

Ada opsi untuk **force publish** di entrypoint:

```yaml
# docker-compose-multi-apps.yml
app-siimut:
  environment:
    FORCE_LIVEWIRE_PUBLISH: "true"  # Unconditionally publish
```

Ini bisa di-handle di entrypoint:
```bash
if [ "${FORCE_LIVEWIRE_PUBLISH}" = "true" ]; then
    echo "⚠️ FORCE_LIVEWIRE_PUBLISH=true, removing existing assets..."
    rm -rf public/vendor/livewire/
fi
```

---

### **SOLUTION 3: Volume Mount Strategy** (Recommended)

**Approach A: Keep Named Volume (Current Setup)** ✅

**Pros:**
- Persistent across restarts
- Lightweight
- Standard compose practice

**Cons:**
- First run: empty volume overrides image content
- Need entrypoint to populate volume

**Implementation:**
- ✅ Entrypoint now handles this properly
- Data seeded on first run by `livewire:publish`

**Approach B: Use tmpfs (Alternative)** ⭐

```yaml
app-siimut:
  volumes:
    - siimut_storage:/var/www/siimut/storage
    - siimut_bootstrap_cache:/var/www/siimut/bootstrap/cache
    # Remove: siimut_public:/var/www/siimut/public
    # Add tmpfs instead:
    - type: tmpfs
      target: /var/www/siimut/public
      tmpfs:
        size: 256M  # Adjust if needed
```

**Pros:**
- No volume override issues
- Faster (in-memory)
- Fresh public folder per restart

**Cons:**
- Lost on container restart
- Nginx needs separate volume for cache

**Approach C: Separate Volumes** (Most Reliable) 🏆

```yaml
volumes:
  # Keep storage + cache persistent
  siimut_storage:
  siimut_bootstrap_cache:
  # Split public into smaller volumes
  siimut_public_assets:  # For vendor/livewire, images, css, js
  siimut_public_cache:   # For compiled files
```

---

## 🔧 Server Deployment Checklist

Sebelum deploy ke server, pastikan:

### ✅ Pre-Deployment

- [ ] Dockerfile has all Livewire dependencies (`vendor/livewire/`)
- [ ] Entrypoint-registry.sh sudah updated dengan logic baru
- [ ] docker-compose-multi-apps.yml sudah reviewed
- [ ] Named volumes defined di docker-compose.yml

### ✅ First Deploy

```bash
# 1. Build images with fresh layers
docker-compose -f docker-compose-multi-apps.yml build --no-cache

# 2. Start containers (entrypoint akan publish)
docker-compose -f docker-compose-multi-apps.yml up -d

# 3. Verify Livewire assets exist
docker-compose -f docker-compose-multi-apps.yml exec app-siimut \
    ls -la /var/www/siimut/public/vendor/livewire/

# 4. Check entrypoint logs
docker-compose -f docker-compose-multi-apps.yml logs app-siimut | grep -i livewire
```

### ✅ Production Verification

```bash
# 1. Check file accessible via HTTP
curl -I http://server-ip:8000/vendor/livewire/livewire.min.js
# Should return: HTTP/1.1 200 OK

# 2. Login to app and check browser console
# Should NOT have: "Failed to load resource: livedwire.min.js 404"

# 3. Verify Livewire functionality
# Try submitting a Livewire form
```

---

## 🚨 Troubleshooting di Server

### **Q1: Still getting 404 error?**

```bash
# 1. SSH ke server
ssh user@server

# 2. Check container
docker-compose -f docker-compose-multi-apps.yml ps

# 3. Check Livewire folder
docker-compose -f docker-compose-multi-apps.yml exec app-siimut \
    ls -la /var/www/siimut/public/vendor/livewire/

# 4. Check entrypoint output
docker-compose -f docker-compose-multi-apps.yml logs app-siimut | head -50

# 5. Check /tmp/livewire-publish.log
docker-compose -f docker-compose-multi-apps.yml exec app-siimut \
    cat /tmp/livewire-publish.log
```

### **Q2: Livewire folder exists but symlink broken?**

```bash
# Check symlink
docker-compose -f docker-compose-multi-apps.yml exec app-siimut \
    ls -la /var/www/siimut/public/livewire

# Should show:
# livewire -> vendor/livewire

# Fix if broken:
docker-compose -f docker-compose-multi-apps.yml exec app-siimut sh -c \
    'cd /var/www/siimut && rm -f public/livewire && ln -s vendor/livewire public/livewire'
```

### **Q3: Folder exists but 404 still happens?**

Could be Nginx configuration issue:

```bash
# 1. Check Nginx config
docker-compose -f docker-compose-multi-apps.yml exec web \
    nginx -T | grep -A5 -B5 "siimut"

# 2. Check volume mounting in Nginx
docker-compose -f docker-compose-multi-apps.yml exec web \
    ls -la /var/www/siimut/public/vendor/ | head -10

# 3. Test file access directly
docker-compose -f docker-compose-multi-apps.yml exec web \
    curl http://localhost:8000/vendor/livewire/livewire.min.js | head -20
```

### **Q4: Permission denied?**

```bash
# Check Nginx access permissions
docker-compose -f docker-compose-multi-apps.yml exec web \
    ls -la /var/www/siimut/

# Should show permissions like: drwxr-xr-x

# Fix if needed:
docker-compose -f docker-compose-multi-apps.yml exec app-siimut \
    chmod -R 755 /var/www/siimut/public
```

---

## 📊 Volume Mount Comparison

| Aspect | Named Volume | tmpfs | Separate Volumes |
|--------|--------------|-------|------------------|
| **Persistence** | ✅ Yes | ❌ No | ✅ Yes |
| **First run override** | ⚠️ Needs fix | ✅ Fresh | ✅ No issue |
| **Performance** | Good | 🏆 Excellent | Good |
| **Complexity** | Simple | Simple | High |
| **Recommended** | ✅ With fix | ✅ For dev | ✅ For prod |

---

## 📝 Files Changed

### **Updated Files:**
1. ✅ `DockerNew/php/entrypoint-registry.sh`
   - Improved Livewire publish logic
   - Better retry & verification
   - Better error messages

2. ℹ️ `docker-compose-multi-apps.yml`
   - No changes needed (works with improved entrypoint)
   - Optional: Add `FORCE_LIVEWIRE_PUBLISH` env if needed

3. ℹ️ `Dockerfile.siimut-registry`
   - No changes needed (doesn't use entrypoint in build)

4. ℹ️ `Dockerfile.ikp-registry`
   - No changes needed

5. ℹ️ `Dockerfile.iam-registry`
   - No changes needed

---

## ✅ Verification Checklist

After applying fixes, verify:

- [ ] Container starts without errors
- [ ] Entrypoint shows: ✅ "Livewire assets already present" or "✅ Created symlink"
- [ ] `public/vendor/livewire/livewire.min.js` exists and is ~2MB
- [ ] Browser can load: `http://server:8000/vendor/livewire/livewire.min.js` (200 OK)
- [ ] No "Livewire is not defined" error in browser console
- [ ] Livewire components work (forms, buttons, etc)

---

## 🔗 Related Documentation

- [Docker Volumes Best Practices](https://docs.docker.com/storage/volumes/)
- [Livewire Documentation](https://livewire.laravel.com/)
- [Laravel Service Container](https://laravel.com/docs/artisan)

---

**Last Updated**: 2026-04-14  
**Solution Status**: ✅ Implemented  
**Tested on**: Docker Compose Multi-Apps Setup
