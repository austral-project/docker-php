# Austral Docker PHP

[![License](https://img.shields.io/github/license/austral-project/docker-php)](https://img.shields.io/github/license/austral-project/docker-php)
[![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/australproject/php/5.6)](https://img.shields.io/docker/v/australproject/php/5.6)
[![Docker Automated build](https://img.shields.io/docker/automated/australproject/php)](https://img.shields.io/docker/automated/australproject/php)
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/australproject/php)](https://img.shields.io/docker/cloud/build/australproject/php)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/australproject/php)](https://img.shields.io/docker/image-size/australproject/php)

> **Legacy image (PHP 5.6 / Alpine 3.7)**: end of life, no security updates. Do not expose it directly: run it on an internal network behind a reverse proxy.

Base image Alpine 3.7: [Docker Hub](https://hub.docker.com/r/australproject/alpine/) or [GitHub](https://github.com/austral-project/docker-alpine)

## Versions

* PHP: 5.6.40
* PostgreSQL-client: 10.10
* MariaDB-client: 10.1.41
* Composer: 2.2 (LTS)
* Supercronic: 0.2.49

**PECL extensions (built from source)**

* redis: 4.3.0
* msgpack: 0.5.7
* xdebug: 2.5.5 (only loaded when `XDEBUG=1`)
* imagick: 3.4.4

## Running as any user (non-root)

The image runs as root **or** as any UID/GID, for example with Docker Swarm:

```yaml
services:
  php:
    image: australproject/php:5.6
    user: "3001:3001"
```

The configuration is rendered at start-up into `/tmp/php` (writable by any user) from templates stored in the image. When the container is not root, `user`/`group` are not set in the FPM pool and `chown` / `su-exec` are skipped. Mounted directories must already be writable by the chosen UID.

Quick test:

```bash
docker run --rm -u 3001:3001 -e SCRIPT_AUTO=0 australproject/php:5.6 php -i | grep -E "Loaded Configuration|post_max_size"
```

## Environment variables

**Application**

| Variable | Default | Description |
|---|---|---|
| `APP_ENV` | `prod` | `prod` or `dev` |
| `APP_DEBUG` | `false` | `true` or `false`; `true` enables `display_errors` and `E_ALL`, and disables OPcache |
| `XDEBUG` | `0` | `1` loads Xdebug 2.x (remote debug on port 9000) |
| `SCRIPT_AUTO` | `1` | `1` runs `script-auto/run.sh` if it exists. Set `0` on cron and secondary services |

**PHP (`php.ini`)**

| Variable | Default |
|---|---|
| `PHP_MEMORY_LIMIT` | `256M` |
| `PHP_MAX_EXECUTION_TIME` | `120` |
| `PHP_MAX_INPUT_TIME` | `60` |
| `PHP_MAX_INPUT_VARS` | `5000` |
| `PHP_POST_MAX_SIZE` | `64M` |
| `PHP_UPLOAD_MAX_FILESIZE` | `64M` |
| `PHP_SESSION_SAVE_PATH` | `/tmp` |
| `OPCACHE_ENABLED` | `1` (`0` when `APP_DEBUG=true`) |
| `OPCACHE_VALIDATE_TIMESTAMPS` | `1` |
| `OPCACHE_MEMORY` | `128` (MB) |
| `OPCACHE_REVALIDATE_FREQ` | `2` (seconds) |

> `OPCACHE_VALIDATE_TIMESTAMPS=0` is only safe for immutable deployments: files edited over SFTP would not be reloaded.

**PHP-FPM (pool `www`)**

| Variable | Default |
|---|---|
| `FPM_PM` | `dynamic` |
| `FPM_MAX_CHILDREN` | `20` |
| `FPM_START_SERVERS` | `4` |
| `FPM_MIN_SPARE_SERVERS` | `4` |
| `FPM_MAX_SPARE_SERVERS` | `16` |
| `FPM_MAX_REQUESTS` | `500` |
| `FPM_REQUEST_TERMINATE_TIMEOUT` | `300s` |
| `FPM_LOG_LEVEL` | `notice` |

> Keep `FPM_MAX_CHILDREN` × `PHP_MEMORY_LIMIT` below the container memory limit.

## Overriding the configuration

Mount a directory on `/overrides` (read-only is fine):

| Path in `/overrides` | Effect |
|---|---|
| `php.ini` | Replaces the whole `php.ini` (copied as is, no variable substitution) |
| `php-fpm.conf` | Replaces the whole `php-fpm.conf` |
| `www.conf` | Replaces the whole pool configuration |
| `conf.d/*.ini` | Extra PHP settings, loaded after the base configuration |
| `pool.d/*.conf` | Extra FPM pools, added to the base configuration |

For small changes, prefer drop-ins:

```ini
; /overrides/conf.d/custom.ini
date.timezone = Europe/Paris
session.save_handler = redis
```

```yaml
services:
  php:
    volumes:
      - ./php-overrides:/overrides:ro
```

## Logs

Everything goes to the container output (`docker logs`): FPM errors, PHP errors (`/proc/self/fd/2`) and workers' stdout/stderr (`catch_workers_output`).

## Sessions with several replicas

The default `/tmp` is not shared between replicas. Use a shared store, for example Redis (extension included):

```
PHP_SESSION_SAVE_PATH=tcp://redis:6379
```

and add `session.save_handler = redis` in `/overrides/conf.d/`.

## Script Auto

Add a `script-auto/run.sh` file in the project path. It runs at container start-up when `SCRIPT_AUTO=1` (as `www-data` when the container is root, as the current user otherwise).

## Cron with Supercronic

Supercronic is included and writes job output to stdout/stderr, so it appears in `docker logs`. Run it in a dedicated service:

```yaml
services:
  cron:
    image: australproject/php:5.6
    command: supercronic /etc/crontab
    environment:
      - SCRIPT_AUTO=0
    healthcheck:
      disable: true
```

## Healthcheck

The image checks that FPM listens on port 9900. Disable it on services that do not run FPM (cron).

## Commit Messages

The commit message must follow the [Conventional Commits specification](https://www.conventionalcommits.org/).
The following types are allowed:

* `update`: Update
* `fix`: Bug fix
* `feat`: New feature
* `docs`: Change in the documentation
* `spec`: Spec change
* `test`: Test-related change
* `perf`: Performance optimization

Examples:

    update : Something

    fix: Fix something

    feat: Introduce X

    docs: Add docs for X

    spec: Z disambiguation

## License and Copyright
See [License](https://austral.dev/en/license)

## Credits
Created by [Matthieu Beurel](https://www.mbeurel.com). Sponsored by [Yipikai Studio](https://yipikai.studio).