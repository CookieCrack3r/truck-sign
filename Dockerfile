# syntax=docker/dockerfile:1

# Truck Signs API - container image for the Django backend.
#
# Build:  docker build -t truck-signs-api:local .
# Run:    see README.md - the image expects a PostgreSQL service and an .env

FROM python:3.12-slim

# PYTHONUNBUFFERED        - stdout/stderr reach `docker logs` immediately.
# PYTHONDONTWRITEBYTECODE - no .pyc files inside the image.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Dependencies first: this layer is only rebuilt when requirements.txt changes.
# psycopg2-binary ships prebuilt wheels, so no compiler or libpq-dev is needed.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app

# Runtime preparation, kept in a single layer:
#  - the executable bit does not survive a Windows checkout reliably, so set it
#    explicitly instead of relying on the copied file mode
#  - STATIC_ROOT and MEDIA_ROOT must exist and be owned by the runtime user
#    before the named volumes are mounted: Docker takes the directory owner
#    from the image when it initialises an empty volume
#  - the application runs unprivileged, never as root
RUN chmod +x /app/entrypoint.sh \
    && mkdir -p /app/src/staticfiles /app/src/mediafiles \
    && useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app

# Numeric UID so it stays resolvable regardless of the host's user database.
USER 10001

# The Django project lives in src/: manage.py and the tsa_app.wsgi module
# resolve relative to this directory at runtime.
WORKDIR /app/src

# Gunicorn listens on this port inside the container. The publicly reachable
# port is mapped in docker-compose.yml (8020 by default).
EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
