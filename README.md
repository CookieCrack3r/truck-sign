<div align="center">

# Signs for Trucks

![Python version](https://img.shields.io/badge/Python-3.12-4c566a?logo=python&&longCache=true&logoColor=white&colorB=pink&style=flat-square&colorA=4c566a) ![Django version](https://img.shields.io/badge/Django-5.2.8-4c566a?logo=django&&longCache=truelogoColor=white&colorB=pink&style=flat-square&colorA=4c566a) ![Django-RestFramework](https://img.shields.io/badge/Django_Rest_Framework-3.16.1-red.svg?longCache=true&style=flat-square&logo=django&logoColor=white&colorA=4c566a&colorB=pink) ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4c566a?logo=postgresql&longCache=true&logoColor=white&colorB=pink&style=flat-square&colorA=4c566a)

![Truck Signs](./src/screenshots/Truck_Signs_logo.png)

__Signs for Trucks__ is an online store to buy pre-designed vinyls with custom lines of letters (often called truck letterings).
The store also allows clients to upload their own designs and to customize them on the website.

</div>

## Table of Contents

- [About This Repository](#about-this-repository)
  - [What This Repository Contains](#what-this-repository-contains)
  - [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
  - [How to Build the Image](#how-to-build-the-image)
- [Usage](#usage)
  - [Configuration Reference](#configuration-reference)
  - [Building a Container Image](#building-a-container-image)
  - [Running with Docker Compose](#running-with-docker-compose)
  - [Running with docker run](#running-with-docker-run)
  - [Changing the Published Port](#changing-the-published-port)
  - [The Superuser Account](#the-superuser-account)
  - [Data Persistence and Volumes](#data-persistence-and-volumes)
  - [Switching Between PostgreSQL and SQLite](#switching-between-postgresql-and-sqlite)
  - [Media Storage: Local or Cloudinary](#media-storage-local-or-cloudinary)
  - [Local Development Without Docker](#local-development-without-docker)
  - [Troubleshooting](#troubleshooting)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Build Application](#build-application)
  - [Lint and Test Python Code Base](#lint-and-test-python-code-base)
  - [Check Open PR](#check-open-pr)
  - [Required Repository Settings](#required-repository-settings)
- [Application Reference](#application-reference)
  - [Models](#models)
  - [Brief Explanation of the Views](#brief-explanation-of-the-views)
  - [API Endpoints](#api-endpoints)
- [Screenshots of the Django Backend Admin Panel](#screenshots-of-the-django-backend-admin-panel)
  - [Mobile View](#mobile-view)
  - [Desktop View](#desktop-view)
- [Additional Information](#additional-information)

## About This Repository

This repository holds the **Truck Signs API**, the Django/Django REST Framework backend of the
_Signs for Trucks_ online store, together with everything needed to run it as a container.

The purpose of the repository is twofold:

1. **The application.** A Django project (`src/`) that exposes a REST API for vinyl products,
   categories, letterings, colors and orders, plus the Django admin panel used to manage them.
2. **The deployment.** A container image definition and a Docker Compose stack that run the
   application together with a PostgreSQL database, so the API can be deployed to any host with
   Docker installed without setting up Python, a virtualenv or a database by hand.

The container image is built by GitHub Actions and published to the GitHub Container Registry
(GHCR). The Compose stack **pulls** that image; nothing is built on the deployment host.

### What This Repository Contains

| Path | Description |
| --- | --- |
| `Dockerfile` | Builds the backend container image: Python 3.12 slim base, Python dependencies, an unprivileged runtime user, and `entrypoint.sh` as the entrypoint. |
| `docker-compose.yml` | The application stack: the `backend` service (pulled from GHCR) and the `db` service (PostgreSQL), a shared bridge network, and named volumes for database, static and media files. |
| `entrypoint.sh` | Container startup script: waits for PostgreSQL, applies migrations, collects static files, creates the admin account if it does not exist, and starts Gunicorn. |
| `example.env` | Template for the `.env` file. Contains every supported variable with placeholder values. Copy it; never commit the real `.env`. |
| `requirements.txt` | Pinned Python dependencies, installed by `pip` during the image build. |
| `pyproject.toml` | Configuration for the `black`, `isort` and `flake8` tooling (line length 120, `black` profile for `isort`). |
| `Procfile` | Legacy process definition (`web: gunicorn tsa_app.wsgi`) for Heroku-style platforms. Not used by the container setup; the entrypoint starts Gunicorn instead. |
| `.dockerignore` | Keeps git metadata, local notes, docs and the `.env` out of the build context and therefore out of the image. |
| `.gitattributes` | Forces LF line endings for shell scripts and configuration files. A CRLF shebang makes Linux look for a program literally named `bash\r`, which breaks the container on Windows checkouts. |
| `.gitignore` | Standard Python/Django ignore rules, including `.env`. |
| `.github/workflows/` | The CI/CD pipelines. See [CI/CD Pipeline](#cicd-pipeline). |
| `docs/testing.md` | Description of the quality assurance setup: linters, formatters and the Django test suite. |
| `src/` | The Django project: `src/manage.py`, the `tsa_app` project package (settings, URLs, WSGI) and the `tsa_products` application (models, serializers, views, tests, migrations). |
| `src/screenshots/` | Images used by this README. |

### Architecture

```
                      host port 8020
                             |
              +--------------v----------------+
              |  backend  (tsa_backend)       |
              |  Gunicorn -> Django, port 8000|
              +--------------+----------------+
                             |  tsa-network (bridge)
              +--------------v----------------+
              |  db  (tsa_db)                 |
              |  PostgreSQL 17, port 5432     |
              |  no host port published       |
              +-------------------------------+

  volumes:  postgres_data   static_files   media_files
```

Only the backend publishes a port. The database is reachable exclusively from inside the Compose
network under the hostname `db`, resolved by Docker's embedded DNS.

## Prerequisites

* [Docker Engine](https://docs.docker.com/engine/install/) 20.10 or newer, including the
  Compose v2 plugin (`docker compose`, not the legacy `docker-compose`)
* [Git](https://git-scm.com/downloads)

Only needed for [local development without Docker](#local-development-without-docker):

* [Python 3.12](https://www.python.org/downloads/)
* A local PostgreSQL server (optional - the application falls back to SQLite)

## Quickstart

1. **Clone the repository**

   ```bash
   git clone https://github.com/CookieCrack3r/truck-sign.git
   cd truck-sign
   ```

2. **Create the environment file**

   ```bash
   cp example.env .env
   ```

   Open `.env` and replace every `<placeholder>`. The minimum required values are `SECRET_KEY`
   and `DB_PASSWORD` - Compose refuses to start without them. Generate a secret key with:

   ```bash
   python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
   ```

3. **Start the stack**

   ```bash
   docker compose up -d
   ```

4. **Check that it came up**

   ```bash
   docker compose ps
   docker compose logs -f backend
   ```

   The log ends with `[entrypoint] starting gunicorn on 0.0.0.0:8000 ...`.

5. **Open the application**

   | URL | What |
   | --- | --- |
   | `http://<your-host>:8020/` | Landing page |
   | `http://<your-host>:8020/admin/` | Django admin panel |
   | `http://<your-host>:8020/truck-signs/products/` | Product API |

   Log in to the admin panel with the `DJANGO_SUPERUSER_*` credentials from your `.env`.

6. **Stop the stack**

   ```bash
   docker compose down          # keeps all data
   docker compose down -v       # also deletes the volumes, including the database
   ```

### How to Build the Image

The Compose stack pulls a prebuilt image, so building is only necessary when you change the
application or the `Dockerfile`. To build it locally:

```bash
docker build -t truck-sign:local .
```

To build it under the name the Compose file expects, so that `docker compose up` uses your local
build instead of pulling from GHCR:

```bash
docker build -t ghcr.io/cookiecrack3r/truck-sign:main .
```

A detailed description of the build, tagging and publishing is in
[Building a Container Image](#building-a-container-image).

## Usage

### Configuration Reference

All configuration is supplied through environment variables. In the Compose setup they are read
from the `.env` file in the project root; `docker-compose.yml` passes them into the containers.
Nothing sensitive is stored in the repository.

Two forms are used in `docker-compose.yml`:

* `${VARIABLE:-default}` - optional, falls back to the default shown below.
* `${VARIABLE:?message}` - **required**. Compose aborts with that message if the variable is
  missing, instead of silently starting with an insecure default.

**Application**

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `SECRET_KEY` | **yes** | - | Django signing key. Never reuse the value from another deployment. |
| `MODE` | no | `prod` | `prod` selects PostgreSQL. Any other value selects SQLite - see [Switching Between PostgreSQL and SQLite](#switching-between-postgresql-and-sqlite). |
| `DEBUG_ENABLED` | no | `False` | Set to `True` only for debugging. Never enable it on a public host. |
| `LOG_LEVEL` | no | `ERROR` | Django log level, e.g. `INFO` or `DEBUG`. |
| `ALLOWED_HOSTS` | no | `localhost,127.0.0.1` | Comma separated, no spaces. Add the public address of your server, otherwise Django answers every request with `400 Bad Request`. |
| `CORS_ALLOWED_ORIGINS` | no | `http://localhost:3000` | Comma separated list of origins the frontend may call the API from. |

**Database**

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `DB_PASSWORD` | **yes** | - | Password for the PostgreSQL user. Used by both services. |
| `DB_NAME` | no | `trucksigns_db` | Database name. |
| `DB_USER` | no | `trucksigns_user` | Database user. |
| `DB_HOST` | no | `db` | Set by `docker-compose.yml` to the service name. Only relevant when running the container without Compose. |
| `DB_PORT` | no | `5432` | Database port inside the network. |

**Runtime and deployment**

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `BACKEND_PORT` | no | `8020` | Host port the API is published on. |
| `IMAGE_TAG` | no | `main` | Which image tag to deploy. `main` is the latest build of the default branch; use a release tag such as `v1.0.0` to pin a specific build. |
| `GUNICORN_WORKERS` | no | `4` | Number of Gunicorn worker processes. A common starting point is `2 x CPU cores + 1`. |
| `DB_WAIT_RETRIES` | no | `30` | How many times the entrypoint retries the database connection before giving up. |
| `DB_WAIT_INTERVAL` | no | `2` | Seconds between those retries. |

**Admin account** (optional - see [The Superuser Account](#the-superuser-account))

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `DJANGO_SUPERUSER_USERNAME` | no | empty | Admin login name. |
| `DJANGO_SUPERUSER_EMAIL` | no | empty | Admin email address. |
| `DJANGO_SUPERUSER_PASSWORD` | no | empty | Admin password. |

**Media storage** (optional - see [Media Storage: Local or Cloudinary](#media-storage-local-or-cloudinary))

| Variable | Required | Default | Description |
| --- | --- | --- | --- |
| `CLOUD_NAME` | no | empty | Cloudinary cloud name. When empty, media is stored in the local volume. |
| `CLOUD_API_KEY` | no | empty | Cloudinary API key. |
| `CLOUD_API_SECRET` | no | empty | Cloudinary API secret. |

### Building a Container Image

The `Dockerfile` produces a single-stage image based on `python:3.12-slim`.

```bash
# Build with an arbitrary local tag
docker build -t truck-sign:local .

# Build without cached layers, e.g. to pick up base image security patches
docker build --no-cache -t truck-sign:local .

# Inspect the result
docker image ls truck-sign
docker run --rm --entrypoint sh truck-sign:local -c "id && pwd"
```

What the build does, and how to modify it:

* **Base image** - `FROM python:3.12-slim`. The tag is pinned to a minor version on purpose;
  `latest` would make builds irreproducible. The `slim` variant keeps the image small and the
  attack surface low. It contains no compiler and no `netcat`, which is why the entrypoint probes
  the database with Python instead of `nc`.
* **Dependencies** - `requirements.txt` is copied and installed **before** the application code,
  so the slow dependency layer is reused as long as that file does not change. Add or upgrade
  packages there, then rebuild.
* **Runtime user** - the image creates `appuser` with UID `10001` and switches to it with
  `USER 10001`. The application never runs as root. If you add a directory the application must
  write to, create it in the same `RUN` layer so it ends up owned by that user.
* **Working directory** - the final `WORKDIR` is `/app/src`, where `manage.py` lives, so
  `manage.py` and the `tsa_app.wsgi` module resolve at runtime.
* **`EXPOSE 8000`** - documents the port Gunicorn listens on *inside* the container. It publishes
  nothing by itself; the host port is mapped by Compose or by `docker run -p`.

To publish the image manually instead of through CI:

```bash
echo "<your-github-token>" | docker login ghcr.io -u <your-github-username> --password-stdin
docker build -t ghcr.io/<your-github-username>/truck-sign:main .
docker push ghcr.io/<your-github-username>/truck-sign:main
```

The token needs the `write:packages` scope. Normally this is done by the
[Build Application](#build-application) workflow, which uses the automatic `GITHUB_TOKEN`.

### Running with Docker Compose

This is the intended way to run the stack. See [Quickstart](#quickstart) for the short version.

```bash
docker compose pull             # fetch the image tag named in .env
docker compose up -d            # start in the background
docker compose logs -f backend  # follow the application log
docker compose ps               # status and published ports
docker compose restart backend  # restart just the application
docker compose down             # stop and remove containers, keep volumes
```

Things you are likely to change in `docker-compose.yml`:

* **Which image is deployed.** The `backend` service references
  `ghcr.io/cookiecrack3r/truck-sign:${IMAGE_TAG:-main}`. Replace the image path if you forked
  the repository, and set `IMAGE_TAG` in `.env` to deploy a specific build.
* **The published port.** See [Changing the Published Port](#changing-the-published-port).
* **The PostgreSQL version.** The `db` service uses `postgres:17-alpine`. Changing the major
  version requires migrating the data directory: a `postgres_data` volume created by an older
  major version will not be read by a newer one.
* **Startup order.** The backend declares `depends_on: db: condition: service_healthy`, so it
  starts only after the database healthcheck passes. The entrypoint additionally waits for a real
  connection, so the stack also recovers if the database restarts later.
* **Restart behaviour.** Both services use `restart: unless-stopped`: Docker restarts them after a
  crash and after a host reboot, but not after you stopped them manually.

> [!NOTE]
> To verify the restart policy, do not use `docker kill` - Docker treats that like a manual stop
> and deliberately does not restart the container. Send the signal to the process inside instead:
> `docker exec tsa_backend sh -c 'kill -TERM 1'`, then watch `docker compose ps`.

### Running with docker run

The container can also be started without Compose, for example to test the image against an
existing database. It needs a network it shares with PostgreSQL, the published port, and the
environment variables.

Replace every `<placeholder>` - **never put real credentials into a command you commit or share.**

```bash
# A network both containers can talk on
docker network create tsa-network

# The database
docker run -d \
  --name tsa_db \
  --network tsa-network \
  --restart unless-stopped \
  -e POSTGRES_DB='<your-database-name>' \
  -e POSTGRES_USER='<your-database-user>' \
  -e POSTGRES_PASSWORD='<your-database-password>' \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:17-alpine

# The application
docker run -d \
  --name tsa_backend \
  --network tsa-network \
  --restart unless-stopped \
  -p 8020:8000 \
  -e MODE='prod' \
  -e DEBUG_ENABLED='False' \
  -e SECRET_KEY='<your-django-secret-key>' \
  -e ALLOWED_HOSTS='localhost,127.0.0.1,<your-server-address>' \
  -e DB_NAME='<your-database-name>' \
  -e DB_USER='<your-database-user>' \
  -e DB_PASSWORD='<your-database-password>' \
  -e DB_HOST='tsa_db' \
  -e DB_PORT='5432' \
  -e DJANGO_SUPERUSER_USERNAME='<your-admin-username>' \
  -e DJANGO_SUPERUSER_EMAIL='<your-admin-email>' \
  -e DJANGO_SUPERUSER_PASSWORD='<your-admin-password>' \
  -v static_files:/app/src/staticfiles \
  -v media_files:/app/src/mediafiles \
  ghcr.io/cookiecrack3r/truck-sign:main
```

Passing secrets on the command line puts them into your shell history and into `docker inspect`.
Prefer an env file:

```bash
docker run -d \
  --name tsa_backend \
  --network tsa-network \
  --restart unless-stopped \
  -p 8020:8000 \
  --env-file .env \
  -e DB_HOST='tsa_db' \
  -v static_files:/app/src/staticfiles \
  -v media_files:/app/src/mediafiles \
  ghcr.io/cookiecrack3r/truck-sign:main
```

### Changing the Published Port

The API answers on host port **8020** by default. The mapping lives in `docker-compose.yml`:

```yaml
ports:
  - '${BACKEND_PORT:-8020}:8000'
```

The left number is the host port, the right one is Gunicorn's port inside the container. To serve
on a different host port, set `BACKEND_PORT` in `.env` - for example `BACKEND_PORT=9000` - and run
`docker compose up -d` again. Do not change the right-hand `8000`: it must match `GUNICORN_BIND`,
which the entrypoint defaults to `0.0.0.0:8000`.

Remember to open the port in the firewall or security group of your cloud VM, and to add the
server address to `ALLOWED_HOSTS`.

### The Superuser Account

The entrypoint creates a Django superuser automatically, but only when
`DJANGO_SUPERUSER_USERNAME` and `DJANGO_SUPERUSER_PASSWORD` are both set. If they are not set, the
step is skipped and the log says so.

The step is **idempotent**: it checks whether the user already exists and only creates it when it
does not. A restart therefore never overwrites an existing account and never fails because the
account is already there:

```
[entrypoint] ensuring superuser 'admin' exists ...
[entrypoint] superuser created                              <- first start
[entrypoint] superuser already exists - skipping creation   <- every later start
```

Changing `DJANGO_SUPERUSER_PASSWORD` afterwards has no effect, because the account already exists.
Change the password in the admin panel, or from the command line:

```bash
docker compose exec backend python manage.py changepassword <your-admin-username>
```

To create an additional superuser interactively:

```bash
docker compose exec backend python manage.py createsuperuser
```

### Data Persistence and Volumes

The stack uses three **named volumes**, managed by Docker rather than bound to a host directory:

| Volume | Mounted at | Contents |
| --- | --- | --- |
| `postgres_data` | `/var/lib/postgresql/data` | The PostgreSQL data directory |
| `static_files` | `/app/src/staticfiles` | Static files produced by `collectstatic` |
| `media_files` | `/app/src/mediafiles` | Files uploaded by users |

Named volumes survive `docker compose down`, `docker compose restart` and a host reboot. They are
used deliberately instead of host bind mounts, so that no permanent link exists from the host
filesystem into the container.

```bash
docker volume ls | grep truck-signs      # list them
docker compose down                      # containers gone, data kept
docker compose down -v                   # data deleted as well - irreversible
```

To back up the database:

```bash
docker compose exec db pg_dump -U <your-database-user> <your-database-name> > backup.sql
```

### Switching Between PostgreSQL and SQLite

`src/tsa_app/settings.py` picks the database from the `MODE` variable:

* `MODE=prod` -> PostgreSQL, configured from `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST` and
  `DB_PORT`. This is what the Compose stack sets.
* `MODE` unset or any other value -> SQLite at `src/db.sqlite3`, no database variables needed.
  Useful for local development and for the test job in CI.

SQLite inside the container is not persisted by any volume, so this mode is not suitable for a
deployment.

### Media Storage: Local or Cloudinary

By default, uploaded images are written to the `media_files` volume. If `CLOUD_NAME` is set,
`settings.py` switches to [Cloudinary](https://cloudinary.com/) and uses `CLOUD_API_KEY` and
`CLOUD_API_SECRET` for authentication. Leave all three empty to keep local storage.

### Local Development Without Docker

Running the application directly is useful for writing code and running the test suite.

```bash
git clone https://github.com/CookieCrack3r/truck-sign.git
cd truck-sign

python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate

pip install -r requirements.txt
cp example.env .env               # set MODE=dev to use SQLite

cd src
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

The development server runs on <http://localhost:8000>. It is a development server only - the
container image always serves through Gunicorn.

Quality checks, as run by CI:

```bash
flake8 .
black --check .
isort --check-only .
cd src && python manage.py test --verbosity=2
```

See [docs/testing.md](./docs/testing.md) for details.

### Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `DB_PASSWORD must be set in .env` | `.env` is missing or the variable is empty. Copy `example.env` and fill it in. |
| `[entrypoint] postgres unreachable after 30 attempts` | The database did not become ready. Check `docker compose logs db`; raise `DB_WAIT_RETRIES` on very slow hosts. |
| `400 Bad Request` on every URL | The requested host is not in `ALLOWED_HOSTS`. Add the server address and restart. |
| Admin panel has no styling | `collectstatic` failed or the `static_files` volume is stale. Check the backend log; `docker compose down -v` recreates the volume. |
| `denied` or `manifest unknown` when pulling | The GHCR package is private or the tag does not exist. Make the package public, or run `docker login ghcr.io`. |
| Container keeps restarting | `docker compose logs backend` shows the reason; the restart policy keeps retrying until the cause is fixed. |

## CI/CD Pipeline

Three GitHub Actions workflows live in `.github/workflows/`.

### Build Application

`.github/workflows/build.yaml` - builds the container image and publishes it to GHCR.

* **Triggers:** pushes to `main`, pushes of any tag, and manual runs (`workflow_dispatch`).
* **Permissions:** `packages: write` is required; without it the push to GHCR fails with `403`.
* **Steps:** checkout -> log in to `ghcr.io` with the automatic `GITHUB_TOKEN` -> set up Buildx ->
  derive tags and labels with `docker/metadata-action` -> build and push with
  `docker/build-push-action`, using the GitHub Actions cache.
* **Tags produced:** the branch name for branch pushes (`main`), the tag name for tag pushes
  (`v1.0.0`), and `latest` for the default branch.

`docker/metadata-action` also lowercases the repository name. GHCR rejects uppercase image names,
so a repository owner such as `CookieCrack3r` would otherwise break the push.

The resulting image is exactly what `docker-compose.yml` pulls, which is why the Compose file
contains no `build` context.

### Lint and Test Python Code Base

`.github/workflows/test.yaml` - quality gate for the application code.

* **Triggers:** pushes and pull requests against `main` that touch `**/*.py` or `requirements.txt`.
* **`lint` job:** `flake8`, `black --check` and `isort --check-only`, configured in
  `pyproject.toml`.
* **`test` job:** runs after `lint` and executes the Django test suite in `src/` with `MODE=dev`,
  so the tests use SQLite and need no database service.

### Check Open PR

`.github/workflows/check-open-pr.yaml` - makes sure feature branches are not pushed without a pull
request. It runs on every push to a branch other than `main` and fails when no open PR exists for
that branch.

### Required Repository Settings

For the pipeline to work end to end:

1. **Actions permissions** - under `Settings -> Actions -> General -> Workflow permissions`, the
   `packages: write` permission declared in the workflow must be allowed.
2. **Package visibility** - after the first successful push the GHCR package is private. Set it to
   public under `Packages -> truck-sign -> Package settings`, otherwise every deployment host
   needs `docker login ghcr.io`.
3. **Image path** - `docker-compose.yml` must reference the same package the workflow publishes.

## Application Reference

### Models

Most models do what their name suggests. The following notes clarify the less obvious ones:

- __Category Model:__ The category of the vinyls in the store. It contains the title of the category as well as the basic properties shared among products that belong to the same category. For example, _Truck Logo_ is a category for all vinyls that have a logo of a truck plus some lines of letterings (the vinyls themselves are instances of the model _Product_). Another category is _Fire Extinguisher_, for all vinyls with a fire extinguisher logo.
- __Lettering Item Category:__ The category of the lettering, for example _Company Name_ or _VIN NUMBER_. Each has different pricing.
- __Lettering Item Variations:__ Contains a foreign key to the __Lettering Item Category__ and the text added by the client.
- __Product Variation:__ Has the original product as a foreign key, plus the lettering lines (instances of the __Lettering Item Variations__ model) added by the client.

### Brief Explanation of the Views

Most views are class based views imported from _rest_framework.generics_. They provide the basic
CRUD operations expected from the API and inherit from _ListAPIView_, _CreateAPIView_,
_RetrieveAPIView_ and so on.

The behaviour of some views had to be modified to address functionality such as order creation and
payment: both are implemented in the same view, which therefore inherits from _GenericAPIView_.
Another example is the _UploadCustomerImage_ view, which takes the vinyl template uploaded by a
client and creates a new product from it.

### API Endpoints

All API routes are served under the `/truck-signs/` prefix, for example:

| Endpoint | Purpose |
| --- | --- |
| `/truck-signs/products/` | List products |
| `/truck-signs/categories/` | List categories |
| `/truck-signs/product-detail/<id>/` | Retrieve a single product |
| `/truck-signs/product-color/` | List available colors |
| `/truck-signs/truck-logo-list/` | List truck logos |
| `/truck-signs/order/<id>/create/` | Create an order |

The full list is defined in `src/tsa_products/urls.py`. The Django admin panel is at `/admin/`.

> [!NOTE]
> To create truck vinyls with truck logos in them, first create the __Category__ Truck Sign,
> and then the __Product__ (it can have any name). This ensures the frontend retrieves the truck
> vinyls for display in the product grid, as it only fetches products of the category Truck Sign.

## Screenshots of the Django Backend Admin Panel

### Mobile View

<div style="padding: 0 5rem; width: 100%;  display: flex; gap: 5rem; justify-content: center; flex-wrap: wrap;">

![Admin panel, mobile view](./src/screenshots/Admin_Panel_View_Mobile.png)

![Admin panel, mobile view](./src/screenshots/Admin_Panel_View_Mobile_2.png)

![Admin panel, mobile view](./src/screenshots/Admin_Panel_View_Mobile_3.png)

</div>

### Desktop View

<div style="padding: 0 5rem; width: 100%; display: flex; flex-direction: column; gap: 2rem; align-items: center; justify-content: center;">

![Admin panel, desktop view](./src/screenshots/Admin_Panel_View.png)

![Admin panel, desktop view](./src/screenshots/Admin_Panel_View_2.png)

![Admin panel, desktop view](./src/screenshots/Admin_Panel_View_3.png)

</div>

## Additional Information

**Docker and deployment**

- [Docker official documentation](https://docs.docker.com/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Working with the GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Dockerizing Django with Postgres, Gunicorn and Nginx](https://testdriven.io/blog/dockerizing-django-with-postgres-gunicorn-and-nginx/)

**PostgreSQL**

- [Official `postgres` image](https://hub.docker.com/_/postgres)
- [Django deployment on a VPS](https://www.digitalocean.com/community/tutorials/how-to-set-up-django-with-postgres-nginx-and-gunicorn-on-ubuntu-16-04)

**Django and DRF**

- [Django official documentation](https://docs.djangoproject.com/en/5.2/)
- [Django deployment checklist](https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/)
- [Django REST Framework documentation](https://www.django-rest-framework.org/)
- Customising the Django admin: [small modifications](https://realpython.com/customize-django-admin-python/), [templates and CSS](https://medium.com/@brianmayrose/django-step-9-180d04a4152c)
- [Nested serializers](https://stackoverflow.com/questions/51182823/django-rest-framework-nested-serializers)
- [More about generic views](https://testdriven.io/blog/drf-views-part-2/)

**Miscellaneous**

- [Configure CORS](https://www.stackhawk.com/blog/django-cors-guide/)
- [Set up Django with Cloudinary](https://cloudinary.com/documentation/django_integration)
- [Virtual environments](https://docs.python-guide.org/dev/virtualenvs/)
