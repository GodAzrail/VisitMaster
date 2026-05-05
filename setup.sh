#!/bin/bash

# Цвета для красоты и читаемости
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BOLD='\033[1m'
export NC='\033[0m'

# Ссылка на твой репозиторий
REPO_URL="https://github.com/GodAzrail/VisitMaster.git"

show_header() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BOLD}         VISIT MASTER: МЕНЕДЖЕР БОТОВ            ${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

msg() { echo -e "${BLUE}[ИНФО]${NC} $1"; }
success() { echo -e "${GREEN}[УСПЕХ]${NC} $1"; }
warn() { echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"; }
error() { echo -e "${RED}[ОШИБКА]${NC} $1"; }

get_bot_list() {
    mapfile -t BOTS < <(ls /etc/systemd/system/tg_booking_*.service 2>/dev/null | xargs -n 1 basename | sed 's/\.service//')
}

list_bots() {
    get_bot_list
    if [ ${#BOTS[@]} -eq 0 ]; then
        warn "Боты не найдены."
        return 1
    fi
    echo -e "\n${BOLD}СПИСОК БОТОВ:${NC}"
    for i in "${!BOTS[@]}"; do
        status=$(systemctl is-active "${BOTS[$i]}")
        status_color=$RED
        [[ "$status" == "active" ]] && status_color=$GREEN
        printf "  ${BLUE}%2d.${NC} %-25s [${status_color}%-8s${NC}]\n" "$((i+1))" "${BOTS[$i]}" "$status"
    done
    return 0
}

install_bot() {
    show_header
    echo -e "${BOLD}УСТАНОВКА НОВОГО БОТА${NC}\n"
    
    read -p "Введите имя для папки бота (напр. barber): " folder_name
    bot_service_name="tg_booking_$folder_name"
    # Путь создается в текущей директории, где лежит сам setup.sh
    target_dir="$(pwd)/$folder_name"

    if [ -d "$target_dir" ]; then
        error "Папка $folder_name уже существует!"
        return
    fi

    read -p "Токен бота: " token
    read -p "ID админа: " admin_id
    read -p "Часовой пояс (напр. Asia/Krasnoyarsk): " tz

    # Клонируем прямо в указанную папку, чтобы не было матрешки
    msg "Клонируем код в $target_dir..."
    git clone "$REPO_URL" "$target_dir" || { error "Ошибка клонирования!"; return; }
    
    cd "$target_dir" || return

    # Создаем конфиг
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
    echo "BOT_NAME=$bot_service_name" >> .env

    # Настраиваем окружение
    msg "Создаем виртуальное окружение..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip -q
    # Ставим зависимости. Фиксируем версию APScheduler
    pip install --no-cache-dir APScheduler==3.10.4 aiogram==3.13.1 aiosqlite==0.20.0 python-dotenv ics -q

    # Создаем файл службы
    msg "Регистрируем сервис $bot_service_name..."
    USER_NAME=$(whoami)
    SERVICE_FILE="[Unit]
Description=VisitMaster Bot: $bot_service_name
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$target_dir
ExecStart=$target_dir/venv/bin/python3 $target_dir/main.py
Restart=always

[Install]
WantedBy=multi-user.target"

    echo -e "$SERVICE_FILE" | sudo tee /etc/systemd/system/"$bot_service_name".service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "$bot_service_name"
    sudo systemctl start "$bot_service_name"
    
    success "Бот установлен и запущен!"
    cd ..
}

delete_bot() {
    list_bots || return
    echo -ne "\n${BOLD}Введите НОМЕР для УДАЛЕНИЯ (0 - отмена): ${NC}"
    read bot_num
    
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        
        # Находим путь к папке из конфига сервиса
        folder_path=$(grep "WorkingDirectory" "/etc/systemd/system/$selected_bot.service" | cut -d'=' -f2)

        warn "Удаляем $selected_bot..."
        sudo systemctl stop "$selected_bot"
        sudo systemctl disable "$selected_bot"
        sudo rm "/etc/systemd/system/$selected_bot.service"
        sudo systemctl daemon-reload
        
        if [ -d "$folder_path" ]; then
            read -p "Удалить папку проекта $folder_path? (y/n): " confirm
            [[ "$confirm" == "y" ]] && rm -rf "$folder_path" && success "Папка стерта."
        fi
        success "Бот удален."
    else
        error "Отмена или неверный номер."
    fi
}

# ... функции manage_bots и view_logs остаются такими же ...

while true; do
    show_header
    echo -e "  1. Установить нового бота"
    echo -e "  2. Проверить статусы"
    echo -e "  3. Управление (Старт/Стоп/Рестарт)"
    echo -e "  4. Посмотреть логи"
    echo -e "  5. Удалить бота и папку"
    echo -e "  6. Выход"
    read -p "Действие: " choice
    case $choice in
        1) install_bot; read -p "Enter..." ;;
        2) list_bots; read -p "Enter..." ;;
        3) manage_bots; read -p "Enter..." ;;
        4) view_logs; read -p "Enter..." ;;
        5) delete_bot; read -p "Enter..." ;;
        6) exit 0 ;;
    esac
done