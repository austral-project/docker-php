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
  npm


#RUN apk add --update --no-cache nodejs=16.20.2-r0 --repository=http://dl-cdn.alpinelinux.org/alpine/v3.15/main  \
#  npm=8.1.3-r0 --repository=http://dl-cdn.alpinelinux.org/alpine/v3.15/main

RUN export NODE_OPTIONS=--openssl-legacy-provider
RUN rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

# Create php executable
RUN ln -s /usr/bin/php82 /usr/bin/php

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

#RUN sed -i 's/#default_bits/default_bits/' /etc/ssl/openssl.cnf
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Init config
COPY config/www.conf /etc/php82/fpm/pool.d/www.conf
COPY config/php-fpm.conf /etc/php82/php-fpm.conf
COPY config/php.ini.conf /etc/php82/php.ini.conf
RUN rm /etc/php82/php.ini

COPY config/docker-entrypoint.sh /
RUN chmod -R 755 docker-entrypoint.sh

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

WORKDIR /home/www-data/website
CMD ["php-fpm81", "--nodaemonize"]