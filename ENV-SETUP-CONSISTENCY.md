# 🔄 Project Environment Setup - Consistency Check

## Overview
Ketiga project (SIIMUT, IAM, IKP) kini mengikuti **pattern yang sama**:

✅ Masing-masing punya env file: `env/.env.<project>`  
✅ `prepare-<project>.sh` load dari env file  
✅ Database credentials konsisten di `docker-compose.base.yml`

---

## 📋 Project Environment Files

### 1️⃣  SIIMUT Project
```
File: env/.env.siimut
Loaded by: prepare-siimut.sh
Branch: feat-daily-report
Database: siimut_db
User: siimut_user
Password: siimut-password
Port: 8080
```

### 2️⃣  IAM Project  
```
File: env/.env.iam
Loaded by: prepare-iam.sh
Branch: dev
Database: iam_db
User: iam_user
Password: iam-password
Port: 8100
```

### 3️⃣  IKP Project
```
File: env/.env.ikp  ✅ NEWLY CREATED
Loaded by: prepare-ikp.sh  ✅ UPDATED
Branch: main
Database: ikp_db
User: ikp_user
Password: ikp-password
Port: 8082
```

---

## 🗄️ Database Consistency

Semua project menggunakan credentials dari `env/.env.db`:

```bash
# Root Access
MYSQL_ROOT_PASSWORD=rootpass123

# Read/Write Users (dibuat di DockerNew/db/sql/00-init-multi-db.sql)
siimut_user / siimut-password      → siimut_db
iam_user / iam-password            → iam_db
ikp_user / ikp-password            → ikp_db

# Read-Only Users (Optional)
siimut_readonly / Siimut@ReadOnly2025!
iam_readonly / Iam@ReadOnly2025!
ikp_readonly / ikp@ReadOnly2025!
```

---

## 🔧 How It Works

### prepare-siimut.sh & prepare-iam.sh & prepare-ikp.sh

**Pattern yang sama:**

```bash
# 1. Load env file if exists
if [ -f "env/.env.<project>" ]; then
    source <(grep -E '^(APP_DIR|REPO_URL|BRANCH|DB_*)=' env/.env.<project>)
fi

# 2. Use loaded values or defaults
APP_DIR="${APP_DIR:-<default>}"
REPO_URL="${REPO_URL:-<default_url>}"
BRANCH="${BRANCH:-<default_branch>}"

# 3. Use variables consistently throughout script
```

Keuntungan:
- ✅ Centralized configuration
- ✅ Easy to override via env file
- ✅ Fallback to defaults if file missing
- ✅ Easy to manage multiple deployments

---

## ✅ Quick Start

### Setup SIIMUT
```bash
# env/.env.siimut already exists
bash prepare-siimut.sh
```

### Setup IAM
```bash
# env/.env.iam already exists
bash prepare-iam.sh
```

### Setup IKP
```bash
# env/.env.ikp newly created ✅
bash prepare-ikp.sh
```

---

## 📝 Configuration Files

| File | Purpose | Status |
|------|---------|--------|
| `env/.env.db` | Database credentials | ✅ Existing |
| `env/.env.siimut` | SIIMUT project config | ✅ Existing |
| `env/.env.iam` | IAM project config | ✅ Existing |
| `env/.env.ikp` | IKP project config | ✅ **NEW** |
| `docker-compose.base.yml` | Database & shared services | ✅ Existing |
| `DockerNew/db/sql/00-init-multi-db.sql` | DB initialization | ✅ Existing |

---

## 🎯 Database Initialization

Saat container pertama kali start:

1. **MySQL Root** dibuat dengan password: `rootpass123`
2. **SQL Script** otomatis jalankan: `DockerNew/db/sql/00-init-multi-db.sql`
3. Membuat 3 databases:
   - `siimut_db` + user `siimut_user`
   - `iam_db` + user `iam_user`
   - `ikp_db` + user `ikp_user`
4. Optional read-only users juga dibuat

---

## 🔐 Environment Variable Hierarchy

Untuk setiap project:

```
1. Hardcoded defaults (paling rendah)
2. ↓ override by
3. env/.env.<project> values (paling tingah)
```

Example untuk IKP:
```bash
# Default (jika env/.env.ikp tidak ada)
APP_DIR="ikp"
REPO_URL="https://github.com/juniyasyos/ikp.git"
BRANCH="main"

# Dari env/.env.ikp (override defaults)
APP_DIR="ikp"                                    # sama
REPO_URL="https://github.com/juniyasyos/ikp.git" # sama
BRANCH="main"                                    # sama
DB_DATABASE="ikp_db"                             # tambahan
DB_USER="ikp_user"                               # tambahan
```

---

## 📚 Related Files

- [DATABASE-CREDENTIALS.md](./DATABASE-CREDENTIALS.md) - Complete credentials reference
- [test-database.sh](./test-database.sh) - Test DB connections
- [debug-root-password.sh](./debug-root-password.sh) - Debug root issues
- [DockerNew/db/sql/00-init-multi-db.sql](./DockerNew/db/sql/00-init-multi-db.sql) - Database initialization

---

## ✨ Summary

| Aspek | Status |
|-------|--------|
| SIIMUT Environment | ✅ Configured |
| IAM Environment | ✅ Configured |
| IKP Environment | ✅ **NOW CONFIGURED** |
| Database Consistency | ✅ All aligned |
| prepare-*.sh Pattern | ✅ All unified |
| Credentials Reference | ✅ Available |
