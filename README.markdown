# Austral Docker PHP

[![License](https://img.shields.io/github/license/austral-project/docker-php)](https://img.shields.io/github/license/austral-project/docker-php)
[![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/australproject/php/5.6)](https://img.shields.io/docker/v/australproject/php/5.6)
[![Docker Automated build](https://img.shields.io/docker/automated/australproject/php)](https://img.shields.io/docker/automated/australproject/php)
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/australproject/php)](https://img.shields.io/docker/cloud/build/australproject/php)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/australproject/php)](https://img.shields.io/docker/image-size/australproject/php)

> **Legacy image (PHP 5.6 / Alpine 3.7)**: end of life, no security updates. Do not expose it directly, run it on an internal network behind a reverse proxy.

View repository for the base image Alpine 3.7 : [Docker Hub](https://hub.docker.com/r/australproject/alpine/) or [Gitub](https://github.com/austral-project/docker-alpine)

__Versions__
* PHP : 5.6.40
* PostgreSQL-client : 10.10
* MariaDB-client : 10.1.41
* Composer : 2.2 (LTS)
* Supercronic : 0.2.49

__PECL extensions (built from source)__
* redis : 4.3.0
* msgpack : 0.5.7
* xdebug : 2.5.5 (only loaded when XDEBUG=1)
* imagick : 3.4.4

__VARS defined :__
* APP_ENV : prod or dev
* APP_DEBUG : true or false
* XDEBUG -> to active php module (Xdebug 2.x, remote debug on port 9000)
* SCRIPT_AUTO : 1 / 0 -> enabled script auto if file exists
* PHP_MEMORY_LIMIT -> default : 512M
* PHP_MAX_EXECUTION_TIME -> default : 120
* PHP_MAX_INPUT_TIME -> default : 60
* PHP_MAX_INPUT_VARS -> default : 5000

__Script Auto__
* add run.sh file in path project -> script-auto/run.sh

(le reste inchangé : Commit Messages, License and Copyright, Credits)