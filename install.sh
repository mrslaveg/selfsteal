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

# 2. Проверяем наличие docker-compose.yml
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

# 4. Папка site
mkdir -p site
if [[ -z "$(ls -A site 2>/dev/null)" ]]; then
    echo "Внимание: папка site/ пуста"
    echo "→ положи туда index.html и остальные файлы сайта"
else
    echo "Папка site/ содержит файлы — ок"
fi

# 5. Открываем порт 80 в ufw (если ufw активен)
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        echo ""
        echo "ufw активен → открываем порт 80 (HTTP)..."
        sudo ufw allow http || {
            echo "Предупреждение: не удалось выполнить 'ufw allow http'"
            echo "Проверьте вручную: sudo ufw status"
        }
        # Можно добавить и 443, если захочешь:
        # sudo ufw allow https
    else
        echo "ufw установлен, но не активен → порт открывать не нужно"
    fi
else
    echo "ufw не найден → предполагаем, что firewall не используется или другой"
fi

# 6. Вопрос о запуске
echo ""
read -r -p "Запустить Caddy сейчас? [Y/n] " answer
answer=${answer:-Y}   # по умолчанию Yes

case "$answer" in
    [Yy]*|"")
        echo "Запускаем / перезапускаем контейнер..."

        docker compose down --remove-orphans 2>/dev/null || true
        docker compose pull
        docker compose up -d --remove-orphans

        echo ""
        echo "Статус контейнеров:"
        docker compose ps
        echo ""
        echo "Последние 30 строк логов:"
        docker compose logs --tail 30
        ;;
    [Nn]*)
        echo "Запуск пропущен."
        echo "Чтобы запустить позже:"
        echo "  cd $INSTALL_DIR"
        echo "  docker compose up -d"
        ;;
    *)
        echo "Неизвестный ответ → запуск пропущен."
        ;;
esac

# 7. Переходим в папку selfsteal (чтобы shell остался там)
echo ""
echo "Переходим в директорию проекта..."
cd "$INSTALL_DIR"

echo ""
echo "Готово! Вы уже находитесь в:"
pwd
echo ""
echo "Полезные команды:"
echo "  docker compose logs -f          → смотреть логи в реальном времени"
echo "  docker compose ps               → статус контейнеров"
echo "  git pull && docker compose up -d → обновить сайт"
echo ""
echo "Файлы сайта: ./site/"
echo "Конфиг Caddy: ./Caddyfile"
