Changelog
=========

### Version PHP 8.1 (2026-10-07)
* Add env vars `CREATE_LOG_DIR` and `CREATE_CACHE_DIR` (`1`/`true` to enable)
* Update start-up: `docker-log/php` and `var/cache` are no longer created by default (set `CREATE_LOG_DIR=1` / `CREATE_CACHE_DIR=1` to restore the previous behaviour)

### Version PHP 8.1 (2026-10-06)
**Non-root support**
* Add support for any UID/GID (e.g. Swarm `user: "3001:3001"`); the container no longer needs root
* Add rendering of the configuration at start-up into `/tmp/php` (`PHPRC`, `PHP_INI_SCAN_DIR`), writable by any user
* Add `gettext` (`envsubst`) and `su-exec` to the image
* Delete `pid` file directive from `php-fpm.conf`
* Update pool `user`/`group`: only set when the container starts as root
* Update `chown`, `su-exec` and `HOME`/`COMPOSER_HOME` handling to work with or without root
* Update Xdebug: installed in the image, enabled with `XDEBUG=1` (no more `apk add` at start-up); configuration written to a separate ini file instead of being appended to `php.ini`

**Configuration overrides**
* Add `/overrides/php.ini`, `/overrides/php-fpm.conf`, `/overrides/www.conf` to replace a whole file
* Add `/overrides/conf.d/*.ini` and `/overrides/pool.d/*.conf` as drop-ins added on top of the base configuration
* Add env vars `PHP_POST_MAX_SIZE`, `PHP_UPLOAD_MAX_FILESIZE`, `PHP_SESSION_SAVE_PATH`, `PHP_MEMORY_LIMIT`, `PHP_MAX_EXECUTION_TIME`, `PHP_MAX_INPUT_TIME`, `PHP_MAX_INPUT_VARS`
* Add env vars `OPCACHE_ENABLED`, `OPCACHE_VALIDATE_TIMESTAMPS`, `OPCACHE_MEMORY`, `OPCACHE_REVALIDATE_FREQ`
* Add env vars `FPM_PM`, `FPM_MAX_CHILDREN`, `FPM_START_SERVERS`, `FPM_MIN_SPARE_SERVERS`, `FPM_MAX_SPARE_SERVERS`, `FPM_MAX_REQUESTS`, `FPM_REQUEST_TERMINATE_TIMEOUT`, `FPM_LOG_LEVEL`
* Update `APP_DEBUG` and `XDEBUG` to accept `0`/`false` and `1`/`true`

**Defaults changed**
* Update `memory_limit` default from 512M to 256M
* Update `post_max_size` and `upload_max_filesize` defaults from 10G / 4G to 64M
* Update PHP-FPM pool defaults: `max_children` 20, `start_servers` 4, `min_spare_servers` 4, `max_spare_servers` 16, `max_requests` 500, `request_terminate_timeout` 300s
* Update `opcache.validate_timestamps`: stays at 1 in production unless overridden (was 0 in production; files edited over SFTP are picked up)

**Runtime**
* Add Supercronic 0.2.49 (checksum verified at build time), for cron services that log to `docker logs`
* Add `catch_workers_output` in PHP-FPM pool, so worker output reaches `docker logs`
* Add `HEALTHCHECK` on the FPM port (9900)
* Update `SCRIPT_AUTO`: runs `script-auto/run.sh` as `www-data` when root, as the current user otherwise (set it to 0 on cron and secondary services)
* Update PHP-FPM log: errors now go to the container output instead of `var/docker-log/php/php-fpm.log`
* Update default command to `php-fpm` (expanded by the entrypoint with the rendered configuration)

### Version PHP 8.1 (2023-03-07)
* Update Alpine Version to 3.17
* Update PHP Version to 8.1
* Update Nodejs Version to 18.14.2
* Update Npm Version to 9.1.2