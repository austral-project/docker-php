# Austral Docker PHP 8.2

[![License](https://img.shields.io/github/license/austral-project/docker-php)](https://img.shields.io/github/license/austral-project/docker-php)
[![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/australproject/php/8.2)](https://img.shields.io/docker/v/australproject/php/8.2)
[![Docker Automated build](https://img.shields.io/docker/automated/australproject/php)](https://img.shields.io/docker/automated/australproject/php)
[![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/australproject/php)](https://img.shields.io/docker/cloud/build/australproject/php)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/australproject/php)](https://img.shields.io/docker/image-size/australproject/php)

View repository for the base image Alpine 3.20 : [Docker Hub](https://hub.docker.com/r/australproject/alpine/) or [Gitub](https://github.com/austral-project/docker-alpine)

__Versions__
* PHP : 8.2.21
* Node : 20.15.1
* NPM : 10.2.5
* Squoosh-cli : 0.7.2
* PostgreSQL-client : 16.3
* MySQL-client : 10.11.8

__VARS defined :__
* APP_ENV : prod or dev
* APP_DEBUG : true or false
* XDEBUG -> to active php module

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