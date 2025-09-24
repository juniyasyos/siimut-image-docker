# SIIMUT Enhanced Entrypoints

Koleksi entrypoint scripts yang telah dioptimalkan untuk berbagai skenario deployment container SIIMUT.

## 📁 Available Entrypoints

### 1. `entrypoint-enhanced.sh` (Recommended)
**Full-featured entrypoint dengan semua fitur.**

**Fitur:**
- ✅ Support multiple database types (MySQL/PostgreSQL/SQLite)
- ✅ Smart environment configuration
- ✅ Composer management dengan retry mechanism
- ✅ Redis/cache optimization
- ✅ Health checks dan monitoring
- ✅ Migration dan seeding support
- ✅ Queue worker support
- ✅ Robust permission handling
- ✅ Colored logging output

**Environment Variables:**
```bash
APP_ENV=production                    # Environment mode
SIIMUT_WAIT_FOR_DB=true              # Wait for database
SIIMUT_WAIT_FOR_REDIS=true           # Wait for Redis  
SIIMUT_RUN_MIGRATIONS=false          # Auto-run migrations
SIIMUT_RUN_SEEDERS=false             # Auto-run seeders
SIIMUT_STORAGE_LINK=true             # Create storage link
SIIMUT_OPTIMIZE_CACHE=true           # Cache optimization
SIIMUT_QUEUE_WORKER=false            # Start queue worker
SIIMUT_DEBUG=false                   # Debug mode
```

### 2. `entrypoint-production.sh`
**Lightweight production entrypoint.**

**Fitur:**
- ⚡ Fast startup time
- 🔒 Security focused
- 💾 Minimal resource usage
- ✅ Essential optimizations only
- ⏱️ Quick health checks

**Best for:** Production deployments, Kubernetes, high-traffic sites

### 3. `entrypoint-development.sh` 
**Development-focused dengan debugging tools.**

**Fitur:**
- 🛠️ Development packages support
- 🐛 Xdebug integration
- 🔄 Hot reload friendly
- 🗄️ Auto-migrations
- 🌱 Auto-seeding
- 📝 Permissive permissions
- 🎨 Colored debug output

**Environment Variables:**
```bash
SIIMUT_AUTO_MIGRATE=true             # Auto-run migrations
SIIMUT_AUTO_SEED=false               # Auto-run seeders
SIIMUT_INSTALL_DEV_DEPS=true         # Install dev dependencies
SIIMUT_CLEAR_CACHE=true              # Clear all caches
SIIMUT_ENABLE_XDEBUG=false           # Enable Xdebug
```

**Best for:** Local development, testing, debugging

### 4. `entrypoint-caddy.sh`
**Optimized untuk Caddy web server.**

**Fitur:**
- 🌐 Caddy reverse proxy optimization
- 📁 Static file serving optimization
- 🔐 HTTPS/TLS certificate support
- 💚 Health check endpoints
- 🏃‍♂️ Graceful shutdown handling

**Environment Variables:**
```bash
SIIMUT_CADDY_OPTIMIZE=true           # Caddy optimizations
SIIMUT_STATIC_CACHE=true             # Static file caching
SIIMUT_HEALTH_CHECK=true             # Health check endpoint
```

**Best for:** Caddy server deployments, microservices, load balanced setups

### 5. `entrypoint-minimal.sh`
**Ultra-minimal bootstrap.**

**Fitur:**
- ⚡ Fastest startup
- 🎯 Essential operations only
- 🐛 Perfect for debugging
- 📦 Minimal dependencies

**Best for:** Testing, debugging, CI/CD, resource-constrained environments

## 🚀 Usage

### Quick Start

```bash
# Using enhanced entrypoint (default)
docker run -v ./Docker/php/entrypoint-enhanced.sh:/entrypoint.sh myapp /entrypoint.sh php-fpm

# Using production entrypoint
docker run -v ./Docker/php/entrypoint-production.sh:/entrypoint.sh myapp /entrypoint.sh php-fpm

# Using development entrypoint
docker run -v ./Docker/php/entrypoint-development.sh:/entrypoint.sh myapp /entrypoint.sh php-fpm
```

### With Entrypoint Selector (Recommended)

```bash
# Auto-detect mode based on environment
docker run -v ./Docker/php/entrypoint-selector.sh:/entrypoint.sh myapp /entrypoint.sh auto php-fpm

# Explicit mode selection
docker run -v ./Docker/php/entrypoint-selector.sh:/entrypoint.sh myapp /entrypoint.sh development php-fpm
```

