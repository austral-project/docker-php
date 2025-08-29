#!/usr/bin/env sh
set -eu
if [ ! -d "/home/www-data/website/docker-log/php" ]; then
  mkdir -p /home/www-data/website/docker-log/php
fi

#### Init var APP_ENV if not defined or is empty
if [ -z "${APP_ENV+x}" ]; then
  APP_ENV="prod"
fi
if [ -z "${APP_DEBUG+x}" ]; then
  APP_DEBUG=false
fi

if [ -z "${PHP_MEMORY_LIMIT+x}" ]; then
  PHP_MEMORY_LIMIT="512M"
fi
if [ -z "${PHP_MAX_EXECUTION_TIME+x}" ]; then
  PHP_MAX_EXECUTION_TIME="120"
fi
if [ -z "${PHP_MAX_INPUT_TIME+x}" ]; then
  PHP_MAX_INPUT_TIME="60"
fi
if [ -z "${PHP_MAX_INPUT_VARS+x}" ]; then
  PHP_MAX_INPUT_VARS="5000"
fi


#### Init var XDEBUG if not defined or is empty
if [ -z ${XDEBUG+x} ]; then
  XDEBUG=false
fi

echo "App environnement : ${APP_ENV}"
echo "App debug : ${APP_DEBUG}"

if [ "${APP_DEBUG}" = "false" ]; then
  ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"
  DISPLAY_ERROR="Off"
  OPCACHE_VALIDATE_TIMESTAMPS="0"
else
  ERROR_REPORTING="E_ALL"
  DISPLAY_ERROR="On"
  OPCACHE_VALIDATE_TIMESTAMPS="1"
fi

echo "Error reporting : ${ERROR_REPORTING}"
echo "Display error : ${DISPLAY_ERROR}"
echo "Opcache Validate timestamps : ${OPCACHE_VALIDATE_TIMESTAMPS}"

echo "PHP Memory limit : ${PHP_MEMORY_LIMIT}"
echo "Opcache Max Execution Time : ${PHP_MAX_EXECUTION_TIME}"
echo "Opcache Max Input Time : ${PHP_MAX_INPUT_TIME}"
echo "Opcache Max Input Vars : ${PHP_MAX_INPUT_VARS}"

echo "Xdebug enabled ? : ${XDEBUG}"
XDEBUG_VALUES=""
if [ "${XDEBUG}" = 1 ]
then
  if [ ! -d "/home/www-data/website/var/docker-log/xdebug/" ]; then
    mkdir -p /home/www-data/website/var/docker-log/xdebug
  fi

  echo "Install XDEBUG"
  apk add php82-xdebug php82-dev
  XDEBUG_VALUES="
[xdebug]
zend_extension=xdebug.so
xdebug.start_with_request=On
xdebug.discover_client_host=On
xdebug.mode=develop,debug,profile,trace
xdebug.client_port=9000
xdebug.max_nesting_level=500
xdebug.client_enable=On
xdebug.profiler_append=On
xdebug.log=/home/www-data/website/var/log/xdebug.log
; xdebug.log_level=10
xdebug.log_level=7
xdebug.idekey=PHPSTORM
;xdebug.show_error_trace=On
; xdebug.show_exception_trace=On
; xdebug.show_local_vars=1
;xdebug.trace_format=2
;xdebug.trace_options=1
;xdebug.collect_return=1
;xdebug.collect_assignments=On
; xdebug.force_display_errors=On
; xdebug.scream=On
; xdebug.halt_level=E_WARNING|E_NOTICE|E_USER_WARNING|E_USER_NOTICE
xdebug.output_dir=/home/www-data/website/var/docker-log/xdebug/
";
fi


export APP_ENV
export APP_DEBUG
export XDEBUG
export XDEBUG_VALUES
export ERROR_REPORTING
export DISPLAY_ERROR
export OPCACHE_VALIDATE_TIMESTAMPS

export PHP_MEMORY_LIMIT
export PHP_MAX_EXECUTION_TIME
export PHP_MAX_INPUT_TIME
export PHP_MAX_INPUT_VARS

if test -f /etc/php82/php.ini
then
  echo "php.ini exist"
else
  echo "Generate php.ini"
  envsubst '${ERROR_REPORTING} ${DISPLAY_ERROR} {OPCACHE_VALIDATE_TIMESTAMPS} ${PHP_MEMORY_LIMIT} ${PHP_MAX_EXECUTION_TIME} ${PHP_MAX_INPUT_TIME} ${PHP_MAX_INPUT_VARS} ${XDEBUG_VALUES}' < /etc/php82/php.ini.conf > /etc/php82/php.ini
fi


if [ "${SCRIPT_AUTO}" = "1" ]; then
  if test -f /home/www-data/website/script-auto/run.sh
  then
    echo "Start script auto"
    chmod +x /home/www-data/website/script-auto/run.sh
    su -c "/bin/bash /home/www-data/website/script-auto/run.sh" www-data
  else
    echo "No script auto detected"
  fi
fi

exec "$@"