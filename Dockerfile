FROM php:8.3-cli-bookworm

RUN apt-get update \
    && apt-get install --yes --no-install-recommends git libzip-dev unzip \
    && docker-php-ext-install pdo_mysql zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

CMD ["sh", "-c", "if [ -f artisan ]; then php artisan serve --host=0.0.0.0 --port=8000; else echo 'Run make init to create the Laravel application.'; tail -f /dev/null; fi"]
