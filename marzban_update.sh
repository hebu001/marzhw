#!/usr/bin/env bash
set -e

# === НАСТРОЙКИ ===
# Сюда впиши реальный URL архива с GitHub
GITHUB_ZIP_URL="https://import.evovpn.ru/static/download/code.zip"
CODE_ZIP_PATH="/var/lib/marzban/code.zip"
CODE_DIR="/var/lib/marzban/code"
DB_PATH="/var/lib/marzban/db.sqlite3"
DOCKER_COMPOSE="/opt/marzban/docker-compose.yml"

echo "== 1. Backup Marzban =="
marzban backup || { echo "marzban backup неудачно, выходим"; exit 1; }

echo "== 2. Скачиваем code.zip с GitHub =="
mkdir -p /var/lib/marzban
cd /var/lib/marzban

if command -v wget >/dev/null 2>&1; then
  wget -O "$CODE_ZIP_PATH" "$GITHUB_ZIP_URL"
elif command -v curl >/dev/null 2>&1; then
  curl -L "$GITHUB_ZIP_PATH" -o "$CODE_ZIP_PATH"
else
  echo "Нужен wget или curl для скачивания архива"; exit 1
fi

echo "== 3. Распаковываем архив =="
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y unzip >/dev/null 2>&1

rm -rf "$CODE_DIR"
mkdir -p "$CODE_DIR"
unzip -o "$CODE_ZIP_PATH" -d "$CODE_DIR"

echo "== 4. Устанавливаем sqlite3 (если нет) =="
apt-get install -y sqlite3 >/dev/null 2>&1

if [ ! -f "$DB_PATH" ]; then
  echo "База $DB_PATH не найдена, проверь путь"; exit 1
fi

echo "== 5. ALTER TABLE users (hwid и max_devices) =="

sqlite3 "$DB_PATH" <<'SQL'
ALTER TABLE users ADD COLUMN hwid TEXT;
SQL

sqlite3 "$DB_PATH" <<'SQL'
ALTER TABLE users ADD COLUMN max_devices INTEGER DEFAULT 2;
SQL

echo "== 6. Обновляем docker-compose.yml (добавляем /var/lib/marzban/code:/code) =="

if [ ! -f "$DOCKER_COMPOSE" ]; then
  echo "Файл $DOCKER_COMPOSE не найден, проверь путь"; exit 1
fi

# Добавляем строку монтирования, если её ещё нет
if ! grep -q "/var/lib/marzban/code:/code" "$DOCKER_COMPOSE"; then
  sed -i '/- \/var\/lib\/marzban:\/var\/lib\/marzban/a\      - /var/lib/marzban/code:/code' "$DOCKER_COMPOSE"
  echo "Строка с /var/lib/marzban/code:/code добавлена."
else
  echo "Строка /var/lib/marzban/code:/code уже есть — пропускаем."
fi

echo "== 7. Перезапускаем Marzban =="
marzban restart

echo "Готово."
