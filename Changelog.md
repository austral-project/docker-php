Changelog
=========

### Version PHP 5.6 (2026-10-07)
* Add env vars `CREATE_LOG_DIR` and `CREATE_CACHE_DIR` (`1`/`true` to enable)
* Update start-up: `docker-log/php` and `var/cache` are no longer created by default (set `CREATE_LOG_DIR=1` / `CREATE_CACHE_DIR=1` to restore the previous behaviour)

### Version PHP 5.6 (2026-10-06)
**Non-root support**
* Add support for any UID/GID (e.g. Swarm `user: "3001:3001"`); the container no longer needs root
* Add rendering of the configuration at start-up into `/tmp/php` (`PHPRC`, `PHP_INI_SCAN_DIR`), writable by any user
* Add `gettext` (`envsubst`) to the image
* Delete `pid` file directive from `php-fpm.conf`
* Update pool `user`/`group`: only set when the container starts as root
* Update `chown`, `su-exec` and `HOME`/`COMPOSER_HOME` handling to work with or without root
* Update Xdebug: compiled in the image and enabled with `XDEBUG=1` (no more `apk add` at start-up)

**Configuration overrides**
* Add `/overrides/php.ini`, `/overrides/php-fpm.conf`, `/overrides/www.conf` to replace a whole file
* Add `/overrides/conf.d/*.ini` and `/overrides/pool.d/*.conf` as drop-ins added on top of the base configuration
* Add env vars `PHP_POST_MAX_SIZE`, `PHP_UPLOAD_MAX_FILESIZE`, `PHP_SESSION_SAVE_PATH`, `OPCACHE_MEMORY`, `OPCACHE_REVALIDATE_FREQ`, `OPCACHE_ENABLED`, `OPCACHE_VALIDATE_TIMESTAMPS`
* Add env vars `FPM_PM`, `FPM_MAX_CHILDREN`, `FPM_START_SERVERS`, `FPM_MIN_SPARE_SERVERS`, `FPM_MAX_SPARE_SERVERS`, `FPM_MAX_REQUESTS`, `FPM_REQUEST_TERMINATE_TIMEOUT`, `FPM_LOG_LEVEL`

**Defaults changed**
* Update `PHP_MEMORY_LIMIT` default from 512M to 256M
* Update `post_max_size` and `upload_max_filesize` defaults from 10G / 4G to 64M
* Update `opcache.memory_consumption` default from 512 to 128
* Update `opcache.revalidate_freq` default from 0 to 2
* Update `opcache.validate_timestamps`: stays at 1 in production unless overridden (files edited over SFTP are picked up)

**Runtime**
* Add Supercronic 0.2.49 (checksum verified at build time), for cron services that log to `docker logs`
* Add `HEALTHCHECK` on the FPM port (9900)
* Update default command to `php-fpm` (expanded by the entrypoint with the rendered configuration)
* Update `SCRIPT_AUTO`: set it to 0 on cron and secondary services

### Version PHP 5.6 (2026-10-05)
* Create image from the PHP 8 Dockerfile, adapted to PHP 5.6
* Update Alpine Version to 3.7
* Update PHP Version to 5.6.40
* Update PostgreSQL-client Version to 10.10
* Update MariaDB-client Version to 10.1.41 (replaces MySQL-client)
* Update Composer Version to 2.2 (LTS, last version compatible with PHP 5.6)
* Add PECL extensions built from source: redis 4.3.0, msgpack 0.5.7, xdebug 2.5.5, imagick 3.4.4
* Update Xdebug configuration to 2.x syntax
* Delete Sodium extension (not available before PHP 7.2)
* Delete OPcache JIT settings (PHP 8.0+ only)
* Update `serialize_precision` to 17 in php.ini
* Add `catch_workers_output` in PHP-FPM pool, so worker output reaches `docker logs`
* Legacy image: no security updates, do not expose directly