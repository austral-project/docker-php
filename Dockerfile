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

# PHP sources: official 5.6.40 release tarball + a php2shell patch, plus the PECL extensions.
# Everything downloaded is pinned and verified by sha256.
#
# The PHP team published NO php2shell fix for 5.6 (its backports stop at 7.4; the 7.4 patch fails on 5.6).
# patches/php2shell.patch is the UNOFFICIAL port made by Debian/Sury (patch 0261, from php5.6 5.6.40-105),
# written by a PHP core developer, as republished in github.com/nsrivastava2velsof/php56-php2shell-patch (MIT).
# Its sha256 is pinned below; the build fails if the file is missing, empty or different, so an unpatched
# or unreviewed 5.6 can never be built by mistake. To use another patch, change PATCH_SHA256 on purpose.
FROM --platform=$BUILDPLATFORM alpine:3.23 AS php-src
ARG PHP_FULL_VERSION=5.6.40
ARG PHP_SHA256=1369a51eee3995d7fbd1c5342e5cc917760e276d561595b6052b21ace2656d1c
ARG PATCH_SHA256=d945982b5ab29bc5c42d1892750d72d39ae911df8b9f4f5ea47d133707ab72a4
RUN apk add --no-cache curl xz patch \
 && mkdir -p /src/php /src/pecl \
 && cd /src \
 && { curl -fsSL -o php.tar.xz "https://www.php.net/distributions/php-${PHP_FULL_VERSION}.tar.xz" \
      || curl -fsSL -o php.tar.xz "https://museum.php.net/php5/php-${PHP_FULL_VERSION}.tar.xz"; } \
 && echo "${PHP_SHA256}  php.tar.xz" | sha256sum -c - \
 && tar -xJf php.tar.xz --strip-components=1 -C /src/php \
 && rm php.tar.xz

COPY patches/ /src/patches/
RUN if [ ! -s /src/patches/php2shell.patch ]; then \
      echo "ERROR: patches/php2shell.patch is missing or empty (see patches/README.md)." >&2; \
      exit 1; \
    fi \
 && echo "${PATCH_SHA256}  /src/patches/php2shell.patch" | sha256sum -c - \
 && cd /src/php \
 && patch -p1 --fuzz=0 < /src/patches/php2shell.patch \
 && touch Zend/zend_vm_def.h && sleep 1 && touch Zend/zend_vm_execute.h \
 && { echo "PHP ${PHP_FULL_VERSION} + php2shell patch (CVE-2026-109618 / CVE-2026-109619)"; \
      echo "UNOFFICIAL: port of Debian/Sury patch 0261 (php5.6 5.6.40-105); no upstream fix exists for 5.6"; \
      echo "patch sha256: $(sha256sum /src/patches/php2shell.patch | cut -d' ' -f1)"; } > /src/php2shell.txt

RUN cd /src/pecl \
 && for spec in \
      redis-4.3.0:c0f04cec349960a842b60920fb8a433656e2e494eaed6e663397d67102a51ba2 \
      msgpack-0.5.7:b8ee20cd0a79426c1abd55d5bbae85e5dcfbe0238abf9ce300685fbe76d94cdf \
      xdebug-2.5.5:72108bf2bc514ee7198e10466a0fedcac3df9bbc5bd26ce2ec2dafab990bf1a4 \
      imagick-3.4.4:8dd5aa16465c218651fc8993e1faecd982e6a597870fd4b937e9ece02d567077 \
      igbinary-2.0.8:bacbab1172e073b1857dc07a486bfdaca6d60fbed678ce0f4b37cd018ef5b680 \
      oauth-1.2.3:86bb5ee37afe672d4532ad784c7f711855c79f0dabf0acacafd5344ab6cf0195 \
      ssh2-0.13:cb2cb8ab840b5b36bcd8a8df06ea4a970a61e4cb3980f3c0ac5c913522e6c1be \
      uuid-1.0.4:63079b6a62a9d43691ecbcd4eb52e5e5fe17b5a3d0f8e46e3c17ff265c06a11f \
      yaml-1.3.2:5a8ed1b776e099c0dd8615b919ae3d6bc774c4ba04c2609a0f6e3877c72e599a \
      apcu-4.0.11:454f302ec13a6047ca4c39e081217ce5a61bbea815aec9c1091fb849e70b4d00 \
    ; do \
      name="${spec%%:*}"; sha="${spec##*:}"; \
      curl -fsSL -o "${name}.tgz" "https://pecl.php.net/get/${name}.tgz" \
      && echo "${sha}  ${name}.tgz" | sha256sum -c - \
      || exit 1; \
    done

