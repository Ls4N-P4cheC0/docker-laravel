ARG NODE_IMAGE=node:22-bookworm
ARG COMPOSER_IMAGE=composer:2.8.11
ARG PHP_IMAGE=php:8.5-apache-bookworm

FROM ${NODE_IMAGE} AS node_source
FROM ${COMPOSER_IMAGE} AS composer_source

# PHP 8.5 en Debian Bookworm optimizado para Laravel
FROM ${PHP_IMAGE}

ARG PNPM_VERSION=11.15.1
ARG YARN_VERSION=1.22.22

# 1. Instala dependencias del sistema (vía apt-get)
RUN apt-get update && apt-get install -y \
    libicu-dev \
    libonig-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libzip-dev \
    unzip \
    zip \
    7zip \
    git \
    curl \
    tree \
    wget \
    ca-certificates \
    gnupg \
    libnss3 \
    && rm -rf /var/lib/apt/lists/*

# 2. Extrae Node.js directamente desde la imagen oficial (Método optimizado multi-arch)
COPY --from=node_source /usr/local/bin/node /usr/local/bin/node
COPY --from=node_source /usr/local/include/node /usr/local/include/node
COPY --from=node_source /usr/local/lib/node_modules /usr/local/lib/node_modules

# Enlaza npm y npx, e instala versiones fijas de pnpm y yarn
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g pnpm@${PNPM_VERSION} yarn@${YARN_VERSION} \
    && node -v \
    && npm -v \
    && pnpm -v \
    && yarn -v

# 3. Configura e instala extensiones de PHP requeridas por Laravel (incluyendo Redis y pcntl)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mbstring \
    xml \
    intl \
    pdo \
    pdo_mysql \
    mysqli \
    zip \
    bcmath \
    pcntl \
    exif \
    opcache \
    && pecl install redis \
    && docker-php-ext-enable redis

# 4. Instala Composer globalmente de forma optimizada
COPY --from=composer_source /usr/bin/composer /usr/bin/composer

# 5. Habilita el módulo de reescritura de Apache y genera una configuración limpia de VirtualHost con AllowOverride All
RUN a2enmod rewrite \
    && printf '<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog ${APACHE_LOG_DIR}/error.log\n\
    CustomLog ${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>\n' > /etc/apache2/sites-available/000-default.conf

# 6. Establece el directorio de trabajo
WORKDIR /var/www/html

# 7. Ajuste de permisos iniciales para el usuario de Apache
RUN chown -R www-data:www-data /var/www/html
