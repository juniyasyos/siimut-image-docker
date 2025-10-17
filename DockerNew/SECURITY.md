# 🔒 Security & Data Protection Guide

## ⚠️ **PERINGATAN KEAMANAN**

Folder `DockerNew/` berisi data sensitif production yang **TIDAK BOLEH** di-commit ke git repository!

## 🚫 **Data yang TIDAK BOLEH di-commit:**

### 1. **Database Data (SANGAT SENSITIF)**
```
DockerNew/db/data/          # Data user, password, informasi pribadi
DockerNew/db/logs/          # Query logs yang bisa contain sensitive data
DockerNew/db/sql/*.sql      # Database dumps dengan data real
```

### 2. **Session & Cache Data (SENSITIF)**
```
DockerNew/redis/data/       # Session data, cache dengan info user
DockerNew/phpmyadmin/sessions/  # Session phpMyAdmin
```

### 3. **Logs (BERPOTENSI SENSITIF)**
```
DockerNew/caddy/logs/       # Access logs dengan IP dan request
DockerNew/php/logs/         # Error logs yang mungkin expose info
DockerNew/logs/             # Semua application logs
```

### 4. **Certificates & Keys (SANGAT SENSITIF)**
```
DockerNew/caddy/*.key       # Private keys SSL
DockerNew/caddy/*.crt       # SSL certificates
DockerNew/caddy/*.pem       # Certificate files
```

### 5. **Backup Files (SANGAT SENSITIF)**
```
DockerNew/**/*.backup       # Backup database/config
DockerNew/**/*.dump         # Database dumps
DockerNew/**/*.sql.gz       # Compressed backups
```

## ✅ **Data yang BOLEH di-commit:**

### 1. **Configuration Templates**
```
DockerNew/caddy/Caddyfile           # Web server config template
DockerNew/php/php.ini               # PHP configuration
DockerNew/db/my.cnf                 # Database configuration
DockerNew/php/Dockerfile.production # Docker build instructions
```

### 2. **Scripts & Documentation**
```
DockerNew/php/entrypoint-production.sh  # Startup scripts
DockerNew/README-*.md                    # Documentation
DockerNew/.gitignore                     # Security rules
```

### 3. **Placeholder Files**
```
DockerNew/**/.gitkeep               # Directory structure placeholders
```

## 🛡️ **Perlindungan yang Sudah Diterapkan**

### 1. **`.gitignore` Root Level**
File `.gitignore` utama melindungi:
- Semua data sensitif di `DockerNew/`
- Environment files (`.env.production`)
- Certificate files
- Log files
- Backup files

### 2. **`.gitignore` di DockerNew**
File `DockerNew/.gitignore` memberikan perlindungan tambahan khusus untuk folder production.

### 3. **Placeholder Files**
File `.gitkeep` memastikan struktur direktori tetap terjaga tanpa commit data sensitif.

## 📋 **Checklist Keamanan Sebelum Git Push**

```bash
# 1. Pastikan tidak ada data sensitif yang akan di-commit
git status

# 2. Periksa file yang akan di-add
git diff --cached

# 3. Pastikan file .env.production tidak ter-track
git ls-files | grep -E "\.env\.production|\.env\.local"

# 4. Periksa tidak ada file backup atau dump
git ls-files | grep -E "\.(backup|dump|sql)$"

# 5. Periksa tidak ada private keys
git ls-files | grep -E "\.(key|pem)$"
```

## 🚨 **Jika Data Sensitif Ter-commit (Emergency Response)**

### 1. **Jika Belum Push:**
```bash
# Reset commit terakhir
git reset --soft HEAD~1

# Atau hapus file dari staging
git reset HEAD path/to/sensitive/file
```

### 2. **Jika Sudah Push:**
```bash
# DANGER: Ini akan mengubah history!
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/sensitive/file' \
  --prune-empty --tag-name-filter cat -- --all

# Force push (koordinasi dengan tim!)
git push --force-with-lease
```

### 3. **Best Practice:**
- Segera ganti password/keys yang ter-expose
- Inform tim development
- Review security procedures

## 🔍 **Monitoring & Audit**

### 1. **Regular Security Check**
```bash
# Cek file yang ter-track di DockerNew
git ls-files | grep "^DockerNew/"

# Pastikan hanya config files yang ter-track
git ls-files DockerNew/ | grep -v -E "\.(ini|cnf|conf|php|sh|md|gitignore|gitkeep|Dockerfile)$"
```

### 2. **Pre-commit Hook (Recommended)**
Buat file `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Prevent sensitive files from being committed

sensitive_files=$(git diff --cached --name-only | grep -E "\.(sql|dump|backup|key|pem|log)$|DockerNew/.*/data/")

if [ ! -z "$sensitive_files" ]; then
    echo "🚫 COMMIT BLOCKED: Sensitive files detected!"
    echo "$sensitive_files"
    echo "Remove these files from staging before committing."
    exit 1
fi
```

## 📞 **Tim Responsibility**

### **Developer:**
- Selalu check `git status` sebelum commit
- Tidak pernah commit file di folder `data/`, `logs/`, `sessions/`
- Report jika menemukan data sensitif ter-commit

### **DevOps:**
- Monitor repository untuk data sensitif
- Setup automated security scanning
- Maintain `.gitignore` rules

### **Security:**
- Regular audit git history
- Review access logs
- Incident response untuk data leaks

---

**💡 INGAT:** Sekali data sensitif ter-push ke git, sangat sulit untuk benar-benar menghapusnya dari history. Pencegahan selalu lebih baik daripada recovery!