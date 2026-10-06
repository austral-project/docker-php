FROM alpine:3.23 AS supercronic
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
RUN apk add --no-cache curl \
 && curl -fsSL -o /supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /supercronic" | sha256sum -c - \
 && chmod +x /supercronic

FROM australproject/alpine:3.15
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

RUN apk update && apk upgrade
RUN apk add --update --no-cache php8 \
  php8-pecl-redis \
  php8-common \
  php8-pecl-msgpack \
  php8-pear \
  php8-opcache\
  php8-session \
  php8-cli \
  php8-iconv \
  php8-pcntl \
  php8-fileinfo \
  php8-exif \
  php8-json \
  php8-curl \
  php8-sodium \
  php8-fpm \
  php8-gd \
  php8-gmp \
  php8-imap \
  php8-intl \
  php8-json \
  php8-phar \
  php8-pdo \
  php8-mbstring \
  php8-opcache \
  php8-sqlite3 \
  php8-ctype \
  php8-xml \
  php8-simplexml \
  php8-xsl \
  php8-zip \
  php8-tokenizer \
  php8-openssl \
  php8-xmlwriter \
  php8-xmlreader \
  php8-sockets \
  postgresql-client \
  php8-pdo_pgsql \
  php8-pgsql \
  php8-pdo_mysql\
  php8-pcntl \
  php8-exif \
  nodejs \
  mysql-client \
  npm \
  php8-xdebug \
  gettext \
  su-exec

# Xdebug is installed but only enabled on demand (XDEBUG=1) by the entrypoint
RUN rm -f /etc/php8/conf.d/*xdebug*.ini \
 && rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

RUN ln -s /usr/bin/php8 /usr/bin/php
RUN ln -s /usr/bin/phar8 /usr/bin/phar

#RUN sed -i 's/#default_bits/default_bits/' /etc/ssl/openssl.cnf
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Config templates (rendered at start-up by the entrypoint into /tmp/php)
RUN mkdir -p /usr/local/share/php-templates
COPY config/php.ini.conf config/php-fpm.conf config/www.conf /usr/local/share/php-templates/
# Templates must be readable by any UID (COPY keeps the source file mode)
RUN chmod -R a+rX /usr/local/share/php-templates
# Remove distro configs so only the rendered ones are used
RUN rm -f /etc/php8/php.ini /etc/php8/php-fpm.conf /etc/php8/php-fpm.d/*.conf /etc/php8/fpm/pool.d/*.conf 2>/dev/null || true

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

# Any UID must be able to write here (rendered config, tmp)
RUN mkdir -p /tmp/php /home/www-data/website \
    && chmod 1777 /tmp/php \
    && chown -R www-data:www-data /home/www-data
ENV PHP_VERSION=8
ENV PHP_RUN_DIR=/tmp/php

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r 'exit(@fsockopen("127.0.0.1", 9900) ? 0 : 1);'

WORKDIR /home/www-data/website
CMD ["php-fpm"]
