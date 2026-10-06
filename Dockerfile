FROM alpine:3.23 AS supercronic
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
RUN apk add --no-cache curl \
 && curl -fsSL -o /supercronic \
    "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
 && echo "${SUPERCRONIC_SHA256}  /supercronic" | sha256sum -c - \
 && chmod +x /supercronic

FROM australproject/alpine:3.20
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

ENV SCRIPT_AUTO=1

RUN apk update && apk upgrade
RUN apk add --update --no-cache php82 \
  php82-pecl-redis \
  php82-common \
  php82-pecl-msgpack \
  php82-pear \
  php82-opcache\
  php82-session \
  php82-cli \
  php82-iconv \
  php82-pcntl \
  php82-fileinfo \
  php82-exif \
  php82-json \
  php82-curl \
  php82-sodium \
  php82-soap \
  php82-fpm \
  php82-gd \
  php82-gmp \
  php82-imap \
  php82-intl \
  php82-json \
  php82-phar \
  php82-pdo \
  php82-mbstring \
  php82-opcache \
  php82-sqlite3 \
  php82-ctype \
  php82-xml \
  php82-simplexml \
  php82-xsl \
  php82-zip \
  php82-tokenizer \
  php82-openssl \
  php82-xmlwriter \
  php82-xmlreader \
  php82-sockets \
  php82-pdo_pgsql \
  php82-pgsql \
  php82-pdo_mysql\
  php82-pcntl \
  php82-exif \
  postgresql16-client \
  mysql-client \
  nodejs \
  npm \
  php82-xdebug \
  gettext \
  su-exec


#RUN apk add --update --no-cache nodejs=16.20.2-r0 --repository=http://dl-cdn.alpinelinux.org/alpine/v3.15/main  \
#  npm=8.1.3-r0 --repository=http://dl-cdn.alpinelinux.org/alpine/v3.15/main

RUN export NODE_OPTIONS=--openssl-legacy-provider
# Xdebug is installed but only enabled on demand (XDEBUG=1) by the entrypoint
RUN rm -f /etc/php82/conf.d/*xdebug*.ini \
 && rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

# Create php executable
RUN ln -s /usr/bin/php82 /usr/bin/php

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
RUN rm -f /etc/php82/php.ini /etc/php82/php-fpm.conf /etc/php82/php-fpm.d/*.conf /etc/php82/fpm/pool.d/*.conf 2>/dev/null || true

COPY --from=supercronic /supercronic /usr/local/bin/supercronic

COPY config/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 0755 /docker-entrypoint.sh

# Any UID must be able to write here (rendered config, tmp)
RUN mkdir -p /tmp/php /home/www-data/website \
    && chmod 1777 /tmp/php \
    && chown -R www-data:www-data /home/www-data
ENV PHP_VERSION=82
ENV PHP_RUN_DIR=/tmp/php

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD php -r 'exit(@fsockopen("127.0.0.1", 9900) ? 0 : 1);'

WORKDIR /home/www-data/website
CMD ["php-fpm"]