# Build PHP from source on the same Alpine release as the final image
# (runtime libraries must match), then ship only the installed files.
FROM australproject/alpine:3.7 AS php-build
ENV PHP_VERSION=5

# Alpine 3.7 uses LibreSSL as its default TLS library (curl, imap...): build PHP against the
# same one so that a single libssl ends up in the process. Switch to openssl-dev only if the
# base image really ships OpenSSL.
ARG SSL_DEV=libressl-dev
RUN apk add --update --no-cache --virtual .build-deps \
      build-base autoconf pkgconf file linux-headers pax-utils tar \
      ${SSL_DEV} \
      aspell-dev bzip2-dev curl-dev enchant-dev freetype-dev gdbm-dev \
      gettext-dev gmp-dev icu-dev imap-dev libjpeg-turbo-dev libpng-dev \
      libxml2-dev libxslt-dev net-snmp-dev postgresql-dev sqlite-dev zlib-dev \
      imagemagick-dev libmcrypt-dev libssh2-dev util-linux-dev yaml-dev pcre-dev readline-dev

COPY --from=php-src /src /usr/src

# Same layout as the Alpine packages (php5, /etc/php5, /usr/lib/php5/modules ...)
# so the entrypoint and the config templates keep working unchanged.
RUN set -eux; \
    cd /usr/src/php; \
    export CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"; \
    export CPPFLAGS="$CFLAGS"; \
    export LDFLAGS="-Wl,-O1 -pie"; \
    export EXTENSION_DIR="/usr/lib/php${PHP_VERSION}/modules"; \
    ./configure \
      --prefix=/usr \
      --sysconfdir=/etc/php${PHP_VERSION} \
      --localstatedir=/var \
      --libdir=/usr/lib/php${PHP_VERSION} \
      --datadir=/usr/share/php${PHP_VERSION} \
      --program-suffix=${PHP_VERSION} \
      --with-config-file-path=/etc/php${PHP_VERSION} \
      --with-config-file-scan-dir=/etc/php${PHP_VERSION}/conf.d \
      --with-pic --disable-rpath --disable-cgi --disable-phpdbg --without-pear \
      --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data \
      --enable-opcache \
      --enable-mbstring --enable-mbregex \
      --enable-mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
      --with-pgsql=/usr --with-pdo-pgsql=/usr --with-pdo-sqlite=/usr --with-sqlite3=/usr \
      --with-curl=/usr --with-openssl=/usr --with-zlib=/usr --with-bz2=/usr --with-gmp=/usr \
      --with-libxml-dir=/usr --enable-dom --enable-simplexml --enable-xml --enable-xmlreader --enable-xmlwriter \
      --with-xsl=/usr --enable-soap --with-xmlrpc --enable-wddx \
      --with-gd --with-jpeg-dir=/usr --with-png-dir=/usr --with-freetype-dir=/usr \
      --enable-zip --with-iconv --with-gettext=/usr --with-mcrypt=/usr \
      --with-enchant=/usr --with-pspell=/usr --with-snmp=/usr --with-readline=/usr \
      --with-imap=/usr --with-imap-ssl=/usr \
      --enable-dba --with-gdbm=/usr \
      --enable-intl --with-icu-dir=/usr \
      --enable-exif --enable-calendar --enable-bcmath --enable-ftp \
      --enable-pcntl --enable-sockets \
      --enable-shmop --enable-sysvmsg --enable-sysvsem --enable-sysvshm; \
    make -j"$(nproc)"; \
    touch /tmp/.php-stamp; sleep 1; \
    make install; \
    test "$(php-config${PHP_VERSION} --extension-dir)" = "/usr/lib/php${PHP_VERSION}/modules"

# PECL extensions (installed with the freshly built PHP, so they match its API).
# Same versions as the previous image, plus apcu 4.x (the last branch supporting PHP 5).
RUN set -eux; \
    pecl_build() { \
      ext="$1"; shift; \
      mkdir -p "/tmp/pecl/$ext"; \
      tar -xzf /usr/src/pecl/"$ext"-*.tgz -C "/tmp/pecl/$ext" --strip-components=1; \
      cd "/tmp/pecl/$ext"; \
      phpize${PHP_VERSION}; \
      ./configure --with-php-config=/usr/bin/php-config${PHP_VERSION} "$@"; \
      make -j"$(nproc)"; \
      make install; \
      cd /; \
    }; \
    for ext in redis msgpack xdebug imagick igbinary oauth ssh2 uuid yaml apcu; do \
      pecl_build "$ext"; \
    done; \
    rm -rf /tmp/pecl

