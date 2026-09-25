#!/bin/bash

set -e

# db:seed can't prompt for the first admin user inside the container,
# so fail fast with a clear message if .env doesn't provide one.
missing=""
for key in ADMIN_NAME ADMIN_EMAIL ADMIN_PASSWORD; do
  if ! grep -qE "^${key}=.+" .env 2>/dev/null; then
    missing="$missing $key"
  fi
done
if [ -n "$missing" ]; then
  echo "ERROR: Missing values in .env:$missing" >&2
  echo "Set them (see .env.docker.example), then run: docker compose up -d" >&2
  exit 1
fi

echo "Waiting for the database..."
until nc -z db 3306; do
  sleep 1
done
echo "Database is up."

composer install --no-interaction
npm install

php artisan key:generate
php artisan migrate --force
php artisan db:seed --force
php artisan storage:link
composer dump-autoload

exec npm run dev