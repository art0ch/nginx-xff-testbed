# Makefile

# Все цели не генерируют файлы-артефакты
.PHONY: build up down restart test clean logs help

COMPOSE := docker compose -f docker-compose.yml

# Сборка образов, --pull обновляет базовые слои 
build:
	$(COMPOSE) build --pull

# Запуск сервисов в фоновом режиме
up:
	$(COMPOSE) up -d

# Корректное удаление контейнеров, сетей и volumes
down:
	$(COMPOSE) down --remove-orphans --volumes

# Полная перезагрузка сервисов
restart: down
	$(COMPOSE) up -d

# Валидация проброса заголовков через всю цепочку прокси
test:
	bash tests/test.sh

# Освобождение дискового пространства
clean: down
	docker system prune -f

# Вывод логов с ограничением истории для избежания перегрузки терминала
logs:
	$(COMPOSE) logs -f --tail=50

# Справка по доступным операциям
help:
	@echo "Доступные команды:"
	@echo "  make build   - Сборка образов"
	@echo "  make up      - Запуск стенда"
	@echo "  make down    - Остановка и очистка"
	@echo "  make restart - Перезапуск"
	@echo "  make test    - Проверка X-Forwarded-For"
	@echo "  make clean   - Полная очистка Docker"
	@echo "  make logs    - Логи сервисов"