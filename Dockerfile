FROM alpine:3.23 AS supercronic
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
RUN apk add --no-cache curl \
 && curl -fsSL -o /supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /supercronic" | sha256sum -c - \
 && chmod +x /supercronic

FROM node:16-alpine3.17 AS node

FROM australproject/alpine:3.17
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

ENV SCRIPT_AUTO=1

RUN apk update && apk upgrade
RUN apk add --update --no-cache php81 \
  php81-pecl-redis \
  php81-common \
  php81-pecl-msgpack \
  php81-pear \
  php81-opcache\
  php81-session \
  php81-cli \
  php81-iconv \
  php81-pcntl \
  php81-fileinfo \
  php81-exif \
  php81-json \
  php81-curl \
  php81-sodium \
  php81-soap \
  php81-fpm \
  php81-gd \
  php81-gmp \
  php81-imap \
  php81-intl \
  php81-json \
  php81-phar \
  php81-pdo \
  php81-mbstring \
  php81-opcache \
  php81-sqlite3 \
  php81-ctype \
  php81-xml \
  php81-simplexml \
  php81-xsl \
  php81-zip \
  php81-tokenizer \
  php81-openssl \
  php81-xmlwriter \
  php81-xmlreader \
  php81-sockets \
  php81-pdo_pgsql \
  php81-pgsql \
  php81-pdo_mysql\
  php81-pcntl \
  php81-exif \
  postgresql15-client \
  mysql-client \
  php81-xdebug \
  gettext \
  su-exec

# Node 16 (needed by squoosh-cli) copied from the official image: mixing Alpine 3.15
# and 3.17 repositories with apk is fragile (nodejs / nodejs-current conflicts).
RUN apk add --no-cache libstdc++
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN export NODE_OPTIONS=--openssl-legacy-provider
# Xdebug is installed but only enabled on demand (XDEBUG=1) by the entrypoint
RUN rm -f /etc/php81/conf.d/*xdebug*.ini \
 && rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/local/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

RUN [ -e /usr/bin/php ] || ln -s /usr/bin/php81 /usr/bin/php
#RUN sed -i 's/#default_bits/default_bits/' /etc/ssl/openssl.cnf
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Config templates (rendered at start-up by the entrypoint into /tmp/php)
RUN mkdir -p /usr/local/share/php-templates
COPY config/php.ini.conf config/php-fpm.conf config/www.conf /usr/local/share/php-templates/
# Remove distro configs so only the rendered ones are used
RUN rm -f /etc/php81/php.ini /etc/php81/php-fpm.conf /etc/php81/php-fpm.d/*.conf /etc/php81/fpm/pool.d/*.conf 2>/dev/null || true

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

# Any UID must be able to write here (rendered config, tmp)
RUN mkdir -p /tmp/php /home/www-data/website \
    && chmod 1777 /tmp/php \
    && chown -R www-data:www-data /home/www-data
ENV PHP_VERSION=81
ENV PHP_RUN_DIR=/tmp/php

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r 'exit(@fsockopen("127.0.0.1", 9900) ? 0 : 1);'

WORKDIR /home/www-data/website
CMD ["php-fpm"]