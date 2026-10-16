# Análisis de Entorno Docker Laravel y Evaluación de Migración a Nginx

**Fecha:** Octubre 2026  
**Proyecto:** Docker Laravel (`docker-laravel`)  
**Documento:** `ANALISIS_MIGRACION_NGINX.md`  

---

## 1. Resumen Ejecutivo

El presente documento evalúa el estado actual de la infraestructura Dockerizada para el desarrollo con **Laravel** (PHP, MySQL 8.4 LTS, Redis, Mailpit y phpMyAdmin) y analiza en profundidad la viabilidad, impacto y arquitectura requerida en caso de realizar una migración de **Apache HTTP Server (`mod_php`)** a **Nginx (`php-fpm`)** o a alternativas modernas como **FrankenPHP**.

### Veredicto Rápido:
* **Estado actual del entorno:** Muy completo y bien orquestado para desarrollo rápido, pero cuenta con detalles críticos que deben ajustarse (versión inestable de PHP, omisión de `.gitignore`, dependencia de red externa previa y sincronización de dependencias de MySQL).
* **Impacto en el código Laravel/React:** **Nulo (0%)**. Laravel y su lógica de aplicación son agnósticos al servidor web.
* **Impacto en la infraestructura Docker:** **Medio (40-50%)**. Requiere desacoplar el servidor web del intérprete de PHP (modelo de 2 contenedores: `nginx` + `php-fpm`), reemplazar directivas `.htaccess` por reglas de ruteo `try_files` en `nginx.conf`, y mapear volúmenes compartidos.

---

## 2. Diagnóstico Técnico del Entorno Actual

### 2.1 Puntos Fuertes Detectados
- **Stack Integral:** Cuenta con todos los servicios esenciales para desarrollo empresarial moderno (MySQL 8.4 LTS, Redis 7, Mailpit para interceptación de correos SMTP y phpMyAdmin para administración gráfica).
- **Herramientas de Build Modernas:** Extracción multi-stage de Node.js v22 y Composer v2.8, con soporte global para `pnpm` y `yarn`.
- **Integración con Vite y HMR:** Puerto `5174` mapeado para Hot Module Replacement en el desarrollo de interfaces con React y Tailwind CSS.
- **Soporte de Dev Containers:** Configuración lista en `.devcontainer/devcontainer.json` para desarrollo directo dentro del contenedor con extensiones clave preconfiguradas.

### 2.2 Hallazgos y Vulnerabilidades a Corregir

| Severidad | Elemento | Diagnóstico | Acción Aplicada | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **Alta** | `PHP_IMAGE` (`Dockerfile` / `.env`) | Se definió `php:8.5-apache-bookworm` (inestable). | Actualizado a `php:8.4-apache-bookworm` (estable y compatible con Composer). | ✅ **Corregido** |
| **Alta** | Ausencia de `.gitignore` | Riesgo de filtrar `.env`, bases de datos y dependencias al repo. | Creado `.gitignore` protegiendo credenciales, `mysql-data/`, `redis-data/` y `app/`. | ✅ **Corregido** |
| **Media** | Red `mi_red_desarrollo` | Definida como `external: true`, requería creación manual previa. | Modificada a red nativa con driver `bridge` y nombre explícito; Compose la crea automáticamente. | ✅ **Corregido** |
| **Media** | Condición de arranque `db` | Sin healthcheck, `web` iniciaba antes de que MySQL estuviera listo. | Implementado healthcheck con `mysqladmin ping` y dependencias `condition: service_healthy`. | ✅ **Corregido** |

---

## 3. Análisis de Impacto: Migración de Apache a Nginx

### 3.1 Diferencia Arquitectónica Fundamental

```
[ ARQUITECTURA ACTUAL (Apache) ]
Cliente Web ---> Puerto 8090 ---> [ Contenedor: laravel-web ]
                                  ( Apache + mod_php + Composer + Node )
                                  * Lee dinámicamente public/.htaccess

[ ARQUITECTURA PROPUESTA (Nginx + PHP-FPM) ]
Cliente Web ---> Puerto 8090 ---> [ Contenedor: laravel-nginx ] (Nginx Oficial)
                                        | (Pasa peticiones PHP vía FastCGI:9000)
                                        v
                                  [ Contenedor: laravel-app ] (php:8.4-fpm)
                                  ( PHP-FPM + Composer + Node )
                                  * Requiere configuración explícita en nginx.conf
```

### 3.2 Desglose del Impacto por Área

#### A. En el Código de la Aplicación (Laravel / Frontend)
* **Impacto:** **Nulo (0%)**.
* Controladores, Middleware, Modelos Eloquent, Jobs en Redis, rutas (`web.php`, `api.php`), migraciones y componentes React no sufren alteración alguna.
* Laravel procesa la petición a través de su entrada unificada `public/index.php`, independientemente de quién le pase la conexión (SAPI Apache o FastCGI PHP-FPM).

#### B. En los Archivos de Configuración Web
* **Impacto:** **Alto**.
* **Pérdida de `.htaccess`:** Nginx **no lee ni interpreta** archivos `.htaccess`. Toda la lógica de reescritura de URLs de Laravel debe residir en el bloque de servidor de Nginx:
  ```nginx
  location / {
      try_files $uri $uri/ /index.php?$query_string;
  }
  ```
