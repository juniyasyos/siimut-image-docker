#!/bin/bash

# Script untuk memeriksa apakah JWT secrets sama di semua service
# Services: app-siimut, app-ikp, app-iam

echo "=== JWT SECRET VERIFICATION ==="
echo ""

# Function untuk mendapatkan JWT secret dari container
get_jwt_secret() {
    local service=$1
    docker exec $service sh -c 'echo $IAM_JWT_SECRET' 2>/dev/null
}

# Function untuk mendapatkan nilai dari env file jika container tidak running
get_jwt_from_env() {
    local env_file=$1
    grep "^IAM_JWT_SECRET=" "$env_file" | cut -d'=' -f2
}

# Array untuk menyimpan hasil
declare -A secrets
declare -a services=("app-siimut" "app-ikp" "app-iam")

# Check setiap service
for service in "${services[@]}"; do
    echo "Checking $service..."
    
    # Coba ambil dari container yang running
    secret=$(get_jwt_secret "$service")
    
    # Jika container tidak running atau env kosong, ambil dari env file
    if [ -z "$secret" ]; then
        env_file="/home/juni/projects/apps/docker/rsch-apps/env/.env.${service#app-}"
        if [ -f "$env_file" ]; then
            secret=$(get_jwt_from_env "$env_file")
            echo "  (dari file: $env_file)"
        else
            secret="NOT_FOUND"
            echo "  ❌ File tidak ditemukan: $env_file"
        fi
    else
        echo "  (dari container)"
    fi
    
    secrets[$service]="$secret"
    echo "  Value: ${secret:0:20}... (truncated)"
    echo ""
done

# Verifikasi kesamaan
echo "=== VERIFICATION RESULT ==="
echo ""

all_same=true
first_secret="${secrets[app-siimut]}"

for service in "${services[@]}"; do
    if [ "${secrets[$service]}" != "$first_secret" ]; then
        all_same=false
        break
    fi
done

if [ "$all_same" = true ] && [ "$first_secret" != "NOT_FOUND" ]; then
    echo "✅ BAGUS! Semua JWT secrets SAMA di ketiga service"
    echo ""
    echo "Details:"
    for service in "${services[@]}"; do
        echo "  $service: ${secrets[$service]}"
    done
else
    echo "❌ BERMASALAH! JWT secrets TIDAK SAMA atau tidak ditemukan"
    echo ""
    echo "Details:"
    for service in "${services[@]}"; do
        echo "  $service: ${secrets[$service]}"
    done
fi

echo ""
echo "=== END OF VERIFICATION ==="
