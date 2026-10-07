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
RUN apk add --update --no-cache php7 \
  php7-pecl-redis \
  php7-common \
  php7-pecl-msgpack \
  php7-pear \
  php7-opcache\
  php7-session \
  php7-cli \
  php7-iconv \
  php7-pcntl \
  php7-fileinfo \
  php7-exif \
  php7-json \
  php7-curl \
  php7-sodium \
  php7-fpm \
  php7-gd \
  php7-gmp \
  php7-imap \
  php7-intl \
  php7-json \
  php7-phar \
  php7-pdo \
  php7-mbstring \
  php7-opcache \
  php7-sqlite3 \
  php7-ctype \
  php7-xml \
  php7-simplexml \
  php7-xsl \
  php7-zip \
  php7-tokenizer \
  php7-openssl \
  php7-xmlwriter \
  php7-xmlreader \
  php7-sockets \
  postgresql-client \
  php7-pdo_pgsql \
  php7-pgsql \
  php7-pdo_mysql\
  php7-pcntl \
  php7-exif \
  nodejs \
  mysql-client \
  npm \
  php7-xdebug \
  gettext \
  su-exec

# Xdebug is installed but only enabled on demand (XDEBUG=1) by the entrypoint
RUN rm -f /etc/php7/conf.d/*xdebug*.ini \
 && rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

#RUN sed -i 's/#default_bits/default_bits/' /etc/ssl/openssl.cnf
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Config templates (rendered at start-up by the entrypoint into /tmp/php)
RUN mkdir -p /usr/local/share/php-templates
COPY config/php.ini.conf config/php-fpm.conf config/www.conf /usr/local/share/php-templates/
# Templates must be readable by any UID (COPY keeps the source file mode)
RUN chmod -R a+rX /usr/local/share/php-templates
# Remove distro configs so only the rendered ones are used
RUN rm -f /etc/php7/php.ini /etc/php7/php-fpm.conf /etc/php7/php-fpm.d/*.conf /etc/php7/fpm/pool.d/*.conf 2>/dev/null || true

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

# Any UID must be able to write here (rendered config, tmp)
RUN mkdir -p /tmp/php /home/www-data/website \
    && chmod 1777 /tmp/php \
    && chown -R www-data:www-data /home/www-data
ENV PHP_VERSION=7
ENV PHP_RUN_DIR=/tmp/php

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r 'exit(@fsockopen("127.0.0.1", 9900) ? 0 : 1);'

WORKDIR /home/www-data/website
CMD ["php-fpm"]
