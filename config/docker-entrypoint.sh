#!/usr/bin/env sh
# PHP-FPM / CLI entrypoint. Works as root (legacy) AND as any non-root UID/GID
# (Swarm `user: "3001:3001"`). Config is rendered at start-up into PHP_RUN_DIR
# (writable by anyone) and can be overridden from /overrides.
set -eu

PHP_VERSION="${PHP_VERSION:-81}"
TEMPLATE_DIR="${TEMPLATE_DIR:-/usr/local/share/php-templates}"
PHP_RUN_DIR="${PHP_RUN_DIR:-/tmp/php}"
OVERRIDES_DIR="${OVERRIDES_DIR:-/overrides}"
WEBSITE_DIR="${WEBSITE_DIR:-/home/www-data/website}"

SCRIPT_AUTO="${SCRIPT_AUTO:-1}"
APP_ENV="${APP_ENV:-prod}"
APP_DEBUG="${APP_DEBUG:-false}"
XDEBUG="${XDEBUG:-0}"

IS_ROOT=0
[ "$(id -u)" = "0" ] && IS_ROOT=1

# ---------- PHP settings (all overridable with env vars) ----------
PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-256M}"
PHP_MAX_EXECUTION_TIME="${PHP_MAX_EXECUTION_TIME:-120}"
PHP_MAX_INPUT_TIME="${PHP_MAX_INPUT_TIME:-60}"
PHP_MAX_INPUT_VARS="${PHP_MAX_INPUT_VARS:-5000}"
PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-64M}"
PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-64M}"
# Replicas: use a shared handler, e.g. "tcp://redis:6379" with PHP_SESSION_SAVE_HANDLER=redis
PHP_SESSION_SAVE_PATH="${PHP_SESSION_SAVE_PATH:-/tmp}"
OPCACHE_MEMORY="${OPCACHE_MEMORY:-256}"
OPCACHE_REVALIDATE_FREQ="${OPCACHE_REVALIDATE_FREQ:-2}"

case "${APP_DEBUG}" in 0|false|"") DEBUG_OFF=1 ;; *) DEBUG_OFF=0 ;; esac
if [ "$DEBUG_OFF" = "1" ]; then
  ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"
  DISPLAY_ERRORS="Off"
  OPCACHE_ENABLED="${OPCACHE_ENABLED:-1}"
  # Default 1 so files edited over SFTP are picked up; set 0 only for immutable images.
  OPCACHE_VALIDATE_TIMESTAMPS="${OPCACHE_VALIDATE_TIMESTAMPS:-1}"
else
  ERROR_REPORTING="E_ALL"
  DISPLAY_ERRORS="On"
  OPCACHE_ENABLED="${OPCACHE_ENABLED:-1}"
  OPCACHE_VALIDATE_TIMESTAMPS="${OPCACHE_VALIDATE_TIMESTAMPS:-1}"
fi

# ---------- FPM settings ----------
FPM_LOG_LEVEL="${FPM_LOG_LEVEL:-notice}"
FPM_PM="${FPM_PM:-dynamic}"
FPM_MAX_CHILDREN="${FPM_MAX_CHILDREN:-20}"
FPM_START_SERVERS="${FPM_START_SERVERS:-4}"
FPM_MIN_SPARE_SERVERS="${FPM_MIN_SPARE_SERVERS:-4}"
FPM_MAX_SPARE_SERVERS="${FPM_MAX_SPARE_SERVERS:-16}"
FPM_MAX_REQUESTS="${FPM_MAX_REQUESTS:-500}"
FPM_REQUEST_TERMINATE_TIMEOUT="${FPM_REQUEST_TERMINATE_TIMEOUT:-300s}"

if [ "$IS_ROOT" = "1" ]; then
  POOL_IDENTITY="user = www-data
group = www-data"
else
  POOL_IDENTITY="; running as UID $(id -u): user/group not set"
fi

export PHP_RUN_DIR PHP_MEMORY_LIMIT PHP_MAX_EXECUTION_TIME PHP_MAX_INPUT_TIME \
  PHP_MAX_INPUT_VARS PHP_POST_MAX_SIZE PHP_UPLOAD_MAX_FILESIZE PHP_SESSION_SAVE_PATH \
  OPCACHE_MEMORY OPCACHE_REVALIDATE_FREQ ERROR_REPORTING DISPLAY_ERRORS \
  OPCACHE_ENABLED OPCACHE_VALIDATE_TIMESTAMPS FPM_LOG_LEVEL FPM_PM FPM_MAX_CHILDREN \
  FPM_START_SERVERS FPM_MIN_SPARE_SERVERS FPM_MAX_SPARE_SERVERS FPM_MAX_REQUESTS \
  FPM_REQUEST_TERMINATE_TIMEOUT POOL_IDENTITY

VARS='${PHP_RUN_DIR} ${PHP_MEMORY_LIMIT} ${PHP_MAX_EXECUTION_TIME} ${PHP_MAX_INPUT_TIME}
${PHP_MAX_INPUT_VARS} ${PHP_POST_MAX_SIZE} ${PHP_UPLOAD_MAX_FILESIZE} ${PHP_SESSION_SAVE_PATH}
${OPCACHE_MEMORY} ${OPCACHE_REVALIDATE_FREQ} ${ERROR_REPORTING} ${DISPLAY_ERRORS}
${OPCACHE_ENABLED} ${OPCACHE_VALIDATE_TIMESTAMPS} ${FPM_LOG_LEVEL} ${FPM_PM}
${FPM_MAX_CHILDREN} ${FPM_START_SERVERS} ${FPM_MIN_SPARE_SERVERS} ${FPM_MAX_SPARE_SERVERS}
${FPM_MAX_REQUESTS} ${FPM_REQUEST_TERMINATE_TIMEOUT} ${POOL_IDENTITY}'

