#!/usr/bin/env bash

# Установщик Caddy + docker-compose для статического сайта
# Запускать с правами root/sudo

set -euo pipefail

echo "=== Установка Caddy в /opt/selfsteal ==="

# 1. Переходим и создаём папку
cd /opt || { echo "Не удалось перейти в /opt"; exit 1; }
mkdir -p selfsteal
cd selfsteal

# 2. Спрашиваем домен у пользователя
echo ""
read -r -p "Введите домен (например: example.com или uk.technoblog.pro): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo "Ошибка: домен не введён. Выход."
    exit 1
fi

# 3. Создаём Caddyfile
cat > Caddyfile << 'EOF'
'"$DOMAIN"' {
    tls {
        protocols tls1.2 tls1.3
    }
    encode gzip
    root * /usr/share/caddy
    file_server
}
EOF

echo ""
echo "Создан Caddyfile для домена: $DOMAIN"
echo "Содержимое:"
cat Caddyfile
echo ""

# 4. Создаём docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "127.0.0.1:8443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./site:/usr/share/caddy
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
EOF

echo "Создан docker-compose.yml"
echo ""

# 5. Создаём пустую папку site (если ещё нет)
mkdir -p site
echo "Создана папка site → туда клади index.html и остальные файлы сайта"

echo ""
echo "Готово. Сейчас будет запущен контейнер."

# 6. Запуск
docker compose up -d

echo ""
echo "Контейнер запущен."
echo "Логи (для выхода из логов нажми Ctrl+C):"
echo ""

# 7. Показываем логи в реальном времени
docker compose logs -f
