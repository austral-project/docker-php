Changelog
=========

### Version PHP 5.6 (2026-10-05)
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
* Add `catch_workers_output` in PHP-FPM pool
* Legacy image: no security updates, do not expose directly

### Version PHP 8.4 (2026-03-02)
* Update Alpine Version to 3.23
* Update PHP Version to 8.4
* Update PostgreSQL-client Version to 16.12
* Update MySQL-client Version to 11.4.9
* Delete Nodejs
* Delete Npm

### Version PHP 8.2 (2023-07-16)
* Update Alpine Version to 3.20
* Update PHP Version to 8.2
* Update Nodejs Version to 20.15.1
* Update Npm Version to 10.2.5
* Update PostgreSQL-client Version to 16.3
* Update MySQL-client Version to 10.11.8

### Version PHP 8.1 (2023-03-07)
* Update Alpine Version to 3.17
* Update PHP Version to 8.1
* Update Nodejs Version to 18.14.2
* Update Npm Version to 9.1.2

### Version 8.0 (2022-07-06)
* Create Dockerfile
* Create Github repository
* Create an image in the Docker hub