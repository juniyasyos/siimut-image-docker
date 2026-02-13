# 📊 Visual Flow Diagrams

## 1. PREPARE → BUILD → RUNTIME Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SIIMUT DEPLOYMENT FLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐
│   PREPARE STAGE             │
│  ./prepare-siimut.sh        │
└─────────────────────────────┘
            ↓
      ┌─────────────┐
      │ Read        │
      │env/.env.    │
      │siimut       │
      └─────┬───────┘
            │
      APP_DIR=siimut
      REPO_URL=...
            │
            ↓
      ┌─────────────────────────┐
      │ Clone/Pull              │
      │ site/siimut/ ← git      │
      └─────────────────────────┘
            │
            ↓
      ┌─────────────────────────┐
      │ Copy                    │
      │ .env.example → .env     │
      │ (if not exist)          │
      └─────────────────────────┘
            │
            ↓
    ✅ Ready for build


┌─────────────────────────────┐
│   BUILD STAGE               │
│  docker build               │
└─────────────────────────────┘
            ↓
┌───────────────────────────────────────────────────┐
│ Stage 1: base                                     │
│ - PHP extensions, composer, www user              │
│ - Immutable (part of image)                       │
└────────────────┬──────────────────────────────────┘
                 ↓
┌───────────────────────────────────────────────────┐
│ Stage 2: deps                                     │
│ - Read: site/siimut/composer.json                 │
│ - Copy: site/siimut/ → /app                       │
│ - composer dump-autoload --optimize               │
│ - Immutable (part of image)                       │
└────────────────┬──────────────────────────────────┘
                 ↓
┌───────────────────────────────────────────────────┐
│ Stage 3: runtime                                  │
│ - Copy app from deps: /app → /var/www/siimut      │
│ - Create storage/ bootstrap/cache dirs            │
│ - Copy entrypoint-registry.sh script              │
│ - Set permissions                                 │
│ - Immutable (part of image)                       │
└────────────────┬──────────────────────────────────┘
                 ↓
    ✅ Image ready: service-app-app-siimut:latest


┌─────────────────────────────┐
│   RUNTIME STAGE             │
│  docker-compose up          │
└─────────────────────────────┘
            ↓
      ┌─────────────────────┐
      │ Load Env Vars       │
      │ Priority:           │
      │ 1. environment:     │
      │ 2. env_file:        │
      │ 3. .env file        │
      └──────────┬──────────┘
                 ↓
      ┌──────────────────────────────────────┐
      │ entrypoint-registry.sh start          │
      ├──────────────────────────────────────┤
      │ 1. switch-auth-mode.sh dev            │ ← Update .env
      │    (update site/siimut/.env)          │
      │ 2. Wait database connection           │
      │ 3. npm install + npm run build        │
      │ 4. php artisan cache:clear            │
      │ 5. php artisan config:cache           │
      │ 6. php artisan route:cache            │
      │ 7. Set permissions storage/           │
      │ 8. Start: php-fpm -F                  │
      └──────────┬───────────────────────────┘
                 ↓
    ✅ Container ready: listen on :9000
```

---

## 2. ENV VARIABLES PRIORITY & SOURCE

```
┌──────────────────────────────────────────────────────────────┐
│              ENVIRONMENT VARIABLES HIERARCHY                 │
└──────────────────────────────────────────────────────────────┘

                    Priority 1️⃣ (Highest)
                         ↓
            ┌─────────────────────────┐
            │ docker-compose          │
            │ environment:            │
            │  APP_ENV: production    │
            │  USE_SSO: "false"       │
            │  LOG_LEVEL: warning     │
            └────────┬────────────────┘
                     │ OVERRIDE!
                     ↓
                Priority 2️⃣
                     ↓
            ┌─────────────────────────┐
            │ docker-compose          │
            │ env_file:               │
            │ ./env/.env.siimut       │
            │ (contains all           │
            │  config vars)           │
            └────────┬────────────────┘
                     │ OVERRIDE!
                     ↓
                Priority 3️⃣ (Lowest)
                     ↓
            ┌─────────────────────────┐
            │ Container working dir   │
            │ site/siimut/.env        │
            │ (loaded by Laravel)     │
            └─────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Example: What does Laravel "see"?                          │
├─────────────────────────────────────────────────────────────┤
│  env('USE_SSO')  → $_ENV['USE_SSO']                         │
│                                                              │
│  Search order:                                              │
│  1. REQUEST $_ENV (from docker-compose environment:) ... ✓  │
│  2. load .env file (from site/siimut/.env) ................ │
│  3. default value (if env not found) ...................... │
│                                                              │
│  Result: Docker env vars WIN over .env files!              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. CURRENT STATE vs RECOMMENDED STATE

