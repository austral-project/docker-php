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

# PHP sources: official release tarball + official php2shell backport (CVE-2026-109618 / CVE-2026-109619),
# plus the PECL extensions. Everything is pinned and verified by sha256.
FROM --platform=$BUILDPLATFORM alpine:3.23 AS php-src
ARG PHP_FULL_VERSION=7.4.33
ARG PHP_SHA256=924846abf93bc613815c55dd3f5809377813ac62a9ec4eb3778675b82a27b927
RUN apk add --no-cache curl xz patch \
 && mkdir -p /src/php /src/pecl \
 && cd /src \
 && { curl -fsSL -o php.tar.xz "https://www.php.net/distributions/php-${PHP_FULL_VERSION}.tar.xz" \
      || curl -fsSL -o php.tar.xz "https://museum.php.net/php7/php-${PHP_FULL_VERSION}.tar.xz"; } \
 && echo "${PHP_SHA256}  php.tar.xz" | sha256sum -c - \
 && tar -xJf php.tar.xz --strip-components=1 -C /src/php \
 && rm php.tar.xz

# Official fix from the PHP security team: branch PHP-7.4-CVE-2026-109618-109619,
# commit 712e60f9e "Avoid state corruption via bailout" (tests excluded). Applied with no fuzz allowed.
COPY patches/php2shell.patch /src/php2shell.patch
RUN cd /src/php \
 && patch -p1 --fuzz=0 < /src/php2shell.patch \
 && touch Zend/zend_vm_def.h && sleep 1 && touch Zend/zend_vm_execute.h \
 && { echo "PHP ${PHP_FULL_VERSION} + php2shell fix (CVE-2026-109618 / CVE-2026-109619)"; \
      echo "fix source: php-src branch PHP-7.4-CVE-2026-109618-109619, commit 712e60f9e"; \
      echo "patch sha256: $(sha256sum /src/php2shell.patch | cut -d' ' -f1)"; } > /src/php2shell.txt

RUN cd /src/pecl \
 && for spec in \
      igbinary-3.2.14:6337147a4fb888072566674837bda9928ee06ee7f0114b4338b86c816232925d \
      msgpack-2.2.0:82aa1e404c5ff54ec41d2a201305cd6594ed14a7529e9119fa7ca457e4bbd12a \
      redis-6.0.2:01aeccb0e14f897fe56f0509be6e6991ff0ad459f9d34e95e4556d02699b9a03 \
      apcu-5.1.24:5c28a55b27082c69657e25b7ecf553e2cf6b74ec3fa77d6b76f4fb982e001e43 \
      imagick-3.7.0:5a364354109029d224bcbb2e82e15b248be9b641227f45e63425c06531792d3e \
      ssh2-1.3.1:9093a1f8d24dc65836027b0e239c50de8d5eaebf8396bc3331fdd38c5d69afd9 \
      uuid-1.2.0:5cb834d32fa7d270494aa47fd96e062ef819df59d247788562695fd1f4e470a4 \
      yaml-2.2.3:5937eb9722ddf6d64626799cfa024598ff2452ea157992e4e67331a253f90236 \
      xdebug-3.1.6:554eca0b4d5b7b93cb2258fab0b0bd84cc8721e74322a2255c14e137cbcad5d2 \
      mcrypt-1.0.7:12ea2fbbf2e2efbe790a12121f77bf096c8b84cef81d0216bec00d56e5badef4 \
      oauth-2.0.9:05fe20322256db62e7bcb5a45693ebc59829eae264f855d5b1438003ab34efe1 \
      ds-1.4.0:a9b930582de8054e2b1a3502bec9d9e064941b5b9b217acc31e4b47f442b93ef \
    ; do \
      name="${spec%%:*}"; sha="${spec##*:}"; \
      curl -fsSL -o "${name}.tgz" "https://pecl.php.net/get/${name}.tgz" \
      && echo "${sha}  ${name}.tgz" | sha256sum -c - \
      || exit 1; \
    done

# Build PHP from source on the same Alpine release as the final image
# (runtime libraries must match), then ship only the installed files.
FROM australproject/alpine:3.15 AS php-build
ENV PHP_VERSION=7

