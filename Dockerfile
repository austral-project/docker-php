# Dockerfile.php
FROM alpine:3.7 AS supercronic
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
RUN apk add --no-cache curl \
 && curl -fsSL -o /supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /supercronic" | sha256sum -c - \
 && chmod +x /supercronic

FROM alpine:3.23 AS pecl-src
RUN apk add --no-cache curl \
    && mkdir /src && cd /src \
    && curl -fsSL https://pecl.php.net/get/redis-4.3.0.tgz     -o redis.tgz \
    && curl -fsSL https://pecl.php.net/get/msgpack-0.5.7.tgz   -o msgpack.tgz \
    && curl -fsSL https://pecl.php.net/get/xdebug-2.5.5.tgz    -o xdebug.tgz \
    && curl -fsSL https://pecl.php.net/get/imagick-3.4.4.tgz   -o imagick.tgz

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
    php${PHP_VERSION}-pdo_pgsql \
    php${PHP_VERSION}-pdo_sqlite \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-mysqli \
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
    php${PHP_VERSION}-gmp \
    php${PHP_VERSION}-exif \
    php${PHP_VERSION}-openssl \
    php${PHP_VERSION}-iconv \
    php${PHP_VERSION}-pcntl \
    php${PHP_VERSION}-posix \
    php${PHP_VERSION}-phar \
    php${PHP_VERSION}-imap \
    imagemagick \
    libgomp \
    postgresql-client \
    mariadb-client \
    su-exec \
    && ln -sf /usr/bin/php${PHP_VERSION} /usr/bin/php \
    && rm -rf /var/cache/apk/*

# Extensions PECL compilées (redis, msgpack, xdebug) – activées plus tard via ini
COPY --from=pecl-src /src /tmp/pecl
RUN apk add --no-cache --virtual .build-deps build-base autoconf imagemagick-dev php${PHP_VERSION}-dev \
    && cd /tmp/pecl \
    && for ext in redis msgpack xdebug imagick; do \
         mkdir $ext && tar xzf $ext.tgz -C $ext --strip-components=1 \
         && cd $ext && phpize${PHP_VERSION} \
         && ./configure --with-php-config=/usr/bin/php-config${PHP_VERSION} \
         && make -j"$(nproc)" && make install && cd ..; \
       done \
    && apk del .build-deps \
    && rm -rf /tmp/pecl /var/cache/apk/*

# Composer 2.2 LTS
COPY --from=composer:2.2 /usr/bin/composer /usr/local/bin/composer

# Config
RUN mkdir -p /etc/php${PHP_VERSION}/fpm/pool.d
COPY config/www.conf /etc/php${PHP_VERSION}/fpm/pool.d/www.conf
COPY config/php-fpm.conf config/php.ini.conf /etc/php${PHP_VERSION}/
RUN rm -f /etc/php${PHP_VERSION}/php.ini

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

RUN chmod +x /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

RUN mkdir -p /home/www-data/.composer \
    && chown -R www-data:www-data /home/www-data

WORKDIR /home/www-data/website
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT
CMD ["sh", "-c", "$PHP_BIN --nodaemonize"]