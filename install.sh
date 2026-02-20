#!/usr/bin/env bash
# install.sh — установка / обновление selfsteal (Caddy + статический сайт через Docker)
# Запуск: sudo bash install.sh   или   sudo ./install.sh

set -euo pipefail

REPO_URL="https://github.com/mrslaveg/selfsteal.git"
INSTALL_DIR="/opt/selfsteal"

echo "=== selfsteal: установка / обновление ==="

# 1. Клонируем или обновляем репозиторий
if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    echo "Клонируем репозиторий..."
    mkdir -p "$INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "Обновляем репозиторий..."
    cd "$INSTALL_DIR"
    git fetch --prune
    git reset --hard origin/main
    git clean -fd
fi

cd "$INSTALL_DIR" || exit 1

# 2. Проверяем наличие docker-compose.yml (из репозитория)
if [[ ! -f "docker-compose.yml" ]]; then
    echo "ОШИБКА: docker-compose.yml не найден!"
    echo "Убедись, что он запушен в репозиторий."
    exit 1
fi

# 3. Caddyfile — создаём только если отсутствует
if [[ ! -f "Caddyfile" ]]; then
    echo ""
    read -r -p "Введите домен (пример: uk.technoblog.pro): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo "Домен обязателен → выход"
        exit 1
    fi

    cat > Caddyfile <<EOF
$DOMAIN {
    tls {
        protocols tls1.2 tls1.3
    }
    encode gzip
    root * /usr/share/caddy
    file_server
}
EOF

    echo "Создан Caddyfile для домена: $DOMAIN"
    cat Caddyfile
else
    echo "Caddyfile уже существует → используем текущий:"
    cat Caddyfile
    echo ""
    echo "(чтобы сменить домен — удали Caddyfile и запусти скрипт заново)"
fi

# 4. Проверяем папку site
mkdir -p site  # на всякий случай
if [[ -z "$(ls -A site 2>/dev/null)" ]]; then
    echo "Внимание: папка site/ пуста"
    echo "→ положи туда index.html и остальные файлы сайта"
else
    echo "Папка site/ содержит файлы — ок"
fi

# 5. Docker: остановка → pull → запуск
echo ""
echo "Останавливаем старый контейнер (если был)..."
docker compose down --remove-orphans 2>/dev/null || true

echo "Обновляем образ caddy..."
docker compose pull

echo "Запускаем..."
docker compose up -d --remove-orphans

echo ""
echo "Готово!"
echo ""
echo "Статус контейнеров:"
docker compose ps
echo ""
echo "Последние логи:"
docker compose logs --tail 30
echo ""
echo "Полные логи в реальном времени:  docker compose logs -f"
echo ""
echo "Полезные пути:"
echo "  $INSTALL_DIR/site/          ← файлы сайта (обновляй git pull или вручную)"
echo "  $INSTALL_DIR/Caddyfile      ← конфиг Caddy"
echo "  $INSTALL_DIR/docker-compose.yml"
echo ""
echo "Для обновления сайта / конфига в будущем:"
echo "  cd $INSTALL_DIR"
echo "  git pull"
echo "  docker compose up -d"
