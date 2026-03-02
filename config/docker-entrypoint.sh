#!/usr/bin/env sh
set -eu

SCRIPT_AUTO=${SCRIPT_AUTO:-1}
APP_ENV=${APP_ENV:-prod}
APP_DEBUG=${APP_DEBUG:-false}
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-512M}
PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-120}
PHP_MAX_INPUT_TIME=${PHP_MAX_INPUT_TIME:-60}
PHP_MAX_INPUT_VARS=${PHP_MAX_INPUT_VARS:-5000}
XDEBUG=${XDEBUG:-0}

# =========================
# Create log directories and set ownership
# =========================
mkdir -p /home/www-data/website/docker-log/php
chown -R www-data:www-data /home/www-data/website/docker-log

mkdir -p /home/www-data/website/var/cache
chown -R www-data:www-data /home/www-data/website/var/cache

# =========================
# Configure PHP error reporting and opcache based on debug mode
# =========================
if [ "${APP_DEBUG}" = "false" ]; then
  ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"
  DISPLAY_ERRORS="Off"
  OPCACHE_VALIDATE_TIMESTAMPS="0"
else
  ERROR_REPORTING="E_ALL"
  DISPLAY_ERRORS="On"
  OPCACHE_VALIDATE_TIMESTAMPS="1"
fi

# =========================
# Show environment info
# =========================
echo "App ENV: ${APP_ENV}, Debug: ${APP_DEBUG}"
echo "------------------------------------------"
echo "Error reporting : ${ERROR_REPORTING}"
echo "Display error : ${DISPLAY_ERRORS}"
echo "Opcache Validate timestamps : ${OPCACHE_VALIDATE_TIMESTAMPS}"
echo "------------------------------------------"
echo "PHP Memory limit : ${PHP_MEMORY_LIMIT}"
echo "Max Execution Time : ${PHP_MAX_EXECUTION_TIME}"
echo "Max Input Time : ${PHP_MAX_INPUT_TIME}"
echo "Max Input Vars : ${PHP_MAX_INPUT_VARS}"
echo "------------------------------------------"
echo "Xdebug enabled ? : ${XDEBUG}"

# =========================
# Generate php.ini from template if missing
# =========================
if [ ! -f /etc/php${PHP_VERSION}/php.ini ]; then
  envsubst '${ERROR_REPORTING} ${DISPLAY_ERRORS} ${OPCACHE_VALIDATE_TIMESTAMPS} ${PHP_MEMORY_LIMIT} ${PHP_MAX_EXECUTION_TIME} ${PHP_MAX_INPUT_TIME} ${PHP_MAX_INPUT_VARS}' \
  < /etc/php${PHP_VERSION}/php.ini.conf > /etc/php${PHP_VERSION}/php.ini
fi

# =========================
# Install and configure Xdebug if enabled
# =========================
if [ "${XDEBUG}" = "1" ]; then

  mkdir -p /home/www-data/website/docker-log/xdebug
  chown -R www-data:www-data /home/www-data/website/docker-log/xdebug

  apk add --no-cache php${PHP_VERSION}-xdebug php${PHP_VERSION}-dev
  echo "[xdebug]
zend_extension=xdebug.so
xdebug.mode=develop,debug,profile,trace
xdebug.start_with_request=On
xdebug.discover_client_host=On
xdebug.client_port=9000
xdebug.max_nesting_level=500
xdebug.client_enable=On
xdebug.profiler_append=On
xdebug.log=/home/www-data/website/var/log/xdebug.log
xdebug.log_level=7
xdebug.idekey=PHPSTORM
xdebug.output_dir=/home/www-data/website/docker-log/xdebug/" > /etc/php${PHP_VERSION}/conf.d/99-xdebug.ini
fi


# =========================
# Run automatic script if SCRIPT_AUTO is enabled
# =========================
if [ "${SCRIPT_AUTO}" = "1" ] && [ -f /home/www-data/website/script-auto/run.sh ]; then
  echo "Start script auto"
  chmod +x /home/www-data/website/script-auto/run.sh
  su-exec www-data /bin/sh /home/www-data/website/script-auto/run.sh
else
  echo "No script auto detected"
fi

# =========================
# Execute container main process
# =========================
exec "$@"