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

# Only generate a key if .env doesn't have one; regenerating logs everyone out
grep -qE '^APP_KEY=.+' .env || php artisan key:generate
php artisan migrate --force

# Seed only on first-time setup; re-seeding would duplicate the admin user and other data
user_count=$(php artisan tinker --execute="echo \Illuminate\Support\Facades\DB::table('users')->count();")
if [ "$user_count" = "0" ]; then
  php artisan db:seed --force
else
  echo "Database already seeded, skipping db:seed."
fi

# Only create the storage symlink if it doesn't already exist
[ -L public/storage ] || php artisan storage:link
composer dump-autoload

npm run dev

# Hand off to the container's command (CMD in the Dockerfile, apache2-foreground by default)
exec "$@"