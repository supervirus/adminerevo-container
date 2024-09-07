FROM php:8.2-alpine

STOPSIGNAL SIGINT

RUN	addgroup -S adminer \
&&	adduser -S -G adminer adminer \
&&	mkdir -p /var/www/html \
&&	mkdir /var/www/html/plugins-enabled \
&&	chown -R adminer:adminer /var/www/html

WORKDIR /var/www/html

RUN	set -x \
&&	apk add --no-cache --virtual .build-deps \
	postgresql-dev \
	sqlite-dev \
	unixodbc-dev \
	freetds-dev \
&&	docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr \
&&	docker-php-ext-install \
	mysqli \
	pdo_pgsql \
	pdo_sqlite \
	pdo_odbc \
	pdo_dblib \
&&	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
&&	apk add --virtual .phpexts-rundeps $runDeps \
&&	apk del --no-network .build-deps

COPY php-conf.d/*.ini /usr/local/etc/php/conf.d/
COPY *.php /var/www/html/
COPY entrypoint.sh /usr/local/bin/

RUN chmod 755 /usr/local/bin/entrypoint.sh

ENV	ADMINER_VERSION=4.8.4
ENV	ADMINER_DOWNLOAD_SHA256=e9a9bc2cc2ac46d6d92f008de9379d2b21a3764a5f8956ed68456e190814b149
ENV	ADMINER_SOURCE_SHA256=7605a124e87556fa33e439f9f0080a0ae4366523e7f32e528f8ecc791859126a
ENV	RMSOFT_THEMES_COMMIT=6f5a850821bcb3145313593bbb6be21f74f7c1c1
ENV	RMSOFT_THEMES_SHA256=ffd8a11fbea5574a47bb4917abc21d2ab5514c6c2a35d82a59e79aa9d25e7ced

RUN	set -x \
&&	curl -fsSL "https://github.com/adminerevo/adminerevo/releases/download/v${ADMINER_VERSION}/adminer-${ADMINER_VERSION}.php" -o adminer.php \
&&	echo "${ADMINER_DOWNLOAD_SHA256}  adminer.php" | sha256sum -c - \
&&	curl -fsSL "https://github.com/adminerevo/adminerevo/archive/refs/tags/v${ADMINER_VERSION}.tar.gz" -o /tmp/adminer.tar.gz \
&&	echo "${ADMINER_SOURCE_SHA256}  /tmp/adminer.tar.gz" | sha256sum -c - \
&&  tar --strip-components=1 -xf /tmp/adminer.tar.gz adminerevo-${ADMINER_VERSION}/designs adminerevo-${ADMINER_VERSION}/plugins \
&&  rm /tmp/adminer.tar.gz \
&&	curl -fsSL "https://github.com/mesaros/adminerevo-theme-rmsoft/archive/${RMSOFT_THEMES_COMMIT}.tar.gz" -o /tmp/rmsoft.tar.gz \
&&	echo "${RMSOFT_THEMES_SHA256}  /tmp/rmsoft.tar.gz" | sha256sum -c - \
&&  mkdir -p designs/rmsoft \
&&  tar --strip-components=2 -C designs/rmsoft -xf /tmp/rmsoft.tar.gz adminerevo-theme-rmsoft-${RMSOFT_THEMES_COMMIT}/designs \
&&  rm /tmp/rmsoft.tar.gz \
&&	chown -R adminer:adminer /var/www/html

ENTRYPOINT [ "entrypoint.sh", "docker-php-entrypoint" ]

USER adminer
CMD	[ "php", "-S", "[::]:8080", "-t", "/var/www/html" ]

EXPOSE 8080
