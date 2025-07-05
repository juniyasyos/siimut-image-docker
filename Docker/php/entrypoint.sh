#!/bin/sh
set -e

echo "Fixing Laravel permissions..."
if [ -d /var/www/storage ]; then
  chown -R www-data:www-data /var/www/storage
  chmod -R 775 /var/www/storage
fi

if [ -d /var/www/bootstrap/cache ]; then
  chown -R www-data:www-data /var/www/bootstrap/cache
  chmod -R 775 /var/www/bootstrap/cache
fi

mkdir -p /sessions
chmod 777 /sessions

echo "Starting PHP..."
exec "$@"
