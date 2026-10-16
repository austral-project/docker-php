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
    && curl -fsSL https://pecl.php.net/get/redis-4.3.0.tgz -o redis.tgz \
    && curl -fsSL https://pecl.php.net/get/msgpack-0.5.7.tgz -o msgpack.tgz \
    && curl -fsSL https://pecl.php.net/get/xdebug-2.5.5.tgz -o xdebug.tgz \
    && curl -fsSL https://pecl.php.net/get/imagick-3.4.4.tgz -o imagick.tgz \
    && curl -fsSL https://pecl.php.net/get/igbinary-2.0.8.tgz -o igbinary.tgz \
    && curl -fsSL https://pecl.php.net/get/oauth-1.2.3.tgz -o oauth.tgz \
    && curl -fsSL https://pecl.php.net/get/ssh2-0.13.tgz -o ssh2.tgz \
    && curl -fsSL https://pecl.php.net/get/uuid-1.0.4.tgz -o uuid.tgz \
    && curl -fsSL https://pecl.php.net/get/yaml-1.3.2.tgz -o yaml.tgz

FROM australproject/alpine:3.7
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

ENV PHP_VERSION=5
ENV PHP_BIN=php-fpm${PHP_VERSION}

RUN apk add --update --no-cache \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-opcache \
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
    php${PHP_VERSION}-mcrypt \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-wddx \
    php${PHP_VERSION}-xmlrpc \
    zlib-dev \
    imagemagick \
    libgomp \
    libssh2 \
    libuuid \
    yaml \
    postgresql-client \
    mariadb-client \
    su-exec \
    gettext \
    && { [ -e /usr/bin/php ] || ln -s /usr/bin/php${PHP_VERSION} /usr/bin/php; } \
    && rm -rf /var/cache/apk/*

# PECL extensions without an Alpine package for this PHP version (pinned in the pecl-src stage)
# redis, msgpack, xdebug and imagick are enabled later via the php.ini template;
# the others get their own conf.d file.
COPY --from=pecl-src /src /tmp/pecl
RUN apk add --no-cache --virtual .build-deps build-base autoconf imagemagick-dev php${PHP_VERSION}-dev libssh2-dev util-linux-dev yaml-dev pcre-dev \
    && cd /tmp/pecl \
    && for ext in redis msgpack xdebug imagick igbinary oauth ssh2 uuid yaml; do \
         mkdir $ext && tar xzf $ext.tgz -C $ext --strip-components=1 \
         && cd $ext && phpize${PHP_VERSION} \
         && ./configure --with-php-config=/usr/bin/php-config${PHP_VERSION} \
         && make -j"$(nproc)" && make install && cd .. \
         && case "$ext" in redis|msgpack|xdebug|imagick) ;; \
              *) echo "extension=${ext}.so" > /etc/php${PHP_VERSION}/conf.d/50_${ext}.ini ;; \
            esac \
         || exit 1; \
       done \
    && apk del .build-deps \
    && rm -rf /tmp/pecl /var/cache/apk/*

# Composer 2.2 LTS
COPY --from=composer:2.2 /usr/bin/composer /usr/local/bin/composer

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