RUN apk update && apk upgrade \
 && apk add --no-cache --virtual .build-deps \
      build-base autoconf pkgconf file linux-headers pax-utils tar \
      argon2-dev aspell-dev bzip2-dev curl-dev enchant2-dev freetype-dev gdbm-dev \
      gettext-dev gmp-dev icu-dev imap-dev krb5-dev libffi-dev \
      libjpeg-turbo-dev libpng-dev libsodium-dev libwebp-dev libxml2-dev libxslt-dev \
      libzip-dev lmdb-dev net-snmp-dev oniguruma-dev openssl-dev pcre2-dev \
      postgresql-dev sqlite-dev tidyhtml-dev zlib-dev \
      imagemagick-dev libmcrypt-dev libssh2-dev util-linux-dev yaml-dev readline-dev

COPY --from=php-src /src /usr/src

# PHP 7.4 only knows Enchant 1 (pkg-config "enchant"); Alpine 3.15 only ships Enchant 2.
# Support for Enchant 2 arrived in PHP 8.0. Minimal bridge, same approach as distro packages:
#  - a pkg-config "enchant" file pointing to enchant-2 (headers and library);
#  - the three C calls renamed or removed in Enchant 2 are replaced one for one
#    (PHP-level function names are unchanged). Each replacement must match, or the build stops.
RUN set -eux; \
    ver="$(pkg-config --modversion enchant-2)"; \
    mkdir -p /usr/lib/pkgconfig; \
    printf '%s\n' \
      'Name: enchant' \
      'Description: bridge to enchant-2 for PHP 7.4' \
      "Version: ${ver}" \
      'Requires: enchant-2' \
      > /usr/lib/pkgconfig/enchant.pc; \
    pkg-config --exists enchant; \
    f=/usr/src/php/ext/enchant/enchant.c; \
    sed -i \
      -e '/{{{ proto/!s/enchant_dict_free_suggestions(/enchant_dict_free_string_list(/' \
      -e '/{{{ proto/!s/\([^_a-z]\)enchant_dict_add_to_personal(/\1enchant_dict_add(/' \
      -e '/{{{ proto/!s/\([^_a-z]\)enchant_dict_is_in_session(/\1enchant_dict_is_added(/' \
      "$f"; \
    test "$(grep -c 'enchant_dict_free_string_list(' "$f")" = 2; \
    test "$(grep -c '[^_a-z]enchant_dict_add(' "$f")" = 1; \
    test "$(grep -c '[^_a-z]enchant_dict_is_added(' "$f")" = 1; \
    if grep -n 'enchant_dict_free_suggestions\|[^_a-z]enchant_dict_add_to_personal(\|[^_a-z]enchant_dict_is_in_session(' "$f" | grep -v 'proto'; then exit 1; fi

# Same layout as the Alpine packages (php81, /etc/php81, /usr/lib/php81/modules ...)
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
      --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
      --with-pgsql --with-pdo-pgsql --with-pdo-sqlite --with-sqlite3 \
      --with-curl --with-openssl --with-zlib --with-bz2 --with-gmp \
      --with-sodium --with-password-argon2 --with-external-pcre \
      --enable-gd --with-jpeg --with-webp --with-freetype \
      --with-zip --with-iconv --with-gettext --with-ffi --with-tidy --with-xmlrpc \
      --with-enchant --with-pspell --with-snmp --with-readline \
      --with-imap --with-imap-ssl --with-kerberos \
      --enable-dba --with-gdbm --with-lmdb \
      --enable-intl --with-xsl --enable-soap \
      --enable-exif --enable-calendar --enable-bcmath --enable-ftp \
      --enable-pcntl --enable-sockets \
      --enable-shmop --enable-sysvmsg --enable-sysvsem --enable-sysvshm; \
    make -j"$(nproc)"; \
    touch /tmp/.php-stamp; sleep 1; \
    make install; \
    test "$(php-config${PHP_VERSION} --extension-dir)" = "/usr/lib/php${PHP_VERSION}/modules"

