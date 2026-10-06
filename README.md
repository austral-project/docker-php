# Austral Docker PHP 8.1

[![License](https://img.shields.io/github/license/austral-project/docker-php)](https://img.shields.io/github/license/austral-project/docker-php)
[![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/australproject/php/8.1)](https://img.shields.io/docker/v/australproject/php/8.1)
[![Docker Automated build](https://img.shields.io/docker/automated/australproject/php)](https://img.shields.io/docker/automated/australproject/php)
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/australproject/php)](https://img.shields.io/docker/cloud/build/australproject/php)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/australproject/php)](https://img.shields.io/docker/image-size/australproject/php)

View repository for the base image Alpine 3.17 : [Docker Hub](https://hub.docker.com/r/australproject/alpine/) or [Gitub](https://github.com/austral-project/docker-alpine)

__Versions__
* PHP : 8.1.16
* Node : 18.14.2
* NPM : 9.1.2
* Squoosh-cli : 0.7.2
* PostgreSQL-client : 15.2
* MySQL-client : 10.6.12
* Supercronic : 0.2.49

__VARS defined :__
* APP_ENV : prod or dev
* APP_DEBUG : 0 / false or 1 / true
* XDEBUG : 1 / true -> to active php module (Xdebug 3, client port 9000)
* SCRIPT_AUTO : 1 / 0 -> run script-auto/run.sh if the file exists (default : 1, set 0 on cron services)
* PHP_MEMORY_LIMIT -> default : 256M
* PHP_MAX_EXECUTION_TIME -> default : 120
* PHP_MAX_INPUT_TIME -> default : 60
* PHP_MAX_INPUT_VARS -> default : 5000
* PHP_POST_MAX_SIZE -> default : 64M
* PHP_UPLOAD_MAX_FILESIZE -> default : 64M
* PHP_SESSION_SAVE_PATH -> default : /tmp
* OPCACHE_ENABLED -> default : 1
* OPCACHE_VALIDATE_TIMESTAMPS -> default : 1
* OPCACHE_MEMORY -> default : 256
* OPCACHE_REVALIDATE_FREQ -> default : 2
* FPM_PM -> default : dynamic
* FPM_MAX_CHILDREN -> default : 20
* FPM_START_SERVERS -> default : 4
* FPM_MIN_SPARE_SERVERS -> default : 4
* FPM_MAX_SPARE_SERVERS -> default : 16
* FPM_MAX_REQUESTS -> default : 500
* FPM_REQUEST_TERMINATE_TIMEOUT -> default : 300s
* FPM_LOG_LEVEL -> default : notice

__Run as any user (non-root)__
* The image runs as root or as any UID/GID (ex: `user: "3001:3001"` in Docker Swarm)
* The configuration is generated at start-up in `/tmp/php` from templates stored in the image

__Override the configuration__

Mount a directory on `/overrides` :
* `php.ini`, `php-fpm.conf`, `www.conf` -> replace the whole file (no variable substitution)
* `conf.d/*.ini` -> extra PHP settings, loaded after the base configuration
* `pool.d/*.conf` -> extra PHP-FPM pools

__Logs__
* PHP-FPM, PHP errors and workers output are sent to the container output (`docker logs`)

__Script Auto__
* add run.sh file in path project -> script-auto/run.sh

__Cron__
* Supercronic is included : `command: supercronic /etc/crontab` in a dedicated service (use `SCRIPT_AUTO=0`)

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