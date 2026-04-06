#!/bin/bash
# Diagnostic script untuk error Debugbar ServiceProvider

echo "=== Checking Debugbar Installation ==="
echo ""

echo "1. Checking composer.json for debugbar package..."
grep -i "barryvdh/laravel-debugbar" composer.json || echo "❌ Debugbar not in composer.json"
echo ""

echo "2. Checking if vendor directory exists..."
if [ -d "vendor" ]; then
    echo "✓ Vendor directory found"
    if [ -d "vendor/barryvdh/laravel-debugbar" ]; then
        echo "✓ Barryvdh Debugbar package exists"
        ls -la vendor/barryvdh/laravel-debugbar/src/ | head -10
    else
        echo "❌ Barryvdh Debugbar package NOT found"
    fi
else
    echo "❌ Vendor directory NOT found"
fi
echo ""

echo "3. Checking if composer autoload.php exists..."
[ -f "vendor/autoload.php" ] && echo "✓ Autoload file exists" || echo "❌ Autoload file missing"
echo ""

echo "4. Checking config/app.php for ServiceProvider registration..."
grep -n "Barryvdh" config/app.php || echo "⚠️  Barryvdh not found in config/app.php"
echo ""

echo "5. Checking if .env APP_DEBUG is set..."
grep "APP_DEBUG" .env || echo "⚠️  APP_DEBUG not set in .env"
echo ""

echo "6. Running composer dump-autoload..."
composer dump-autoload -q && echo "✓ Autoload dumped successfully" || echo "❌ Composer dump-autoload failed"
echo ""

echo "7. Checking for PHP syntax errors..."
php -lint Application.php 2>&1 | head -20