# ---------- Render configuration ----------
# Override rule: a file in /overrides REPLACES the template (copied as-is, no
# substitution, so you own the whole file). Drop-ins in /overrides/conf.d/*.ini
# and /overrides/pool.d/*.conf are ADDED on top (recommended for small tweaks).
mkdir -p "$PHP_RUN_DIR/fpm/pool.d" "$PHP_RUN_DIR/conf.d"

render() { # render <template-name> <override-name> <destination>
  if [ -f "$OVERRIDES_DIR/$2" ]; then
    echo "Config: using override $OVERRIDES_DIR/$2"
    cp "$OVERRIDES_DIR/$2" "$3"
  else
    envsubst "$VARS" < "$TEMPLATE_DIR/$1" > "$3"
  fi
}
render php.ini.conf   php.ini      "$PHP_RUN_DIR/php.ini"
render php-fpm.conf   php-fpm.conf "$PHP_RUN_DIR/php-fpm.conf"
render www.conf      www.conf     "$PHP_RUN_DIR/fpm/pool.d/www.conf"

if [ -d "$OVERRIDES_DIR/pool.d" ]; then
  cp "$OVERRIDES_DIR"/pool.d/*.conf "$PHP_RUN_DIR/fpm/pool.d/" 2>/dev/null || true
fi

# php.ini is read from PHPRC; extra .ini files from PHP_INI_SCAN_DIR
export PHPRC="$PHP_RUN_DIR"
SCAN="/etc/php${PHP_VERSION}/conf.d:$PHP_RUN_DIR/conf.d"
[ -d "$OVERRIDES_DIR/conf.d" ] && SCAN="$SCAN:$OVERRIDES_DIR/conf.d"
export PHP_INI_SCAN_DIR="$SCAN"

# ---------- Writable HOME for arbitrary UID ----------
if [ -z "${HOME:-}" ] || [ ! -w "${HOME:-/nonexistent}" ]; then
  export HOME=/tmp
fi
export COMPOSER_HOME="${COMPOSER_HOME:-/tmp/.composer}"

# ---------- Working dirs ----------
prepare_dir() {
  mkdir -p "$1" 2>/dev/null || { echo "WARN: cannot create $1"; return 0; }
  [ "$IS_ROOT" = "1" ] && chown -R www-data:www-data "$1"
  return 0
}
prepare_dir "$WEBSITE_DIR/var/docker-log/php"
# Legacy behaviour: as root, the whole var/ directory belongs to www-data
[ "$IS_ROOT" = "1" ] && chown -R www-data:www-data "$WEBSITE_DIR/var" 2>/dev/null || true
[ "$PHP_SESSION_SAVE_PATH" = "/tmp" ] || case "$PHP_SESSION_SAVE_PATH" in /*) prepare_dir "$PHP_SESSION_SAVE_PATH" ;; esac

# ---------- Xdebug (installed in the image, enabled on demand) ----------
case "${XDEBUG}" in 1|true)
  prepare_dir "$WEBSITE_DIR/var/docker-log/xdebug"
  cat > "$PHP_RUN_DIR/conf.d/99-xdebug.ini" <<XDEBUG_INI
[xdebug]
zend_extension=xdebug.so
xdebug.start_with_request=On
xdebug.discover_client_host=On
xdebug.mode=develop,debug,profile,trace
xdebug.client_port=9000
xdebug.max_nesting_level=500
xdebug.client_enable=On
xdebug.profiler_append=On
xdebug.log=$WEBSITE_DIR/var/docker-log/xdebug/xdebug.log
xdebug.log_level=7
xdebug.idekey=PHPSTORM
xdebug.output_dir=$WEBSITE_DIR/var/docker-log/xdebug/
XDEBUG_INI
  ;;
esac

echo "App ENV: ${APP_ENV}, Debug: ${APP_DEBUG}, UID: $(id -u), GID: $(id -g)"
echo "Opcache: enabled=${OPCACHE_ENABLED} validate_timestamps=${OPCACHE_VALIDATE_TIMESTAMPS} memory=${OPCACHE_MEMORY}M"
echo "PHP: memory_limit=${PHP_MEMORY_LIMIT} post_max_size=${PHP_POST_MAX_SIZE} upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}"
echo "FPM: pm=${FPM_PM} max_children=${FPM_MAX_CHILDREN} | xdebug=${XDEBUG}"

# ---------- Optional per-project start script ----------
# Set SCRIPT_AUTO=0 on cron/secondary services: replicas would each run it.
if [ "${SCRIPT_AUTO}" = "1" ] && [ -f "$WEBSITE_DIR/script-auto/run.sh" ]; then
  echo "Start script auto"
  if [ "$IS_ROOT" = "1" ]; then
    su-exec www-data /bin/sh "$WEBSITE_DIR/script-auto/run.sh"
  else
    /bin/sh "$WEBSITE_DIR/script-auto/run.sh"
  fi
else
  echo "No script auto"
fi

# ---------- Main process ----------
# Default command "php-fpm" expands to FPM with the rendered configuration.
if [ "${1:-}" = "php-fpm" ]; then
  shift
  set -- "php-fpm${PHP_VERSION}" --nodaemonize \
        --fpm-config "$PHP_RUN_DIR/php-fpm.conf" -c "$PHP_RUN_DIR/php.ini" "$@"
fi
exec "$@"