```
┌────────────────────────────────────────────────────────────────────────┐
│                       CURRENT STATE (PROBLEMATIC)                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  env/.env.siimut:                                                      │
│  ├─ Line 34: APP_ENV=production        (BUILD context)                 │
│  ├─ Line 40: APP_ENV=local             (Laravel app)  ⚠️ CONFUSING!   │
│  ├─ Line 66: USE_SSO=false             (for dev)                       │
│  ├─ Line 67: IAM_ENABLED=false                                         │
│  └─ ... other configs                                                  │
│                                                                          │
│  docker-compose-multi-apps.yml:                                        │
│  ├─ env_file: ./env/.env.siimut        (priority 2)                    │
│  └─ environment: APP_ENV: production   (priority 1) ⚠️ OVERRIDE!       │
│                                                                          │
│  site/siimut/.env:                                                     │
│  ├─ USE_SSO=false                      (from .env.example)             │
│  ├─ APP_ENV=local                                                      │
│  └─ ... other configs (may differ from .env.siimut)                    │
│                                                                          │
│  Result:                                                               │
│  ✗ 3 different .env files with different values                        │
│  ✗ Double APP_ENV assignment = confusing                               │
│  ✗ docker-compose environment OVERRIDE not obvious                     │
│  ✗ Not clear which file is "master"                                    │
│                                                                          │
└────────────────────────────────────────────────────────────────────────┘

                            PROBLEM!
                              ↓↓↓

         When developer changes env/.env.siimut,
         site/siimut/.env may NOT reflect changes!
         (because it was copied from .env.example, not synced)

                            SOLUTION!
                              ↓↓↓

┌────────────────────────────────────────────────────────────────────────┐
│                    RECOMMENDED STATE (OPSI A)                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  NEW: env/.env.dev.siimut                                              │
│  ├─ APP_ENV=local                      (single, no double!)            │
│  ├─ APP_DEBUG=true                                                     │
│  ├─ LOG_LEVEL=debug                                                    │
│  ├─ CACHE_DRIVER=database                                              │
│  ├─ USE_SSO=false                      (development)                   │
│  └─ ... other dev-specific configs                                     │
│                                                                          │
│  KEEP: env/.env.siimut (for production)                                │
│  ├─ APP_ENV=production                 (production only)               │
│  ├─ APP_DEBUG=false                                                    │
│  ├─ LOG_LEVEL=warning                                                  │
│  ├─ CACHE_DRIVER=file                                                  │
│  ├─ USE_SSO=true                       (production)                    │
│  └─ ... other prod-specific configs                                    │
│                                                                          │
│  UPDATE: docker-compose-multi-apps.yml                                 │
│  ├─ env_file: ./env/.env.dev.siimut    (for development)               │
│  └─ environment: (remove APP_ENV override!)                            │
│                                                                          │
│  site/siimut/.env:                                                     │
│  ├─ Automatically synced by switch-auth-mode.sh                        │
│  └─ Matches docker env vars (via entrypoint)                           │
│                                                                          │
│  Result:                                                               │
│  ✓ One .env per mode (dev/prod) → CLEAR!                              │
│  ✓ No double assignments                                              │
│  ✓ No conflicting values                                              │
│  ✓ Easy to switch: change env_file path in compose                    │
│  ✓ Master file is explicit (.env.dev.siimut)                          │
│                                                                          │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. .ENV FILES SYNC FLOW

```
┌──────────────────────────────────────────────────────────────────┐
│           MASTER: env/.env.dev.siimut (HOST)                     │
│  This is the SOURCE OF TRUTH                                     │
│  ├─ USE_SSO=false                                               │
│  ├─ APP_ENV=local                                               │
│  └─ ... all dev settings                                        │
└─────────────────────┬──────────────────────────────────────────┘
                      │
                      │ 1. docker-compose reads
                      ↓            
        ┌──────────────────────────────┐
        │  Docker Container            │
        │  $_ENV = env/.env.dev.siimut │
        │  (set by docker-compose)     │
        └──────────┬───────────────────┘
                   │
                   │ 2. entrypoint-registry.sh runs
                   │    switch-auth-mode.sh dev
                   ↓
        ┌──────────────────────────────────────────┐
        │  site/siimut/.env (HOST, volume mount)   │
        │  Updated by: switch-auth-mode.sh         │
        │  ├─ USE_SSO=false (synced)               │
        │  ├─ APP_ENV=local (synced)               │
        │  └─ ... other values synced              │
        └──────────┬───────────────────────────────┘
                   │
                   │ 3. Laravel (inside container)
                   │    reads .env file
                   ↓
        ┌──────────────────────────────┐
        │  config('iam.enabled')       │ ← reads from .env
        │  env('USE_SSO', false)       │ ← reads from .env
        │  env('APP_ENV')              │ ← reads from $_ENV
        └──────────────────────────────┘
                   │
                   ↓
        ┌──────────────────────────────┐
        │  Routes Registered:          │
        │  ✓ /login (custom)           │
        │  ✓ /siimut/login (filament)  │
        │  ✗ /sso/login (not shown)    │
        └──────────────────────────────┘

