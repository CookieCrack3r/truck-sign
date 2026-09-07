#!/usr/bin/env bash
# Container entrypoint for the Truck Signs API.
#
# Waits for PostgreSQL, applies migrations, collects static files, makes sure
# the admin account exists and finally hands control to gunicorn - a WSGI
# server, never the Django development server.
set -eu

# Connection details. Defaults match the service names in docker-compose.yml;
# credentials have no defaults on purpose and must be supplied via the .env.
export DB_HOST="${DB_HOST:-db}"
export DB_PORT="${DB_PORT:-5432}"
: "${DB_NAME:?DB_NAME must be set (see example.env)}"
: "${DB_USER:?DB_USER must be set (see example.env)}"
: "${DB_PASSWORD:?DB_PASSWORD must be set (see example.env)}"

GUNICORN_BIND="${GUNICORN_BIND:-0.0.0.0:8000}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-4}"
DB_WAIT_RETRIES="${DB_WAIT_RETRIES:-30}"
DB_WAIT_INTERVAL="${DB_WAIT_INTERVAL:-2}"

echo "[entrypoint] waiting for postgres at ${DB_HOST}:${DB_PORT} ..."

# psycopg2 is installed anyway, so probe with a real connection attempt instead
# of a plain port check: postgres opens the port while it is still initialising
# and only accepts logins once the database is actually ready.
ATTEMPT=0
until python -c '
import os, psycopg2
psycopg2.connect(
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    host=os.environ["DB_HOST"],
    port=os.environ["DB_PORT"],
)
' 2>/dev/null; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ "${ATTEMPT}" -ge "${DB_WAIT_RETRIES}" ]; then
        echo "[entrypoint] postgres unreachable after ${DB_WAIT_RETRIES} attempts - giving up." >&2
        exit 1
    fi
    echo "[entrypoint] postgres is unavailable - retrying in ${DB_WAIT_INTERVAL}s (${ATTEMPT}/${DB_WAIT_RETRIES}) ..."
    sleep "${DB_WAIT_INTERVAL}"
done

echo "[entrypoint] postgres is active"

echo "[entrypoint] applying migrations ..."
python manage.py migrate --noinput

echo "[entrypoint] collecting static files ..."
python manage.py collectstatic --noinput

# Create the admin account only when credentials are supplied, and only when it
# does not exist yet. An explicit existence check is used rather than
# `createsuperuser || true`, which would also swallow real database errors.
if [ -n "${DJANGO_SUPERUSER_USERNAME:-}" ] && [ -n "${DJANGO_SUPERUSER_PASSWORD:-}" ]; then
    echo "[entrypoint] ensuring superuser '${DJANGO_SUPERUSER_USERNAME}' exists ..."
    python manage.py shell -c '
import os
from django.contrib.auth import get_user_model

User = get_user_model()
username = os.environ["DJANGO_SUPERUSER_USERNAME"]

if User.objects.filter(username=username).exists():
    print("[entrypoint] superuser already exists - skipping creation")
else:
    User.objects.create_superuser(
        username=username,
        email=os.environ.get("DJANGO_SUPERUSER_EMAIL", ""),
        password=os.environ["DJANGO_SUPERUSER_PASSWORD"],
    )
    print("[entrypoint] superuser created")
'
else
    echo "[entrypoint] DJANGO_SUPERUSER_* not set - skipping superuser creation"
fi

# `exec` replaces this shell with gunicorn so it becomes PID 1 and receives
# Docker's stop signals directly, which allows a graceful shutdown.
echo "[entrypoint] starting gunicorn on ${GUNICORN_BIND} ..."
exec gunicorn tsa_app.wsgi:application \
    --bind "${GUNICORN_BIND}" \
    --workers "${GUNICORN_WORKERS}" \
    --access-logfile - \
    --error-logfile -