* **Límites de Subida y Tiempos:** Directivas como `upload_max_filesize` y `post_max_size` deben ajustarse tanto en `php.ini` como en Nginx (`client_max_body_size`).

#### C. En el Flujo de Trabajo en Docker
* **Impacto:** **Medio**.
* Se pasa de 1 servicio web a 2 servicios interconectados (`nginx` y `app`).
* Ambos contenedores deben montar el volumen `./app:/var/www/html`:
  - `nginx` lo necesita para servir directamente archivos estáticos (CSS, JS compilado, imágenes, favicon) con máxima velocidad.
  - `app` lo necesita para ejecutar los scripts PHP.

---

## 4. Matriz Comparativa: Apache vs Nginx vs FrankenPHP

| Criterio | Apache (`mod_php`) (Actual) | Nginx + PHP-FPM | FrankenPHP (Moderno) |
| :--- | :--- | :--- | :--- |
| **Complejidad de Configuración** | **Mínima:** 1 solo contenedor, `.htaccess` nativo. | **Moderada:** 2 contenedores, configuración FastCGI manual. | **Baja:** 1 solo contenedor, configuración Caddyfile limpia. |
| **Consumo de Memoria RAM** | Medio / Alto (cada hilo carga el módulo completo de PHP). | **Muy Bajo** (arquitectura orientada a eventos ultra ligera). | **Bajo / Optimizado** (servidor en Go con PHP embebido). |
| **Rendimiento en Concurrencia** | Aceptable para desarrollo y cargas moderadas. | **Excelente** (estándar de la industria para tráfico masivo). | **Sobresaliente** (soporta Worker Mode con Laravel Octane). |
| **Rendimiento en Windows / WSL2** | Idéntico (el cuello de botella en desarrollo es el disco/bind mount). | Idéntico en desarrollo local. | Idéntico en desarrollo local. |
| **Paridad con Producción** | Baja (muy pocos despliegues modernos usan Apache). | **Muy Alta** (estándar en VPS, AWS ECS, Kubernetes). | **Muy Alta** (nuevo estándar oficial en Laravel 11/12). |

---

## 5. Guía de Implementación si se decide migrar a Nginx

Si se opta por migrar a Nginx, a continuación se detallan los cambios exactos requeridos:

### 5.1 Estructura del `docker-compose.yml` (Ajuste a 2 Contenedores)

```yaml
services:
  # Servidor Web Nginx
  web:
    image: nginx:1.27-alpine
    container_name: laravel-nginx
    ports:
      - "${APP_PORT:-8090}:80"
    volumes:
      - ./app:/var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app
    networks:
      - mi_red_desarrollo

  # Intérprete PHP-FPM y herramientas de desarrollo
  app:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        PHP_IMAGE: php:8.4-fpm-bookworm
        NODE_IMAGE: ${NODE_IMAGE}
        PNPM_VERSION: ${PNPM_VERSION}
        YARN_VERSION: ${YARN_VERSION}
        COMPOSER_IMAGE: ${COMPOSER_IMAGE}
    container_name: laravel-app
    ports:
      - "${VITE_PORT:-5174}:5174"
    volumes:
      - ./app:/var/www/html
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - mi_red_desarrollo
```

### 5.2 Configuración de Nginx (`docker/nginx/default.conf`)

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;

    index index.php index.html;
    charset utf-8;

    # Tamaño máximo de subida
    client_max_body_size 64M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    # Procesamiento de PHP a través del socket TCP de PHP-FPM
    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
    }

    # Bloqueo de archivos ocultos (.env, .git, etc.)
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### 5.3 Ajustes en el `Dockerfile`
1. Cambiar la imagen base de `php:8.5-apache-bookworm` a `php:8.4-fpm-bookworm`.
2. Remover comandos de Apache (`a2enmod rewrite`, configuración de VirtualHost en `/etc/apache2/`).
3. El comando por defecto pasa a ser `php-fpm` (exponiendo el puerto `9000` internamente).

---

## 6. Recomendaciones Finales y Plan de Acción

1. **Decisión sobre el Servidor Web:**
   - **Para desarrollo exclusivamente local:** Puedes quedarte con **Apache** si buscas la menor cantidad de archivos de configuración posible y cero mantenimiento de virtualhosts.
   - **Para replicar fielmente entornos de producción (Staging / Production):** Realiza la migración a **Nginx + PHP-FPM**. Es el estándar indiscutible en despliegues reales.
   - **Si buscas la vanguardia del ecosistema Laravel:** Considera **FrankenPHP**, el cual unifica la simpleza de un solo contenedor con la máxima velocidad de ejecución.

2. **Acciones Inmediatas Recomendadas (Independientemente del servidor web):**
   - [x] Ajustar la versión de PHP a `php:8.4` en `.env`.
   - [x] Crear el archivo `.gitignore` para salvaguardar credenciales y datos de MySQL.
   - [x] Añadir `healthcheck` al contenedor de MySQL en `docker-compose.yml`.
