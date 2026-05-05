#!/bin/bash

# Цветовая палитра
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BOLD='\033[1m'
export NC='\033[0m'

# Шапка
show_header() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BOLD}          VISIT MASTER: DevOps Terminal          ${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

msg() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Главное меню
show_menu() {
    echo -e "\n${BOLD}ГЛАВНОЕ МЕНЮ:${NC}"
    echo -e "  ${BLUE}1.${NC} Установить нового бота"
    echo -e "  ${BLUE}2.${NC} Список ботов и статусы"
    echo -e "  ${BLUE}3.${NC} Управление (Start/Stop/Restart)"
    echo -e "  ${BLUE}4.${NC} Просмотр логов (Journal)"
    echo -e "  ${BLUE}5.${NC} ${RED}Удалить бота${NC}"
    echo -e "  ${BLUE}6.${NC} Выход"
    echo -ne "\n${BOLD}Выберите действие [1-6]: ${NC}"
    read choice
}

get_bot_list() {
    mapfile -t BOTS < <(ls /etc/systemd/system/tg_booking_*.service 2>/dev/null | xargs -n 1 basename | sed 's/\.service//')
}

list_bots() {
    get_bot_list
    if [ ${#BOTS[@]} -eq 0 ]; then
        warn "Ботов не обнаружено."
        return 1
    fi
    echo -e "\n${BOLD}ТЕКУЩИЕ БОТЫ В СИСТЕМЕ:${NC}"
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

# Функция управления состоянием
manage_bots() {
    list_bots || return
    echo -ne "\n${BOLD}Выберите НОМЕР бота для управления: ${NC}"
    read bot_num
    
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        echo -e "\n${BOLD}ДЕЙСТВИЕ ДЛЯ $selected_bot:${NC}"
        echo "1. Start  2. Stop  3. Restart  0. Отмена"
        read -p "Выберите [1-3]: " action
        
        case $action in
            1) sudo systemctl start "$selected_bot"; success "Запущен" ;;
            2) sudo systemctl stop "$selected_bot"; warn "Остановлен" ;;
            3) sudo systemctl restart "$selected_bot"; success "Перезагружен" ;;
            *) msg "Отмена" ;;
        esac
    else
        error "Неверный номер!"
    fi
}

view_logs() {
    list_bots || return
    echo -ne "\n${BOLD}Номер бота для логов (0 для отмены): ${NC}"
    read bot_num
    [[ "$bot_num" == "0" ]] && return
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        msg "Логи $selected_bot (Ctrl+C для выхода)..."
        sudo journalctl -u "$selected_bot" -f -n 50
    else
        error "Ошибка выбора!"
    fi
}

delete_bot() {
    list_bots || return
    echo -ne "\n${RED}${BOLD}ВНИМАНИЕ! Введите НОМЕР для УДАЛЕНИЯ (0 - отмена): ${NC}"
    read bot_num
    [[ "$bot_num" == "0" ]] && return
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        sudo systemctl stop "$selected_bot"
        sudo systemctl disable "$selected_bot"
        sudo rm "/etc/systemd/system/$selected_bot.service"
        sudo systemctl daemon-reload
        success "Бот $selected_bot удален."
    else
        error "Ошибка выбора!"
    fi
}

install_bot() {
    show_header
    echo -e "${BOLD}УСТАНОВКА НОВОГО ЭКЗЕМПЛЯРА${NC}\n"
    read -p "ID/Имя проекта (напр. nail): " short_name
    bot_service_name="tg_booking_$short_name"
    read -p "Token: " token
    read -p "Admin ID: " admin_id
    read -p "Timezone (Asia/Krasnoyarsk): " tz
    
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
    echo "BOT_NAME=$bot_service_name" >> .env

    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install --no-cache-dir APScheduler==3.10.4 aiogram==3.13.1 aiosqlite==0.20.0 python-dotenv ics -q
    
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

    echo "$SERVICE_FILE" | sudo tee "/etc/systemd/system/$bot_service_name.service" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "$bot_service_name"
    sudo systemctl start "$bot_service_name"
    success "Бот $bot_service_name установлен и запущен!"
}

while true; do
    show_header
    show_menu
    case $choice in
        1) install_bot; read -p "Нажмите Enter..." ;;
        2) list_bots; read -p "Нажмите Enter..." ;;
        3) manage_bots; read -p "Нажмите Enter..." ;;
        4) view_logs; read -p "Нажмите Enter..." ;;
        5) delete_bot; read -p "Нажмите Enter..." ;;
        6) msg "Bye!"; exit 0 ;;
        *) error "Ошибка!"; sleep 1 ;;
    esac
done