FROM --platform=$BUILDPLATFORM alpine:3.23 AS supercronic
ARG TARGETARCH
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256_AMD64=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
ARG SUPERCRONIC_SHA256_ARM64=02aa0cb229ba09050cba6638059dadb9eedc2276632ea43d6a57a2f8c1629dd5
RUN apk add --no-cache curl \
 && case "${TARGETARCH}" in \
      amd64) SHA="${SUPERCRONIC_SHA256_AMD64}" ;; \
      arm64) SHA="${SUPERCRONIC_SHA256_ARM64}" ;; \
      *) echo "Architecture non supportée : ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL -o /supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" \
 && echo "${SHA}  /supercronic" | sha256sum -c - \
 && chmod +x /supercronic

FROM --platform=$BUILDPLATFORM alpine:3.23 AS pecl-src
RUN apk add --no-cache curl \
    && mkdir /src && cd /src \
    && curl -fsSL https://pecl.php.net/get/ds-1.4.0.tgz -o ds.tgz \
    && curl -fsSL https://pecl.php.net/get/mcrypt-1.0.7.tgz -o mcrypt.tgz \
    && curl -fsSL https://pecl.php.net/get/oauth-2.0.9.tgz -o oauth.tgz

FROM node:16-alpine3.17 AS node

FROM australproject/alpine:3.17
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

ENV PHP_VERSION=81
ENV PHP_BIN=php-fpm${PHP_VERSION}
ENV SCRIPT_AUTO=1

RUN apk update && apk upgrade
RUN apk add --update --no-cache \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-session \
    php${PHP_VERSION}-tokenizer \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-fileinfo \
    php${PHP_VERSION}-simplexml \
    php${PHP_VERSION}-xmlwriter \
    php${PHP_VERSION}-sodium \
    php${PHP_VERSION}-pear \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-pdo \
    php${PHP_VERSION}-pdo_mysql \
    php${PHP_VERSION}-mysqli \
    php${PHP_VERSION}-pdo_pgsql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-pdo_sqlite \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-xmlreader \
    php${PHP_VERSION}-dom \
    php${PHP_VERSION}-xsl \
    php${PHP_VERSION}-ctype \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-sockets \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-zlib \
    php${PHP_VERSION}-gmp \
    php${PHP_VERSION}-exif \
    php${PHP_VERSION}-openssl \
    php${PHP_VERSION}-iconv \
    php${PHP_VERSION}-pcntl \
    php${PHP_VERSION}-posix \
    php${PHP_VERSION}-phar \
    php${PHP_VERSION}-imap \
    php${PHP_VERSION}-calendar \
    php${PHP_VERSION}-apcu \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-bz2 \
    php${PHP_VERSION}-dba \
    php${PHP_VERSION}-enchant \
    php${PHP_VERSION}-ftp \
    php${PHP_VERSION}-gettext \
    php${PHP_VERSION}-shmop \
    php${PHP_VERSION}-snmp \
    php${PHP_VERSION}-sysvmsg \
    php${PHP_VERSION}-sysvsem \
    php${PHP_VERSION}-sysvshm \
    php${PHP_VERSION}-pspell \
    php${PHP_VERSION}-ffi \
    php${PHP_VERSION}-tidy \
    php${PHP_VERSION}-pecl-redis \
    php${PHP_VERSION}-pecl-msgpack \
    php${PHP_VERSION}-pecl-imagick \
    php${PHP_VERSION}-pecl-igbinary \
    php${PHP_VERSION}-pecl-ssh2 \
    php${PHP_VERSION}-pecl-uuid \
    php${PHP_VERSION}-pecl-yaml \
    php${PHP_VERSION}-xdebug \
    libmcrypt \
    postgresql15-client \
    mysql-client \
    su-exec \
    gettext \
    && { [ -e /usr/bin/php ] || ln -s /usr/bin/php${PHP_VERSION} /usr/bin/php; } \
    && rm -rf /var/cache/apk/*

# PECL extensions without an Alpine package for this PHP version (pinned in the pecl-src stage)
COPY --from=pecl-src /src /tmp/pecl
RUN apk add --no-cache --virtual .build-deps build-base autoconf php${PHP_VERSION}-dev libmcrypt-dev \
    && cd /tmp/pecl \
    && for ext in ds mcrypt oauth; do \
         mkdir $ext && tar xzf $ext.tgz -C $ext --strip-components=1 \
         && cd $ext && phpize${PHP_VERSION} \
         && ./configure --with-php-config=/usr/bin/php-config${PHP_VERSION} \
         && make -j"$(nproc)" && make install && cd .. \
         && echo "extension=${ext}.so" > /etc/php${PHP_VERSION}/conf.d/50_${ext}.ini \
         || exit 1; \
       done \
    && apk del .build-deps \
    && rm -rf /tmp/pecl /var/cache/apk/*

# Xdebug is installed but only enabled on demand (XDEBUG=1) by the entrypoint
RUN rm -f /etc/php${PHP_VERSION}/conf.d/*xdebug*.ini

# Node 16 (needed by squoosh-cli) copied from the official image: mixing Alpine 3.15
# and 3.17 repositories with apk is fragile (nodejs / nodejs-current conflicts).
RUN apk add --no-cache libstdc++
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

RUN export NODE_OPTIONS=--openssl-legacy-provider

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/local/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

# Composer 2
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Config templates (rendered at start-up by the entrypoint into /tmp/php)
RUN mkdir -p /usr/local/share/php-templates
COPY config/php.ini.conf config/php-fpm.conf config/www.conf /usr/local/share/php-templates/
# Templates must be readable by any UID (COPY keeps the source file mode)
RUN chmod -R a+rX /usr/local/share/php-templates
# Remove distro configs so only the rendered ones are used
RUN rm -f /etc/php${PHP_VERSION}/php.ini /etc/php${PHP_VERSION}/php-fpm.conf \
          /etc/php${PHP_VERSION}/php-fpm.d/*.conf /etc/php${PHP_VERSION}/fpm/pool.d/*.conf 2>/dev/null || true

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

# Any UID must be able to write here (rendered config, tmp)
RUN mkdir -p /tmp/php /home/www-data/website /home/www-data/.composer \
    && chmod 1777 /tmp/php \
    && chown -R www-data:www-data /home/www-data
ENV PHP_RUN_DIR=/tmp/php

WORKDIR /home/www-data/website
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r 'exit(@fsockopen("127.0.0.1", 9900) ? 0 : 1);'

CMD ["php-fpm"]