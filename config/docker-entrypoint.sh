#!/usr/bin/env sh
set -eu
if [ ! -d "/home/www-data/website/var/docker-log/php" ]; then
  mkdir -p /home/www-data/website/var/docker-log/php
fi
chown -R www-data:www-data /home/www-data/website/var

#### Init var APP_ENV if not defined or is empty
if [[ -z "${APP_ENV+x}" ]]; then
  APP_ENV="prod"
fi

#### Init var XDEBUG if not defined or is empty
if [[ -z ${XDEBUG+x} ]]; then
  XDEBUG=false
fi

echo "App environnement : ${APP_ENV}"
if [[ "${APP_ENV}" = "prod" ]]; then
  ERROR_REPORTING="E_ALL & ~E_DEPRECATED & ~E_STRICT"
  DISPLAY_ERROR="On"
else
  ERROR_REPORTING="E_ALL"
  DISPLAY_ERROR="On"
fi

echo "Error reporting : ${ERROR_REPORTING}"
echo "Display error : ${DISPLAY_ERROR}"

export APP_ENV
export XDEBUG
export ERROR_REPORTING
export DISPLAY_ERROR

envsubst '${ERROR_REPORTING} ${DISPLAY_ERROR}' < /etc/php8/php.ini.conf > /etc/php8/php.ini

echo "Xdebug enabled ? : ${XDEBUG}"
if [[ "${XDEBUG}" = 1 ]]
then
  echo "Install XDEBUG"
  apk add php8-xdebug
  printf "\n\
[xdebug] \n\
  zend_extension=xdebug.so \n\
  xdebug.start_with_request=On \n\
  xdebug.discover_client_host=On \n\
  xdebug.mode=develop,debug,profile,trace \n\
  xdebug.client_port=9000 \n\
  xdebug.max_nesting_level=500 \n\
  xdebug.client_enable=On \n\
  xdebug.profiler_append=On \n\
  xdebug.log=/home/www-data/website/var/log/xdebug.log \n\
  ; xdebug.log_level=10 \n\
  xdebug.log_level=7 \n\
  xdebug.idekey=PHPSTORM \n\
  xdebug.show_error_trace=On \n\
  ; xdebug.show_exception_trace=On \n\
  ; xdebug.show_local_vars=1 \n\
  xdebug.trace_format=2 \n\
  xdebug.trace_options=1 \n\
  xdebug.collect_return=1 \n\
  xdebug.collect_assignments=On \n\
  ; xdebug.force_display_errors=On \n\
  ; xdebug.scream=On \n\
  ; xdebug.halt_level=E_WARNING|E_NOTICE|E_USER_WARNING|E_USER_NOTICE \n\
  xdebug.output_dir=/home/www-data/website/var/docker-log/xdebug/ \n\
  " >> /etc/php8/php.ini;
fi


exec "$@"