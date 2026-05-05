#!/bin/bash

# Цветовая палитра
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Функция для отрисовки шапки
show_header() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BOLD}          VISIT MASTER: INSTALLER PRO          ${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

# Функция для вывода уведомлений
msg() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_menu() {
    echo -e "\n${BOLD}ГЛАВНОЕ МЕНЮ:${NC}"
    echo -e "  ${BLUE}1.${NC} Установить нового бота"
    echo -e "  ${BLUE}2.${NC} Список активных ботов"
    echo -e "  ${BLUE}3.${NC} ${RED}Удалить бота (по номеру)${NC}"
    echo -e "  ${BLUE}4.${NC} Выход"
    echo -ne "\n${BOLD}Выберите действие [1-4]: ${NC}"
    read choice
}

get_bot_list() {
    mapfile -t BOTS < <(ls /etc/systemd/system/tg_booking_*.service 2>/dev/null | xargs -n 1 basename | sed 's/\.service//')
}

list_bots() {
    get_bot_list
    if [ ${#BOTS[@]} -eq 0 ]; then
        warn "Установленных ботов не найдено."
        return 1
    fi
    echo -e "\n${BOLD}СПИСОК УСТАНОВЛЕННЫХ БОТОВ:${NC}"
    echo -e "--------------------------------------------------"
    for i in "${!BOTS[@]}"; do
        status=$(systemctl is-active "${BOTS[$i]}")
        status_color=$RED
        [[ "$status" == "active" ]] && status_color=$GREEN
        
        printf "  ${BLUE}%2d.${NC} %-25s [${status_color}%-8s${NC}]\n" "$((i+1))" "${BOTS[$i]}" "$status"
    done
    echo -e "--------------------------------------------------"
    return 0
}

delete_bot() {
    list_bots || return
    echo -ne "\n${BOLD}Введите НОМЕР для удаления (или 0 для отмены): ${NC}"
    read bot_num
    
    if [[ "$bot_num" == "0" ]]; then return; fi

    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        
        warn "Удаление $selected_bot..."
        sudo systemctl stop "$selected_bot"
        sudo systemctl disable "$selected_bot"
        sudo rm "/etc/systemd/system/$selected_bot.service"
        sudo systemctl daemon-reload
        success "Бот полностью удален."
    else
        error "Неверный номер!"
    fi
}

install_bot() {
    show_header
    echo -e "${BOLD}НАСТРОЙКА НОВОЙ КОНФИГУРАЦИИ${NC}\n"
    
    read -p "Название (англ, напр. barber): " short_name
    bot_service_name="tg_booking_$short_name"
    
    read -p "Telegram Bot Token: " token
    read -p "Admin Telegram ID: " admin_id
    read -p "Timezone (Asia/Krasnoyarsk): " tz
    
    msg "Создание конфигурационных файлов..."
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
    echo "BOT_NAME=$bot_service_name" >> .env

    msg "Подготовка окружения (Python 3.13)..."
    python3 -m venv venv
    source venv/bin/activate
    
    msg "Установка зависимостей..."
    pip install --upgrade pip -q
    pip install --no-cache-dir APScheduler==3.10.4 aiogram==3.13.1 aiosqlite==0.20.0 python-dotenv ics -q
    
    msg "Регистрация системной службы..."
    CUR_DIR=$(pwd)
    USER=$(whoami)

    SERVICE_FILE="[Unit]
Description=VisitMaster Bot: $bot_service_name
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$CUR_DIR
ExecStart=$CUR_DIR/venv/bin/python3 $CUR_DIR/main.py
Restart=always

[Install]
WantedBy=multi-user.target"

    echo "$SERVICE_FILE" | sudo tee /etc/systemd/system/"$bot_service_name".service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "$bot_service_name"
    sudo systemctl start "$bot_service_name"
    
    success "Бот $bot_service_name успешно запущен!"
    echo -e "\nЛоги: journalctl -u $bot_service_name -f"
}

# Основной цикл
while true; do
    show_header
    show_menu
    case $choice in
        1) install_bot ;;
        2) list_bots; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        3) delete_bot; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        4) msg "Завершение работы."; exit 0 ;;
        *) error "Неверный выбор!"; sleep 1 ;;
    esac
done