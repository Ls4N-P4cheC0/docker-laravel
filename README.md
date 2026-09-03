# Soporte de Configuración Docker para Laravel

Este documento resume la arquitectura y configuración del entorno Docker optimizado para **Laravel**, incluyendo **PHP 8.5** (o configurable), **MySQL 8.4 LTS**, **Redis**, **Mailpit** y **phpMyAdmin**.

---

## 🏗️ Resumen de Servicios y Puertos

| Servicio | Nombre Contenedor | Puerto Host Configurable | Variable en `.env` | Descripción / Propósito |
| :--- | :--- | :--- | :--- | :--- |
| **Laravel Web** | `laravel-web` | **8090** | `APP_PORT` | Apache + PHP 8.5 (DocumentRoot: `/var/www/html/public`) |
| **Vite Dev Server** | `laravel-web` | **5174** | `VITE_PORT` | Servidor HMR de Vite para CSS/JS (`npm run dev`) |
| **MySQL 8.4** | `laravel-db` | **33084** | `FORWARD_DB_PORT` | Base de Datos MySQL 8.4 LTS |
| **phpMyAdmin** | `laravel-phpmyadmin` | **8094** | `PHPMYADMIN_PORT` | Administrador visual de base de datos |
| **Redis** | `laravel-redis` | **63795** | `FORWARD_REDIS_PORT` | Servidor en memoria para Caché, Sesiones y Colas |
| **Mailpit Web** | `laravel-mailpit` | **8026** | `FORWARD_MAILPIT_PORT` | Interfaz Web para inspección de correos en desarrollo |
| **Mailpit SMTP** | `laravel-mailpit` | **1026** | `FORWARD_MAILPIT_SMTP_PORT` | Servidor SMTP local capturador de e-mails |

---

## 📁 Archivos de Configuración

### 1. `Dockerfile`
- **Imagen Base**: `php:8.5-apache-bookworm` (Configurable vía `PHP_IMAGE` en `.env`; para máxima estabilidad con librerías de terceros se puede utilizar `php:8.3-apache-bookworm` o `php:8.4-apache-bookworm`).
- **Laravel Apache Setup**: Redirige el `DocumentRoot` a `/var/www/html/public` y habilita `a2enmod rewrite` para procesar archivos `.htaccess`.
- **Extensiones PHP**: Instala `pdo_mysql`, `mbstring`, `intl`, `gd`, `zip`, `bcmath`, `pcntl` (necesario para colas con `artisan queue:work`), `exif` (metadatos de imágenes), `opcache` y la extensión `redis` de PECL.
- **Herramientas de Desarrollo**: Copia los binarios de **Node.js (v22)** y **Composer (v2.8)** mediante multi-stage build, e instala **pnpm** y **yarn**.

### 2. `docker-compose.yml`
Orquesta los 5 servicios interconectados a través de la red `mi_red_desarrollo`:
- `web`: Aplica la construcción desde `Dockerfile`.
- `db`: Utiliza la imagen oficial `mysql:8.4` (LTS).
- `phpmyadmin`: Conectado automáticamente al host `db`.
- `redis`: Utiliza la imagen `redis:7-alpine`.
- `mailpit`: Utiliza la imagen `axllent/mailpit`.

### 3. `.env` & `.env.example`
Centraliza la parametrización de puertos, versiones de imágenes y credenciales de la base de datos MySQL.

---

## 💻 Desarrollo con VS Code (Dev Containers)