# PECL extensions (installed with the freshly built PHP, so they match its API)
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
    pecl_build igbinary; \
    pecl_build msgpack; \
    pecl_build redis --enable-redis-igbinary --enable-redis-msgpack; \
    pecl_build apcu; \
    pecl_build imagick; \
    pecl_build ssh2; \
    pecl_build uuid; \
    pecl_build yaml; \
    pecl_build xdebug; \
    pecl_build mcrypt; \
    pecl_build oauth; \
    pecl_build ds; \
    rm -rf /tmp/pecl

# Extension loading: same conf.d mechanism as the Alpine packages.
# Xdebug is installed (.so) but intentionally has no ini: it is enabled on demand (XDEBUG=1) by the entrypoint.
RUN set -eux; \
    conf="/etc/php${PHP_VERSION}/conf.d"; \
    mkdir -p "$conf"; \
    echo "zend_extension=opcache.so" > "$conf/00_opcache.ini"; \
    for ext in igbinary msgpack; do echo "extension=${ext}.so" > "$conf/20_${ext}.ini"; done; \
    for ext in redis apcu imagick ssh2 uuid yaml; do echo "extension=${ext}.so" > "$conf/30_${ext}.ini"; done; \
    for ext in ds mcrypt oauth; do echo "extension=${ext}.so" > "$conf/50_${ext}.ini"; done; \
    for ext in opcache igbinary msgpack redis apcu imagick ssh2 uuid yaml xdebug mcrypt oauth ds; do \
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
    test -x /opt/php-root/usr/bin/php${PHP_VERSION}; \
    test -x /opt/php-root/usr/sbin/php-fpm${PHP_VERSION}; \
    test -f /opt/php-root/usr/lib/php${PHP_VERSION}/modules/opcache.so; \
    find /opt/php-root -type f \( -perm -u+x -o -name '*.so' \) -exec strip --strip-all {} + 2>/dev/null || true; \
    scanelf --needed --nobanner --format '%n#p' --recursive /opt/php-root \
      | tr ',' '\n' | sort -u | awk 'NF { print "so:" $1 }' > /opt/php-rundeps

FROM australproject/alpine:3.15
LABEL maintainer="Matthieu Beurel <matthieu@austral.dev>"
LABEL org.yipikai.php2shell="patched (CVE-2026-109618 / CVE-2026-109619)"

ENV PHP_VERSION=7
ENV PHP_BIN=php-fpm${PHP_VERSION}

RUN apk update && apk upgrade
COPY --from=php-build /opt/php-rundeps /tmp/php-rundeps
RUN apk add --update --no-cache --virtual .php-rundeps $(cat /tmp/php-rundeps) \
    ca-certificates \
    tzdata \
    imagemagick \
    libgomp \
    postgresql-client \
    mysql-client \
    nodejs \
    npm \
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
    for m in ctype session tokenizer mbstring fileinfo simplexml xmlwriter sodium curl json \
             pdo pdo_mysql mysqli pdo_pgsql pgsql pdo_sqlite sqlite3 gd intl xml xmlreader dom xsl xmlrpc \
             soap sockets zip zlib gmp exif openssl iconv pcntl posix phar imap calendar bcmath bz2 \
             dba enchant ftp gettext shmop snmp sysvmsg sysvsem sysvshm pspell readline ffi tidy \
             apcu redis msgpack imagick igbinary ssh2 uuid yaml mcrypt oauth ds "zend opcache"; do \
      grep -qx "$m" /tmp/modules || { echo "Missing PHP extension: $m" >&2; exit 1; }; \
    done; \
    test "$(php -r 'echo ini_get("extension_dir");')" = "/usr/lib/php${PHP_VERSION}/modules"; \
    cat /usr/share/php2shell.txt; \
    rm -f /tmp/modules

RUN export NODE_OPTIONS=--openssl-legacy-provider

# Install npm and squoosh-cli
RUN npm install -g @squoosh/cli
RUN chown -R www-data:www-data /usr/lib/node_modules/

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN echo ${TZ} >  /etc/timezone

# Composer 2
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

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