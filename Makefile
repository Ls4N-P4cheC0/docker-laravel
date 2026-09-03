.PHONY: init up down logs shell artisan test frontend-build react

init:
	docker compose run --rm app composer create-project laravel/laravel .
	docker compose run --rm app composer require livewire/livewire
	docker compose run --rm node npm install
	docker compose run --rm app php artisan key:generate

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose exec app sh

artisan:
	docker compose exec app php artisan $(CMD)

test:
	docker compose exec app php artisan test

frontend-build:
	docker compose run --rm node npm run build

react:
	docker compose run --rm app composer require laravel/breeze --dev
	docker compose run --rm app php artisan breeze:install react
	docker compose run --rm node npm install
