# 🏥 SIIMUT Hospital Single-App Docker Configuration

## 🎯 **Optimized for Hospital Single-Application Use**

### **Arsitektur Baru: Unified Container**
```
┌─────────────────────────────────────────┐
│          Single App Container           │
├─────────────────────────────────────────┤
│  Supervisor (Process Manager)           │
│  ├── PHP-FPM (Web Application)         │
│  ├── Queue Worker (Background Jobs)     │
│  └── Scheduler (Cron Jobs)             │
└─────────────────────────────────────────┘
```

## 🚀 **Quick Start**

### **Production Deployment:**
```bash
# Start main services
docker-compose -f docker-compose-new.yml up -d

# Access application: http://localhost:8080
```

### **Development with phpMyAdmin:**
```bash
# Start with development profile (includes phpMyAdmin)
docker-compose -f docker-compose-new.yml --profile dev up -d

# Access application: http://localhost:8080
# Access phpMyAdmin: http://localhost:8081
```

## 📋 **Service Overview**

### **✅ Active Services:**
- **app** - Unified PHP container (PHP-FPM + Queue + Scheduler)
- **web** - Caddy web server (reverse proxy)
- **db** - MariaDB database
- **phpmyadmin** - Database management (dev profile only)

### **❌ Removed Services:**
- **redis** - Eliminated (using database instead)
- **worker** - Merged into app container

## 🔧 **Technical Implementation**

### **1. Supervisor Configuration**
File: `DockerNew/php/supervisord.conf`

**Managed Processes:**
- **php-fpm** - Handle HTTP requests (priority 100)
- **laravel-queue** - Process background jobs (priority 200)  
- **laravel-scheduler** - Handle scheduled tasks (priority 300)

### **2. Process Management**
```bash
# Check all processes status
docker-compose exec app supervisorctl status

# Restart specific process
docker-compose exec app supervisorctl restart laravel-queue

# View logs
docker-compose exec app supervisorctl tail laravel-queue
```

### **3. Resource Allocation**
```yaml
app:
  memory: 1.5G (increased for unified container)
  cpu: 1.5 cores
  
web: 
  memory: 256M
  cpu: 0.5 cores
  
db:
  memory: 512M  
  cpu: 1.0 core
```

## 📊 **Benefits Achieved**

### **Simplicity:**
- ✅ **3 containers** instead of 4 (75% of original)
- ✅ **1 build process** instead of 2
- ✅ **Unified logging** for app processes
- ✅ **Single deployment unit**

### **Resource Efficiency:**
```
BEFORE: app(1G) + worker(512M) + db(512M) + web(256M) = 2.28GB
AFTER:  app(1.5G) + db(512M) + web(256M) = 2.27GB
SAVED:  ~No significant change, but simplified management
```

### **Operational:**
- ✅ **Easier monitoring** (one container to watch)
- ✅ **Simpler debugging** (all logs in one place)
- ✅ **Faster deployment** (fewer containers)
- ✅ **Better process management** (supervisor handles restarts)

## 🏥 **Hospital-Specific Optimizations**

### **1. Profile-based phpMyAdmin**
```bash
# Production (no phpMyAdmin)
docker-compose up -d

# Development/Admin (with phpMyAdmin)  
docker-compose --profile dev up -d
```

### **2. Health Checks**
- **Web**: Simple root path check (`/`)
- **App**: Supervisor process status + PHP extensions
- **DB**: MariaDB built-in health check

### **3. Security**
- **No exposed database ports** in production
- **Non-root user** (1000:1000) for all processes
- **Read-only config mounts**
- **Resource limits** to prevent abuse

## 🛠️ **Operations Guide**

### **Deployment:**
```bash
# 1. Prepare environment
cp .env.production .env
nano .env  # Customize settings

# 2. Build and deploy
docker-compose -f docker-compose-new.yml build
docker-compose -f docker-compose-new.yml up -d

# 3. Verify health
docker-compose -f docker-compose-new.yml ps
```

### **Monitoring:**
```bash
# Check container health
docker-compose ps

# Check supervisor processes
docker-compose exec app supervisorctl status

# View application logs
docker-compose logs -f app

# View specific process logs
docker-compose exec app tail -f /var/log/supervisor/laravel-queue.log
```

### **Maintenance:**
```bash
# Restart queue worker (if needed)
docker-compose exec app supervisorctl restart laravel-queue

# Run artisan commands
docker-compose exec app php artisan migrate

# Access container shell
docker-compose exec app bash
```

## 🔍 **Troubleshooting**

### **Process Not Running:**
```bash
# Check supervisor status
docker-compose exec app supervisorctl status

# Restart all processes
docker-compose exec app supervisorctl restart all

# Check logs
docker-compose exec app supervisorctl tail -f laravel-queue
```

### **Database Connection Issues:**
```bash
# Test database connection
docker-compose exec app php artisan tinker --execute="DB::connection()->getPdo();"
```

### **Queue Issues:**
```bash
# Monitor queue
docker-compose exec app php artisan queue:monitor

# Process failed jobs
docker-compose exec app php artisan queue:retry all
```

## 📈 **Performance Notes**

### **For Hospital Use:**
- **Perfect for internal applications** (< 1000 concurrent users)
- **Database queue sufficient** for background jobs
- **Supervisor ensures** process reliability
- **Simple backup strategy** (database only)

### **Scaling Options:**
If you need to scale later:
```bash
# Scale app containers (with load balancer)
docker-compose up -d --scale app=3

# Or separate queue worker later if needed
# (supervisor makes it easy to disable queue and run separate container)
```

## 🎯 **Result**

**Perfect for Hospital Single-App Environment:**
- ✅ **Simple deployment** and management
- ✅ **Reliable process management** with supervisor
- ✅ **Development flexibility** with profiles
- ✅ **Production security** with proper isolation
- ✅ **Cost-effective** resource usage

**Philosophy maintained: "Sehat, kenapa harus pakai obat?"** - Simple, reliable, and efficient! 🏥✨