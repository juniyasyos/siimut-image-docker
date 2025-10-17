# Health Check Configuration for DockerNew

## Health Check Endpoints

### 1. Caddy Health Check
The Caddy health check expects a `/health` endpoint. Create this in your Laravel application:

**routes/web.php**:
```php
Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'timestamp' => now()->toISOString(),
        'services' => [
            'database' => 'ok',  // Add actual DB check
            'redis' => 'ok',     // Add actual Redis check
            'app' => 'ok'
        ]
    ]);
});
```

### 2. Database Health Check
MariaDB container uses built-in health check script.

### 3. Redis Health Check  
Redis uses built-in `redis-cli ping` command.

### 4. PHP-FPM Health Check
Uses `php-fpm -t` to test configuration.

### 5. Queue Worker Health Check
Uses `php artisan queue:monitor` (requires Laravel 9+).

## Monitoring

All services include health checks with:
- **interval**: 30s (how often to check)
- **timeout**: 10s (how long to wait for response)
- **retries**: 3 (how many failures before marking unhealthy)
- **start_period**: 30-60s (grace period during startup)

## Usage

Check container health:
```bash
docker-compose ps
docker inspect --format='{{.State.Health.Status}}' container_name
```