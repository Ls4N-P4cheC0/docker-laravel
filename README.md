# Docker Laravel

Entorno Docker para crear una aplicación Laravel con Livewire y, si se necesita,
migrar el frontend al *starter kit* React de Laravel.

## Requisitos

- Docker Compose v2
- GNU Make

## Inicio rápido (Livewire)

```sh
cp .env.example .env
make init
make up
```

La aplicación queda disponible en `http://localhost:8000`. El código Laravel se
crea en `src/`, que se monta en los contenedores para conservar los cambios
locales. `make init` instala Laravel, Livewire y las dependencias de frontend.

Ejecute comandos Artisan mediante:

```sh
make artisan CMD="migrate"
make test
```

Para ejecutar Vite con recarga en caliente:

```sh
docker compose up node
```

## Usar React

Después de inicializar Laravel, el siguiente comando instala Laravel Breeze y
configura su *starter kit* React:

```sh
make react
make frontend-build
```

Livewire y React pueden coexistir durante una migración gradual: mantenga las
pantallas Blade/Livewire existentes y añada las nuevas rutas o componentes
React mediante el *starter kit*. Consulte los comandos disponibles con
`make`; `make down` detiene el entorno.