Result: CONSISTENT across host & container!
```

---

## 5. DECISION TREE: Which .env to edit?

```
┌────────────────────────────────────┐
│  Want to make a configuration       │
│  change for development?             │
└────────────┬───────────────────────┘
             │
             ├─ "I'll be manual testing"
             │  └─► Edit: env/.env.dev.siimut ✓
             │         + site/siimut/.env (via switch-auth-mode.sh)
             │
             ├─ "CI/CD will run this"
             │  └─► Edit: env/.env.dev.siimut ✓
             │
             ├─ "I want quick iteration"
             │  └─► Edit: site/siimut/.env ✓
             │      + Commit env/.env.dev.siimut later
             │
             └─ "Need to switch dev/prod"
                └─► Change docker-compose env_file:
                        ./env/.env.dev.siimut (dev)
                        ./env/.env.siimut (prod)

GOLDEN RULE:
  env/.env.dev.siimut    ← Master for Docker/CI/CD
  site/siimut/.env       ← Auto-synced by entrypoint
                           (don't manually edit if possible)
```

---

## 6. CURRENT vs RECOMMENDED COMMAND FLOW

```
CURRENT FLOW (Problematic):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  $ ./prepare-siimut.sh
  └─ Clones site/siimut/
  └─ Copies .env.example → site/siimut/.env ⚠️ (not from .env.siimut!)

  $ docker compose build
  └─ ARG APP_ENV=production
  └─ Copies site/siimut/ to image (at this point, .env may differ!)

  $ docker compose up
  └─ env_file: ./env/.env.siimut (set $_ENV with USE_SSO=false)
  └─ environment: APP_ENV=production ⚠️ (OVERRIDE!)
  └─ entrypoint runs switch-auth-mode.sh dev
  └─ Updates site/siimut/.env (works, but inconsistency already happened)

  Result: ✗ Multiple sources of truth, easy to get confused


RECOMMENDED FLOW (Opsi A):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  $ ./prepare-siimut.sh
  └─ Clones site/siimut/
  └─ Copies .env.example → site/siimut/.env (still needed)

  $ docker compose build
  └─ ARG APP_DIR=siimut
  └─ Copies site/siimut/ to image (as-is)

  $ docker compose up
  └─ env_file: ./env/.env.dev.siimut ✓ (MASTER - clear, single source)
      (set $_ENV with: APP_ENV=local, USE_SSO=false, LOG_LEVEL=debug)
  └─ environment: (empty if not needed) ✓
  └─ entrypoint runs switch-auth-mode.sh dev
  └─ Updates site/siimut/.env to match .env.dev.siimut ✓

  Result: ✓ Single master file, consistent everywhere, transparent
```

---

## 📝 Quick Cheat Sheet

```
For DEVELOPMENT (No SSO):

  MASTER FILE:  env/.env.dev.siimut
  ├─ APP_ENV=local
  ├─ USE_SSO=false
  ├─ APP_DEBUG=true
  └─ LOG_LEVEL=debug

  To switch mode:
  $ cd site/siimut && ./switch-auth-mode.sh dev
  
  To check:
  $ php artisan route:list | grep login
  Output: /login, /siimut/login (NO /sso/login) ✓


For PRODUCTION (With SSO):

  MASTER FILE:  env/.env.siimut
  ├─ APP_ENV=production
  ├─ USE_SSO=true
  ├─ APP_DEBUG=false
  └─ LOG_LEVEL=warning

  To switch mode:
  $ cd site/siimut && ./switch-auth-mode.sh prod
  
  To check:
  $ php artisan route:list | grep login
  Output: /sso/login (ONLY SSO route) ✓
```
