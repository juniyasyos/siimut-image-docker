# Docker Compose - Three Applications Setup

File ini berisi setup lengkap untuk menjalankan 3 aplikasi Laravel sekaligus:
1. **SIIMUT** (port 8000)
2. **IKP** (port 8001) - NEW
3. **IAM** (port 8100) - optional, currently commented out

## File: `docker-compose-three-apps.yml`

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Nginx Web Server                         │
│  Ports: 8000 (SIIMUT), 8001 (IKP), 8100 (IAM - optional)       │
└────────────────┬──────────────────────┬──────────────────────────┘
                 │                      │
    ┌────────────┴──────────┐  ┌────────┴────────────┐
    │                       │  │                     │
┌───▼──────┐  ┌────────┐ ┌─▼──▼──────┐  ┌────────┐ ┌─▼──────────┐
│ SIIMUT   │  │ Queue  │ │ Scheduler │  │   IKP  │ │ Queue/Sch  │
│  (app)   │  │ Worker │ │ (SIIMUT)  │  │ (app)  │ │ (IKP)      │
└────┬─────┘  └───┬────┘ └─┬────────┘  └────┬───┘ └──┬─────────┘
     │            │         │                │        │
     └────────────┴─────────┼────────────────┴────────┘
                            │
                    ┌───────▼────────┐
                    │  MariaDB       │
                    │  (Shared DB)   │
                    └────────────────┘
```

### Services

#### Web Server (Nginx)
- Container: `{STACK_NAME}-web`
- Ports: 
  - `8000:8000` - SIIMUT app
  - `8001:8001` - IKP app
  - `8002:8002` - Reserved for future use
- Memory: 256MB limit, 128MB reservation
- CPU: 0.2 limit, 0.1 reservation

#### Database (MariaDB)
- Container: `{STACK_NAME}-db`
- Image: `mariadb:10.11`
- No external port exposure (internal only)
- Memory: 512MB limit, 256MB reservation
- CPU: 1.0 limit, 0.5 reservation
- Volumes:
  - `db_data` - Database files
  - `db_logs` - Log files

#### SIIMUT Application
**Main App** (`app-siimut`)
- Container: `siimut-app`
- Dockerfile: `DockerNew/php/Dockerfile.siimut-registry`
- Working Dir: `/var/www/siimut`
- Database: `siimut_db` with user `siimut_user`
- Memory: 1.5GB limit, 768MB reservation
- CPU: 1.5 limit, 0.75 reservation

**Queue Worker** (`queue-siimut`)
- Container: `siimut-queue`
- Processes background jobs
- Memory: 512MB limit, 128MB reservation
- CPU: 1.0 limit, 0.25 reservation

**Scheduler** (`scheduler-siimut`)
- Container: `siimut-scheduler`
- Runs scheduled tasks
- Memory: 256MB limit, 128MB reservation
- CPU: 0.25 limit, 0.125 reservation

#### IKP Application (NEW)
**Main App** (`app-ikp`)
- Container: `ikp-app`
- Dockerfile: `DockerNew/php/Dockerfile.ikp-registry`
- Working Dir: `/var/www/ikp`
- Database: `ikp_db` with user `ikp_user`
- Memory: 1.5GB limit, 768MB reservation
- CPU: 1.5 limit, 0.75 reservation
- Public URL: `http://192.168.1.9:8001`

**Queue Worker** (`queue-ikp`)
- Container: `ikp-queue`
- Memory: 512MB limit, 128MB reservation
- CPU: 1.0 limit, 0.25 reservation

**Scheduler** (`scheduler-ikp`)
- Container: `ikp-scheduler`
- Memory: 256MB limit, 128MB reservation
- CPU: 0.25 limit, 0.125 reservation

#### IAM Application (Optional)
- Currently commented out
- Uncomment the entire `app-iam` section if needed
- Port: `8100`

## Setup Requirements

### 1. Directory Structure
Ensure your repository has this structure:
```
siimut-image-docker/
├── site/
│   ├── siimut/
│   │   ├── composer.json
│   │   ├── composer.lock
│   │   └── ... (Laravel files)
│   └── ikp/
│       ├── composer.json
│       ├── composer.lock
│       └── ... (Laravel files)
├── DockerNew/
│   └── php/
│       ├── Dockerfile.siimut-registry
│       ├── Dockerfile.ikp-registry
│       └── entrypoint-registry.sh
├── docker-compose-three-apps.yml
└── ...
```

### 2. Environment Variables

Create `.env` file or pass via environment:
```bash
# Stack naming
STACK_NAME=myapp

# MariaDB
MYSQL_ROOT_PASSWORD=root-password
MYSQL_DATABASE=app_db
MYSQL_USER=app_user
MYSQL_PASSWORD=app-password

# Optional S3/MinIO
AWS_ACCESS_KEY_ID=admin
AWS_SECRET_ACCESS_KEY=password
```