Este repositorio incluye configuración lista en [`.devcontainer/devcontainer.json`](file:///.devcontainer/devcontainer.json) para desarrollar directamente dentro del contenedor `laravel-web`, disponiendo de extensiones de PHP, Laravel, Tailwind y Node preinstaladas.

### ¿Cómo abrir el entorno en el contenedor?

1. Abre la carpeta del proyecto en **Visual Studio Code**.
2. Asegúrate de tener instalada la extensión oficial **Dev Containers** (`ms-vscode-remote.remote-containers`).
3. Abre la paleta de comandos de VS Code según tu sistema operativo:
   - **En macOS**: Presiona `Cmd + Shift + P`
   - **En Windows / Linux**: Presiona `Ctrl + Shift + P`
   *(Alternativamente, haz clic en el ícono verde/azul `><` en la esquina inferior izquierda de VS Code)*.
4. Escribe y selecciona:
   ```text
   Dev Containers: Reopen in Container
   ```
   *(o en español: `Dev Containers: Reabrir en contenedor`)*.
5. VS Code se conectará al contenedor `laravel-web`. El terminal integrado estará ubicado en `/var/www/html` con acceso directo a `php`, `composer`, `artisan`, `npm` y `node`.

---

## ⚙️ Configuración en el `.env` de Laravel

Cuando instales o configures tu proyecto Laravel en la carpeta `./app`, utiliza estos valores en el `.env` de tu Laravel:

```env
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost:8090

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel_user
DB_PASSWORD=laravel_pass

CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"
```

---

## 🛠️ Comandos de Uso Frecuente

### Construir e Iniciar el Entorno
```bash
# 1. Crear la red externa de Docker si no existe
docker network create mi_red_desarrollo

# 2. Construir la imagen web
docker compose build --no-cache web

# 3. Levantar todos los servicios en segundo plano
docker compose up -d
```

### Trabajar con Laravel (`artisan`, `composer`, `npm`)

```bash
# Entrar al terminal interactivo del contenedor web
docker exec -it laravel-web bash

# Ajustar permisos para storage y bootstrap/cache (ejecutar tras crear o clonar el proyecto)
docker exec -it laravel-web chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
docker exec -it laravel-web chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Ejecutar migraciones de Laravel
docker exec -it laravel-web php artisan migrate

# Ejecutar trabajadores de colas en segundo plano
docker exec -it laravel-web php artisan queue:work

# Instalar dependencias de Composer
docker exec -it laravel-web composer install

# Ejecutar servidor de desarrollo de Vite (HMR)
docker exec -it laravel-web npm run dev
```

### Crear un nuevo proyecto Laravel desde cero (si la carpeta ./app está vacía)
```bash
docker exec -it laravel-web composer create-project laravel/laravel .
```

---

## 🔍 Verificación del Entorno
- **App Web**: [http://localhost:8090](http://localhost:8090)
- **phpMyAdmin**: [http://localhost:8094](http://localhost:8094)
- **Mailpit Web UI**: [http://localhost:8026](http://localhost:8026)

---

## ⚛️ Adecuación para Entorno Laravel + React + Tailwind CSS

Si deseas construir una aplicación con **React** y **Tailwind CSS** en este entorno Dockerizado, considera las siguientes adecuaciones clave:

### 1. Requerimiento Esencial de Red en Vite (`vite.config.js`)
Dado que el contenedor expone el puerto `5174:5174` (vía `VITE_PORT`), **Vite debe escuchar en todas las interfaces de red (`0.0.0.0`)** y el Hot Module Replacement (HMR) debe apuntar a `localhost`. De lo contrario, el navegador en el host no recibirá las actualizaciones en tiempo real.

Configura tu archivo `vite.config.js` (o `vite.config.ts`) en `./app`:

```javascript
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.jsx'],
            refresh: true,
        }),
        react(),
    ],
    server: {
        host: '0.0.0.0', // Permite conexiones fuera del contenedor Docker
        port: 5174,      // Coincide con VITE_PORT en docker-compose
        strictPort: true,
        hmr: {
            host: 'localhost',
            port: 5174,
        },
    },
});
```

---

### 2. Flujo Recomendado: Laravel Breeze (React + Inertia + Tailwind)
La manera más completa y oficial de implementar Laravel con React y Tailwind CSS es mediante **Laravel Breeze**:

```bash
# 1. Instalar Laravel Breeze vía Composer dentro del contenedor
docker exec -it laravel-web composer require laravel/breeze --dev

# 2. Instalar el stack de React con Inertia y Tailwind CSS
docker exec -it laravel-web php artisan breeze:install react

# 3. Ejecutar las migraciones
docker exec -it laravel-web php artisan migrate

# 4. Instalar las dependencias de Node
docker exec -it laravel-web npm install

# 5. Iniciar el servidor Vite
docker exec -it laravel-web npm run dev
```

---

### 3. Flujo Manual: React + Tailwind CSS (Componentes SPA / Blade)

Si prefieres configurar React y Tailwind manualmente sin Inertia:

#### A. Instalar Dependencias de React y Tailwind
```bash
# Instalar React y el plugin de Vite
docker exec -it laravel-web npm install react react-dom @vitejs/plugin-react

# Instalar Tailwind CSS y PostCSS
docker exec -it laravel-web npm install -D tailwindcss postcss autoprefixer
docker exec -it laravel-web npx tailwindcss init -p
```

#### B. Configurar `tailwind.config.js`
Asegúrate de incluir las rutas de las vistas y componentes:
```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./resources/**/*.blade.php",
    "./resources/**/*.js",
    "./resources/**/*.jsx",
    "./resources/**/*.ts",
    "./resources/**/*.tsx",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

#### C. Incluir Directivas en `resources/css/app.css`
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```
*(Nota: Si usas Tailwind CSS v4, se utiliza `@import "tailwindcss";` y el plugin `@tailwindcss/vite`).*

#### D. Crear el Punto de Entrada React (`resources/js/app.jsx`)
```jsx
import React from 'react';
import { createRoot } from 'react-dom/client';

export default function App() {
    return (
        <div className="flex items-center justify-center min-h-screen bg-slate-900 text-white">
            <h1 className="text-3xl font-bold underline text-cyan-400">
                ¡Laravel + React + Tailwind funcionando en Docker!
            </h1>
        </div>
    );
}

const rootElement = document.getElementById('root');
if (rootElement) {
    createRoot(rootElement).render(<App />);
}
```

#### E. Integración en la Plantilla Blade (`resources/views/welcome.blade.php`)
Agrega `@viteReactRefresh` **antes** de la directiva `@vite`:
```html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Laravel + React + Tailwind</title>
    @viteReactRefresh
    @vite(['resources/css/app.css', 'resources/js/app.jsx'])
</head>
<body class="bg-gray-100">
    <div id="root"></div>
</body>
</html>
```

#### F. Iniciar el Servidor de Desarrollo
```bash
docker exec -it laravel-web npm run dev
```
Luego abre [http://localhost:8090](http://localhost:8090) en tu navegador; los cambios en los archivos `.jsx` o `.css` se reflejarán instantáneamente gracias a HMR en el puerto `5174`.