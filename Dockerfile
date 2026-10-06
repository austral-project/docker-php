FROM alpine:3.23 AS supercronic
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
RUN apk add --no-cache curl \
 && curl -fsSL -o /supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /supercronic" | sha256sum -c - \
 && chmod +x /supercronic

FROM australproject/alpine:3.23
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

ENV PHP_VERSION=84

# Install PHP 8.4 and required extensions
RUN apk add --update --no-cache \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-json \
    php${PHP_VERSION}-pdo \
    php${PHP_VERSION}-pdo_mysql \
    php${PHP_VERSION}-pdo_pgsql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-xmlwriter \
    php${PHP_VERSION}-xmlreader \
    php${PHP_VERSION}-ctype \
    php${PHP_VERSION}-session \
    php${PHP_VERSION}-tokenizer \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-sockets \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gmp \
    php${PHP_VERSION}-exif \
    php${PHP_VERSION}-openssl \
    php${PHP_VERSION}-pecl-redis \
    php${PHP_VERSION}-pecl-msgpack \
    php${PHP_VERSION}-pear \
    php${PHP_VERSION}-iconv \
    php${PHP_VERSION}-pcntl \
    php${PHP_VERSION}-fileinfo \
    php${PHP_VERSION}-sodium \
    php${PHP_VERSION}-imap \
    php${PHP_VERSION}-phar \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-simplexml \
    php${PHP_VERSION}-xsl \
    postgresql16-client \
    mysql-client \
    bash \
    curl \
    su-exec \
    gettext \
    php${PHP_VERSION}-xdebug \
    && ln -sf /usr/bin/php${PHP_VERSION} /usr/bin/php \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -f /etc/php${PHP_VERSION}/conf.d/*xdebug*.ini \
    && rm -rf /var/cache/apk/*

# Config templates (rendered at start-up by the entrypoint into /tmp/php)
RUN mkdir -p /usr/local/share/php-templates
COPY config/php.ini.conf config/php-fpm.conf config/www.conf /usr/local/share/php-templates/
# Remove distro configs so only the rendered ones are used
RUN rm -f /etc/php${PHP_VERSION}/php.ini /etc/php${PHP_VERSION}/php-fpm.conf /etc/php${PHP_VERSION}/php-fpm.d/*.conf /etc/php${PHP_VERSION}/fpm/pool.d/*.conf 2>/dev/null || true

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

# Any UID must be able to write here (rendered config, tmp)
RUN mkdir -p /tmp/php /home/www-data/website \
    && chmod 1777 /tmp/php \
    && chown -R www-data:www-data /home/www-data
ENV PHP_RUN_DIR=/tmp/php

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r 'exit(@fsockopen("127.0.0.1", 9900) ? 0 : 1);'

WORKDIR /home/www-data/website
CMD ["php-fpm"]