# Extension loading, as in the previous image:
# redis, msgpack, xdebug and imagick are enabled via the php.ini template; the others get their own conf.d file.
RUN set -eux; \
    conf="/etc/php${PHP_VERSION}/conf.d"; \
    mkdir -p "$conf"; \
    echo "zend_extension=opcache.so" > "$conf/00_opcache.ini"; \
    for ext in igbinary oauth ssh2 uuid yaml apcu; do echo "extension=${ext}.so" > "$conf/50_${ext}.ini"; done; \
    for ext in opcache redis msgpack xdebug imagick igbinary oauth ssh2 uuid yaml apcu; do \
      test -f "/usr/lib/php${PHP_VERSION}/modules/${ext}.so"; \
    done

# Keep only what is installed by PHP + PECL (everything newer than the stamp), drop dev files, strip, compute runtime deps
RUN set -eux; \
    rm -rf /usr/include/php /usr/lib/php${PHP_VERSION}/build /usr/share/man \
           /usr/bin/phpize${PHP_VERSION} /usr/bin/php-config${PHP_VERSION}; \
    mkdir -p /opt/php-root; \
    find /usr /etc/php${PHP_VERSION} -xdev \( -path /usr/src -prune \) -o \( \( -type f -o -type l \) -newer /tmp/.php-stamp -print0 \) \
      | tar --null -T - -cf - | tar -xf - -C /opt/php-root; \
    mkdir -p /opt/php-root/usr/share; \
    cp /usr/src/php2shell.txt /opt/php-root/usr/share/php2shell.txt; \
    mkdir -p /opt/php-root/etc/php${PHP_VERSION}/conf.d; \
    { echo "; Marker only, no setting. Its file name shows in phpinfo() / php --ini (Additional .ini files parsed)."; \
      sed 's/^/; /' /usr/src/php2shell.txt; } > /opt/php-root/etc/php${PHP_VERSION}/conf.d/99_php2shell_patched.ini; \
    test -x /opt/php-root/usr/bin/php${PHP_VERSION}; \
    test -x /opt/php-root/usr/sbin/php-fpm${PHP_VERSION}; \
    test -f /opt/php-root/usr/lib/php${PHP_VERSION}/modules/opcache.so; \
    find /opt/php-root -type f \( -perm -u+x -o -name '*.so' \) -exec strip --strip-all {} + 2>/dev/null || true; \
    scanelf --needed --nobanner --format '%n#p' --recursive /opt/php-root \
      | tr ',' '\n' | sort -u | awk 'NF { print "so:" $1 }' > /opt/php-rundeps

FROM australproject/alpine:3.7
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"
LABEL org.yipikai.php2shell="unofficial port (Debian/Sury 0261) - no upstream fix for PHP 5.6"

ENV PHP_VERSION=5
ENV PHP_BIN=php-fpm${PHP_VERSION}

COPY --from=php-build /opt/php-rundeps /tmp/php-rundeps
RUN apk add --update --no-cache --virtual .php-rundeps $(cat /tmp/php-rundeps) \
    ca-certificates \
    tzdata \
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
    && rm -f /tmp/php-rundeps \
    && rm -rf /var/cache/apk/*

# PHP built from patched sources (see php-build stage)
COPY --from=php-build /opt/php-root/ /
RUN { [ -e /usr/bin/php ] || ln -s /usr/bin/php${PHP_VERSION} /usr/bin/php; }

# Build-time sanity check: every extension of the previous apk-based image must be present
RUN set -eux; \
    php -v; \
    php-fpm${PHP_VERSION} -v; \
    php -m | tr 'A-Z' 'a-z' | sort -u > /tmp/modules; \
    for m in json pdo pdo_mysql mysqli mysql pdo_pgsql pgsql pdo_sqlite sqlite3 gd intl xml xmlreader dom xsl \
             ctype soap sockets zip zlib gmp exif openssl iconv pcntl posix phar imap calendar bcmath bz2 \
             dba enchant ftp gettext shmop snmp sysvmsg sysvsem sysvshm pspell readline mcrypt wddx xmlrpc \
             mbstring session tokenizer simplexml xmlwriter fileinfo \
             apcu igbinary oauth ssh2 uuid yaml "zend opcache"; do \
      grep -qx "$m" /tmp/modules || { echo "Missing PHP extension: $m" >&2; exit 1; }; \
    done; \
    for f in redis msgpack xdebug imagick; do test -f "/usr/lib/php${PHP_VERSION}/modules/$f.so"; done; \
    test "$(php -r 'echo ini_get("extension_dir");')" = "/usr/lib/php${PHP_VERSION}/modules"; \
    cat /usr/share/php2shell.txt; \
    rm -f /tmp/modules

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