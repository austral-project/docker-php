# Austral Docker PHP 8.2

[![License](https://img.shields.io/github/license/austral-project/docker-php)](https://img.shields.io/github/license/austral-project/docker-php)
[![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/australproject/php/8.4)](https://img.shields.io/docker/v/australproject/php/8.4)
[![Docker Automated build](https://img.shields.io/docker/automated/australproject/php)](https://img.shields.io/docker/automated/australproject/php)
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/australproject/php)](https://img.shields.io/docker/cloud/build/australproject/php)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/australproject/php)](https://img.shields.io/docker/image-size/australproject/php)

View repository for the base image Alpine 3.23 : [Docker Hub](https://hub.docker.com/r/australproject/alpine/) or [Gitub](https://github.com/austral-project/docker-alpine)

__Versions__
* PHP : 8.4.17
* PostgreSQL-client : 16.12
* MySQL-client : 11.4.9

__VARS defined :__
* APP_ENV : prod or dev
* APP_DEBUG : true or false
* XDEBUG -> to active php module
* SCRIPT_AUTO : 1 / 0 -> enabled script auto if file exists
* PHP_MEMORY_LIMIT -> default : 512M
* PHP_MAX_EXECUTION_TIME -> default : 120
* PHP_MAX_INPUT_TIME -> default : 60
* PHP_MAX_INPUT_VARS -> default : 5000

__Script Auto__
* add run.sh file in path project -> script-auto/run.sh

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