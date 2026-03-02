# Dockerfile.php
FROM australproject/alpine:3.23
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

# Use root for installation
USER root

ENV PHP_VERSION=84
ENV PHP_BIN=php-fpm${PHP_VERSION}

# Default environment variables
ENV SCRIPT_AUTO=1 \
    APP_ENV=prod \
    APP_DEBUG=false \
    PHP_MEMORY_LIMIT=512M \
    PHP_MAX_EXECUTION_TIME=120 \
    PHP_MAX_INPUT_TIME=60 \
    PHP_MAX_INPUT_VARS=5000 \
    XDEBUG=0

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
    && ln -sf /usr/bin/php${PHP_VERSION} /usr/bin/php \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && rm -rf /var/cache/apk/*

# Init config
COPY config/www.conf /etc/php${PHP_VERSION}/fpm/pool.d/www.conf
COPY config/php-fpm.conf config/php.ini.conf /etc/php${PHP_VERSION}/
RUN rm -f /etc/php${PHP_VERSION}/php.ini

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

WORKDIR /home/www-data/website
ENTRYPOINT ["/docker-entrypoint.sh"]

USER www-data
EXPOSE 9900
STOPSIGNAL SIGQUIT
CMD ["sh", "-c", "$PHP_BIN --nodaemonize"]