### 3. IKP Repository Setup

Clone IKP repository to `site/ikp/`:
```bash
git clone https://github.com/juniyasyos/ikp.git site/ikp
```

Or if you want to integrate it into the existing monorepository structure, ensure:
- `site/ikp/composer.json` exists
- `site/ikp/composer.lock` exists (for reproducible builds)
- `.env` file is configured in IKP app

## Build & Run

### Build all images
```bash
docker compose -f docker-compose-three-apps.yml build
```

### Start all services
```bash
docker compose -f docker-compose-three-apps.yml up -d
```

### View logs
```bash
# All services
docker compose -f docker-compose-three-apps.yml logs -f

# Specific service
docker compose -f docker-compose-three-apps.yml logs -f siimut-app
docker compose -f docker-compose-three-apps.yml logs -f ikp-app
docker compose -f docker-compose-three-apps.yml logs -f {STACK_NAME}-db
```

### Stop services
```bash
docker compose -f docker-compose-three-apps.yml down
```

### Remove volumes (reset data)
```bash
docker compose -f docker-compose-three-apps.yml down -v
```

## Database Setup

### Create databases
```bash
# Access database
docker exec -it {STACK_NAME}-db mysql -u root -p

# Or use:
docker compose -f docker-compose-three-apps.yml exec database-service mysql -u root -p
```

### Initial migrations

After containers are running:
```bash
# SIIMUT
docker compose -f docker-compose-three-apps.yml exec app-siimut php artisan migrate

# IKP
docker compose -f docker-compose-three-apps.yml exec app-ikp php artisan migrate
```

## Accessing Applications

- **SIIMUT**: http://192.168.1.9:8000
- **IKP**: http://192.168.1.9:8001
- **IAM**: http://192.168.1.9:8100 (if enabled)

## Resource Management

### Total Resources (All 3 Apps + DB + Nginx)
- **Memory Limits**: 
  - Nginx: 256MB
  - Database: 512MB
  - SIIMUT (3 services): 2GB
  - IKP (3 services): 2GB
  - **Total: ~5GB**

- **CPU Limits**: ~4 cores

### Adjusting Resources
Edit resource limits in `docker-compose-three-apps.yml` under `deploy.resources` for each service.

## Nginx Configuration

The Nginx configuration should be updated to handle multiple apps. Key configuration needed:
- Route `/` to SIIMUT (port 8000)
- Route `/ikp` (or separate origin) to IKP (port 8001)
- Route `/iam` (or separate origin) to IAM (port 8100) - if enabled

Update `DockerNew/nginx/nginx-multi-apps.conf` accordingly:
```nginx
# SIIMUT upstream
upstream siimut {
    server app-siimut:9000;
}

# IKP upstream
upstream ikp {
    server app-ikp:9000;
}

# SIIMUT (default)
server {
    listen 8000;
    location / {
        fastcgi_pass siimut;
        # ... other config
    }
}

# IKP
server {
    listen 8001;
    location / {
        fastcgi_pass ikp;
        # ... other config
    }
}
```

## Network

- Network name: `rsch_network` (bridge)
- All services communicate internally via service names
- Example: From IKP, access database via `database-service:3306`

## Storage & Persistence

- `siimut_storage` - SIIMUT storage directory
- `siimut_bootstrap_cache` - SIIMUT bootstrap cache
- `siimut_public` - SIIMUT public assets
- `ikp_storage` - IKP storage directory (NEW)
- `ikp_bootstrap_cache` - IKP bootstrap cache (NEW)
- `ikp_public` - IKP public assets (NEW)
- `db_data` - Database files
- `db_logs` - Database logs
- `nginx_logs` - Nginx logs

## Troubleshooting

### Service won't start
Check logs: `docker compose -f docker-compose-three-apps.yml logs {service_name}`

### Database connection failed
- Ensure database is running: `docker ps | grep db`
- Check credentials match in Dockerfile build args vs database service env vars
- Verify network connectivity: `docker network inspect rsch_network`

### Public assets not serving
- Ensure volumes are mounted in Nginx: `docker volume ls | grep public`
- Check file permissions in containers: `docker exec {container} ls -la /var/www/{app}/public/`

### Queue not processing
- Check if `queue-{app}` container is running
- View queue logs: `docker compose -f docker-compose-three-apps.yml logs queue-{app}`
- Check database connection in queue worker

## Next Steps

1. ✅ Clone or integrate IKP repository to `site/ikp/`
2. ✅ Ensure `Dockerfile.ikp-registry` is in place
3. Configure `DockerNew/nginx/nginx-multi-apps.conf` for IKP routing
4. Build: `docker compose -f docker-compose-three-apps.yml build`
5. Run: `docker compose -f docker-compose-three-apps.yml up -d`
6. Run migrations: `docker compose -f docker-compose-three-apps.yml exec app-ikp php artisan migrate`
7. Access via `http://192.168.1.9:8001`