## 🐳 Docker Compose Examples

### Production Setup
```yaml
services:
  app:
    build: .
    volumes:
      - ./Docker/php/entrypoint-production.sh:/entrypoint.sh:ro
    entrypoint: ["/entrypoint.sh"]
    command: ["php-fpm"]
    environment:
      - APP_ENV=production
      - SIIMUT_WAIT_FOR_DB=true
      - SIIMUT_OPTIMIZE_CACHE=true
```

### Development Setup
```yaml
services:
  app:
    build: .
    volumes:
      - ./Docker/php/entrypoint-development.sh:/entrypoint.sh:ro
      - ./site:/var/www/html:rw
    entrypoint: ["/entrypoint.sh"]  
    command: ["php-fpm"]
    environment:
      - APP_ENV=local
      - SIIMUT_AUTO_MIGRATE=true
      - SIIMUT_ENABLE_XDEBUG=true
```

### Auto-Detection Setup (Flexible)
```yaml
services:
  app:
    build: .
    volumes:
      - ./Docker/php/entrypoint-selector.sh:/entrypoint.sh:ro
      - ./Docker/php:/entrypoints:ro
    entrypoint: ["/entrypoint.sh"]
    command: ["auto", "php-fpm"]
    environment:
      - APP_ENV=${APP_ENV:-production}
      - SIIMUT_MODE=${SIIMUT_MODE:-auto}
```

### Caddy Integration
```yaml
services:
  app:
    build: .
    volumes:
      - ./Docker/php/entrypoint-caddy.sh:/entrypoint.sh:ro
    entrypoint: ["/entrypoint.sh"]
    command: ["php-fpm"]
    environment:
      - SIIMUT_CADDY_OPTIMIZE=true
      - SIIMUT_HEALTH_CHECK=true
      
  caddy:
    image: caddy:alpine
    depends_on: [app]
    # Caddy config...
```

## 🔧 Advanced Configuration

### Multi-Database Support

The enhanced entrypoint auto-detects database type:

```bash
# MySQL
MYSQL_DATABASE=siimut
MYSQL_USER=siimut  
MYSQL_PASSWORD=secret

# PostgreSQL  
POSTGRES_DB=siimut
POSTGRES_USER=siimut
POSTGRES_PASSWORD=secret

# SQLite
DB_CONNECTION=sqlite
DB_DATABASE=/var/www/html/database/database.sqlite
```

### Queue Workers

Enable background queue processing:

```bash
SIIMUT_QUEUE_WORKER=true
```

### Custom Health Checks

The Caddy entrypoint creates `/health` endpoint:

```bash
curl http://localhost/health
# {"status":"ok","timestamp":1634567890,"database":"connected"}
```

## 🛠️ Troubleshooting

### Permission Issues

If you encounter permission issues:

```bash
# For development
SIIMUT_DEBUG=true docker-compose up

# Manual permission fix
docker-compose exec app chown -R www-data:www-data /var/www/html
```

### Database Connection Issues

```bash
# Increase wait timeout
SIIMUT_WAIT_FOR_DB=true
SIIMUT_DEBUG=true

# Check database connectivity manually
docker-compose exec app nc -z db 3306
```

### Cache Issues

```bash
# Clear all caches
docker-compose exec app php artisan cache:clear
docker-compose exec app php artisan config:clear
docker-compose exec app php artisan route:clear
docker-compose exec app php artisan view:clear
```

## 📊 Performance Comparison

| Entrypoint | Startup Time | Memory Usage | Features | Best For |
|------------|-------------|--------------|----------|----------|
| Enhanced | ~15-30s | Medium | Full | General use |
| Production | ~5-10s | Low | Essential | Production |
| Development | ~20-45s | High | Full + Debug | Development |
| Caddy | ~10-20s | Medium | Web optimized | Caddy server |
| Minimal | ~2-5s | Very Low | Basic | Testing |

## 🔐 Security Considerations

- Production entrypoints disable debug mode
- File permissions are set appropriately
- Sensitive environment variables are handled securely
- Health check endpoints don't expose sensitive data

## 📝 Migration from Old Entrypoint

Replace your old entrypoint:

```bash
# Old
ENTRYPOINT ["/entrypoint.sh"]

# New (recommended)
COPY Docker/php/entrypoint-selector.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["auto", "php-fpm"]
```

Or keep existing structure:

```bash
# Replace your existing entrypoint file
cp Docker/php/entrypoint-enhanced.sh Docker/php/entrypoint.sh
```