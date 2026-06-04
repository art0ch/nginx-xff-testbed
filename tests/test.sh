#!/usr/bin/env bash
# =============================================================================
# Скрипт валидации цепочки заголовков X-Forwarded-For
# Проверяет корректность проброса IP через 3 уровня Nginx-прокси
# =============================================================================

# Строгий режим выполнения
set -euo pipefail

# Константы конфигурации
readonly BASE_URL="http://localhost"
readonly -a PORTS=(8001 8002 8003)
readonly FAKE_IP="10.99.99.99"

# Ожидаемые хвосты цепочки X-Forwarded-For
# Nginx добавляет IP отправителя в конец существующего заголовка ($proxy_add_x_forwarded_for)
# Порядок в ответе приложения: <Клиент>, <Nginx1>, <Nginx2>, <Nginx3>
# Клиентский IP может варьироваться (127.0.0.1, ::1, или IP Docker-хоста),
# поэтому проверяем только суффикс цепочки
declare -A EXPECTED_TAILS=(
  [8003]="172.20.0.13"
  [8002]="172.20.0.12, 172.20.0.13"
  [8001]="172.20.0.11, 172.20.0.12, 172.20.0.13"
)

# Проверка наличия необходимых утилит
check_dependencies() {
  local missing=()
  for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Отсутствуют утилиты: ${missing[*]}"
    echo "Установите: sudo apt install curl jq (или аналог для вашей ОС)"
    exit 1
  fi
}

# Тестирование одного эндпоинта
test_port() {
  local port=$1
  local url="${BASE_URL}:${port}"
  local expected="${EXPECTED_TAILS[$port]}"

  echo -n "Проверка порта ${port}... "

  # 1. Получаем HTTP-код отдельно. || true предотвращает остановку скрипта при non-200
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" "${url}" || true)

  if [[ "$http_code" != "200" ]]; then
    echo "HTTP ${http_code}"
    return 1
  fi

  # 2. Получаем тело ответа
  local body
  body=$(curl -s "${url}")

  # 3. Безопасное извлечение поля через jq
  # -r: raw output (без кавычек)
  # // empty: возвращает пустую строку, если ключ отсутствует
  local xff
  xff=$(echo "$body" | jq -r '.x_forwarded_for // empty')

  if [[ -z "$xff" ]]; then
    echo "Заголовок X-Forwarded-For отсутствует в ответе"
    return 1
  fi

  # 4. Валидация цепочки
  # Проверяем, что строка заканчивается ожидаемыми IP прокси
  if [[ "$xff" == *"${expected}" ]]; then
    echo "OK"
    echo "Цепочка: ${xff}"
    return 0
  else
    echo "Несоответствие цепочки"
    echo "   Ожидалось (суффикс): ${expected}"
    echo "   Получено:            ${xff}"
    return 1
  fi
}

# Тестирование защиты от подделки заголовка X-Forwarded-For
test_spoofing() {
  local port=$1
  local url="${BASE_URL}:${port}"

  echo -n "Защита от спуфинга (порт ${port})... "

  # Отправляем запрос с заведомо ложным заголовком
  local body
  body=$(curl -s -H "X-Forwarded-For: ${FAKE_IP}" "${url}")

  local xff
  xff=$(echo "$body" | jq -r '.x_forwarded_for // empty')

  # Фейковый IP НЕ должен присутствовать в ответе
  if [[ "$xff" != *"${FAKE_IP}"* ]]; then
    echo "OK (фейк отброшен)"
    return 0
  else
    echo "Уязвимость! Фейковый IP прошёл в приложение"
    echo "   Получено: ${xff}"
    return 1
  fi
}

main() {
  echo "========================================="
  echo "   Валидация X-Forwarded-For (Testbed)"
  echo "========================================="
  
  check_dependencies

  local failures=0
  for port in "${PORTS[@]}"; do
    test_port "$port" || failures=$((failures + 1))
    test_spoofing "$port" || failures=$((failures + 1))
    echo "-----------------------------------------"
  done

  if (( failures == 0 )); then
    echo "Все тесты пройдены успешно."
    exit 0
  else
    echo "Тесты провалены: ${failures} ошибка(и)."
    exit 1
  fi
}

# Запуск основной функции с передачей аргументов (если понадобятся в будущем)
main "$@"