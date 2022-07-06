FROM australproject/alpine:3.15
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"

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
  nodejs \
  npm

RUN rm -rf /var/cache/apk/*

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

RUN ln -s /usr/bin/php8 /usr/bin/php
RUN ln -s /usr/bin/phar8 /usr/bin/phar

#RUN sed -i 's/#default_bits/default_bits/' /etc/ssl/openssl.cnf
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Init config
COPY config/www.conf /etc/php8/fpm/pool.d/www.conf
COPY config/php-fpm.conf /etc/php8/php-fpm.conf
COPY config/php.ini.conf /etc/php8/php.ini.conf
RUN rm /etc/php8/php.ini


COPY config/docker-entrypoint.sh /
RUN chmod -R 755 docker-entrypoint.sh

#  Init Workdir, Entrypoint, CMD
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 9900
STOPSIGNAL SIGQUIT

WORKDIR /home/www-data/website
CMD ["php-fpm8", "--nodaemonize"]