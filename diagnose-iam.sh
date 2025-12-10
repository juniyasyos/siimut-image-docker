#!/bin/bash
# =========================
# Diagnostic Script for IAM Server 502 Error
# =========================

echo "======================================"
echo "🔍 IAM Server Diagnostics"
echo "======================================"
echo ""

# 1. Check if containers are running
echo "1️⃣ Container Status:"
echo "---"
docker ps -a --filter "name=iam" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# 2. Check container health
echo "2️⃣ Health Checks:"
echo "---"
docker inspect iam-app --format='{{.State.Health.Status}}' 2>/dev/null || echo "No health check"
docker inspect iam-web --format='{{.State.Health.Status}}' 2>/dev/null || echo "No health check"
echo ""

# 3. Check network connectivity
echo "3️⃣ Network Connectivity:"
echo "---"
echo "Database container:"
docker ps --filter "name=database" --format "table {{.Names}}\t{{.Status}}"
echo ""
echo "Network connection test:"
docker exec iam-app ping -c 2 database-service 2>/dev/null || echo "❌ Cannot reach database"
docker exec iam-web ping -c 2 app 2>/dev/null || echo "❌ Cannot reach app from web"
echo ""

# 4. Check PHP-FPM status
echo "4️⃣ PHP-FPM Status:"
echo "---"
docker exec iam-app ps aux | grep php-fpm | head -5 || echo "❌ PHP-FPM not running"
echo ""

# 5. Check recent logs
echo "5️⃣ Recent App Logs (last 20 lines):"
echo "---"
docker logs iam-app --tail 20 2>&1
echo ""

echo "6️⃣ Recent Caddy Logs (last 20 lines):"
echo "---"
docker logs iam-web --tail 20 2>&1
echo ""

# 7. Check ports
echo "7️⃣ Port Bindings:"
echo "---"
docker port iam-web 2>/dev/null || echo "No ports"
echo ""

# 8. Test PHP-FPM directly
echo "8️⃣ PHP-FPM Test:"
echo "---"
docker exec iam-app php -v || echo "❌ PHP not working"
docker exec iam-app php artisan --version 2>&1 || echo "❌ Laravel not working"
echo ""

# 9. Check file permissions
echo "9️⃣ File Permissions:"
echo "---"
docker exec iam-app ls -la /var/www/iam/ | head -10
echo ""

# 10. Test internal connection
echo "🔟 Internal Connection Test:"
echo "---"
echo "Test from Caddy to PHP-FPM:"
docker exec iam-web wget -O- http://app:9000 2>&1 | head -5 || echo "❌ Cannot connect"
echo ""

echo "======================================"
echo "💡 Common Issues & Solutions:"
echo "======================================"
echo "1. Container not healthy → Check logs above"
echo "2. Network issues → Verify both containers in same network"
echo "3. PHP-FPM not responding → Restart app container"
echo "4. Permission denied → Check volume mounts"
echo "5. Database connection → Verify DB_HOST in .env"
echo ""
echo "Quick fixes to try:"
echo "  docker-compose -f docker-compose.iam-registry.yml restart app"
echo "  docker-compose -f docker-compose.iam-registry.yml restart web"
echo "  docker-compose -f docker-compose.iam-registry.yml logs -f"
