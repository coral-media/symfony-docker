ARG PHP_VERSION=8.1

FROM php:${PHP_VERSION}-fpm as php

RUN apt update \
    && apt install -y libxslt1-dev zlib1g-dev g++ git libicu-dev zip libzip-dev zip nfs4-acl-tools acl gnupg2 \
    && docker-php-ext-install intl opcache pdo pdo_mysql \
    && docker-php-ext-install xsl \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip \
    && apt-get remove -y libxslt1-dev icu-devtools libicu-dev libxml2-dev  \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash -

RUN apt update \
    && apt install -y yarn \
    && apt install -y nodejs

COPY docker/php/docker-healthcheck.sh /usr/local/bin/docker-healthcheck
RUN chmod +x /usr/local/bin/docker-healthcheck

HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["docker-healthcheck"]

WORKDIR /srv/app

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
ENV COMPOSER_ALLOW_SUPERUSER=1

ARG SKELETON="symfony/skeleton"
ENV SKELETON ${SKELETON}

ARG STABILITY="stable"
ENV STABILITY ${STABILITY}

ARG SYMFONY_VERSION=""
ENV SYMFONY_VERSION ${SYMFONY_VERSION}

COPY docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

RUN composer create-project "${SKELETON} ${SYMFONY_VERSION}" . --stability=$STABILITY --prefer-dist --no-dev --no-progress --no-interaction; \
	composer clear-cache

RUN git config --global user.email "${DEVELOPER_EMAIL}" \
    && git config --global user.name "${DEVELOPER_USER}"

COPY . .

RUN set -eux; \
	mkdir -p var/cache var/log; \
	composer install --prefer-dist --no-dev --no-progress --no-scripts --no-interaction; \
	composer dump-autoload --classmap-authoritative --no-dev; \
	composer symfony:dump-env prod; \
	composer run-script --no-dev post-install-cmd; \
	chmod +x bin/console; sync

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]
