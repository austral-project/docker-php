# Austral Docker PHP 8.0

[![License](https://img.shields.io/github/license/austral-project/docker-php)](https://img.shields.io/github/license/austral-project/docker-php)
[![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/australproject/php/8.0)](https://img.shields.io/docker/v/australproject/php/8.0)
[![Docker Automated build](https://img.shields.io/docker/automated/australproject/php)](https://img.shields.io/docker/automated/australproject/php)

View repository for the base image Alpine 3.15 : [Docker Hub](https://hub.docker.com/repository/docker/australproject/alpine/) or [Gitub](https://github.com/austral-project/docker-alpine)

__Versions__
* PHP : 8.0.18
* Node : 16.14.2
* NPM : 8.1.3
* Squoosh-cli : 0.7.2
* PostreSQL-client : 14.4
* MySQL-client : 10.6

__VARS defined :__
* APP_ENV : prod or dev
* APP_DEBUG : true or false
* XDEBUG -> to active php module

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