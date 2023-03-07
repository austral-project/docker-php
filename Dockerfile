FROM australproject/alpine:3.17
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

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
  nodejs \
  npm

RUN rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

#RUN sed -i 's/#default_bits/default_bits/' /etc/ssl/openssl.cnf
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Init config
COPY config/www.conf /etc/php81/fpm/pool.d/www.conf
COPY config/php-fpm.conf /etc/php81/php-fpm.conf
COPY config/php.ini.conf /etc/php81/php.ini.conf
RUN rm /etc/php81/php.ini


COPY config/docker-entrypoint.sh /
RUN chmod -R 755 docker-entrypoint.sh

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

WORKDIR /home/www-data/website
CMD ["php-fpm81", "--nodaemonize"]