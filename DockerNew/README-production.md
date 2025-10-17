# 🚀 SIIMUT Production Deployment Guide

## 📋 Pre-Deployment Checklist

### 1. Environment Configuration
- [ ] Copy `.env.production` and customize all values
- [ ] Change all default passwords and secrets
- [ ] Generate new Laravel APP_KEY
- [ ] Configure mail settings
- [ ] Set correct domain in APP_URL

### 2. Security Configuration
- [ ] Review and update all passwords
- [ ] Configure SSL/TLS certificates
- [ ] Review firewall rules
- [ ] Set up VPN access if needed

### 3. Infrastructure Requirements
- [ ] Docker and Docker Compose installed
- [ ] Sufficient disk space for volumes
- [ ] Backup strategy in place
- [ ] Monitoring tools configured

## 🏗️ Production Deployment

### Step 1: Prepare Environment
```bash
# Copy production environment
cp .env.production .env

# Edit with your production values
nano .env

# Generate Laravel application key
docker-compose run --rm app php artisan key:generate
```

### Step 2: Build and Deploy
```bash
# Build production images
docker-compose -f docker-compose-new.yml build --no-cache

# Start services
docker-compose -f docker-compose-new.yml up -d

# Check health status
docker-compose -f docker-compose-new.yml ps
```

### Step 3: Initial Setup
```bash
# Run migrations (if needed)
docker-compose -f docker-compose-new.yml exec app php artisan migrate --force

# Clear and cache configurations
docker-compose -f docker-compose-new.yml exec app php artisan config:cache
docker-compose -f docker-compose-new.yml exec app php artisan route:cache
docker-compose -f docker-compose-new.yml exec app php artisan view:cache

# Create storage link
docker-compose -f docker-compose-new.yml exec app php artisan storage:link
```

## 📊 Monitoring and Maintenance

### Health Checks
```bash
# Check all services health
docker-compose -f docker-compose-new.yml ps

# Check specific service health
docker inspect --format='{{.State.Health.Status}}' siimut-app
docker inspect --format='{{.State.Health.Status}}' siimut-db
docker inspect --format='{{.State.Health.Status}}' siimut-redis
```

### Logs Monitoring
```bash
# View all logs
docker-compose -f docker-compose-new.yml logs -f

# View specific service logs
docker-compose -f docker-compose-new.yml logs -f app
docker-compose -f docker-compose-new.yml logs -f db
docker-compose -f docker-compose-new.yml logs -f worker
```

### Performance Monitoring
```bash
# Check resource usage
docker stats

# Check PHP-FPM status
docker-compose -f docker-compose-new.yml exec app php-fpm -t

# Check OPcache status
docker-compose -f docker-compose-new.yml exec app php -r "var_dump(opcache_get_status());"
```

## 🔄 Updates and Maintenance

### Application Updates
```bash
# Pull latest code
git pull

# Rebuild with new code
docker-compose -f docker-compose-new.yml build --no-cache app worker

# Update services
docker-compose -f docker-compose-new.yml up -d --force-recreate app worker

# Run migrations if needed
docker-compose -f docker-compose-new.yml exec app php artisan migrate --force

# Clear caches
docker-compose -f docker-compose-new.yml exec app php artisan config:cache
docker-compose -f docker-compose-new.yml exec app php artisan route:cache
docker-compose -f docker-compose-new.yml exec app php artisan view:cache
```

### Database Maintenance
```bash
# Create database backup
docker-compose -f docker-compose-new.yml exec db mysqldump -u root -p siimut_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Database optimization
docker-compose -f docker-compose-new.yml exec db mysql -u root -p -e "OPTIMIZE TABLE table_name;"
```

## 🚨 Troubleshooting

### Common Issues

1. **Container Won't Start**
   ```bash
   # Check logs
   docker-compose -f docker-compose-new.yml logs service_name
   
   # Check health
   docker inspect --format='{{.State.Health}}' container_name
   ```

2. **Database Connection Issues**
   ```bash
   # Test database connection
   docker-compose -f docker-compose-new.yml exec app php artisan tinker --execute="DB::connection()->getPdo();"
   ```

3. **Redis Connection Issues**
   ```bash
   # Test Redis connection
   docker-compose -f docker-compose-new.yml exec app php artisan tinker --execute="Redis::ping();"
   ```

4. **Permission Issues**
   ```bash
   # Fix Laravel permissions
   docker-compose -f docker-compose-new.yml exec app chown -R www:www storage bootstrap/cache
   docker-compose -f docker-compose-new.yml exec app chmod -R 775 storage bootstrap/cache
   ```

### Emergency Recovery
```bash
# Stop all services
docker-compose -f docker-compose-new.yml down

# Remove containers but keep volumes
docker-compose -f docker-compose-new.yml down --remove-orphans

# Restart from scratch (CAUTION: This will remove data)
docker-compose -f docker-compose-new.yml down -v
```

## 🔐 Security Best Practices

1. **Regular Updates**
   - Keep Docker images updated
   - Update application dependencies
   - Apply security patches

2. **Access Control**
   - Use strong passwords
   - Implement proper firewall rules
   - Regular security audits

3. **Backup Strategy**
   - Automated database backups
   - Application file backups
   - Test restore procedures

4. **Monitoring**
   - Set up alerting for service failures
   - Monitor resource usage
   - Log analysis for security events

## 📈 Performance Optimization

### Database Optimization
- Regular OPTIMIZE TABLE commands
- Monitor slow query log
- Adjust MySQL configuration based on usage

### PHP Optimization
- Monitor OPcache hit rates
- Adjust PHP-FPM pool settings
- Use Laravel caching effectively

### Web Server Optimization
- Enable gzip compression (already configured)
- Use CDN for static assets
- Implement proper caching headers

## 🔗 Useful Commands

```bash
# Scale worker processes
docker-compose -f docker-compose-new.yml up -d --scale worker=3

# Enter container shell
docker-compose -f docker-compose-new.yml exec app sh

# Run Laravel commands
docker-compose -f docker-compose-new.yml exec app php artisan list

# Check composer dependencies
docker-compose -f docker-compose-new.yml exec app composer show

# View real-time logs
docker-compose -f docker-compose-new.yml logs -f --tail=100
```