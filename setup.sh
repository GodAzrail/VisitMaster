#!/bin/bash

# Цвета для интерфейса
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
        warn "Установленных ботов не найдено."
        return 1
    fi
    echo -e "\n${BOLD}СПИСОК БОТОВ В СИСТЕМЕ:${NC}"
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
    echo -e "${BOLD}УСТАНОВКА НОВОГО ЭКЗЕМПЛЯРА${NC}\n"
    
    read -p "Введите имя папки для бота (англ, напр. barber): " folder_name
    bot_service_name="tg_booking_$folder_name"
    target_dir="/home/azrail/$folder_name"

    if [ -d "$target_dir" ]; then
        error "Папка $folder_name уже существует!"
        return
    fi

    read -p "Telegram Bot Token: " token
    read -p "Admin Telegram ID: " admin_id
    
    # Интерактивный выбор часового пояса
    echo -e "\n${BOLD}Выберите часовой пояс:${NC}"
    echo "1. Москва (Europe/Moscow)"
    echo "2. Красноярск (Asia/Krasnoyarsk)"
    echo "3. Новосибирск (Asia/Novosibirsk)"
    echo "4. Екатеринбург (Asia/Yekaterinburg)"
    echo "5. UTC (Universal Time)"
    echo "6. Ввести вручную"
    read -p "Выберите вариант [1-6]: " tz_choice

    case $tz_choice in
        1) tz="Europe/Moscow" ;;
        2) tz="Asia/Krasnoyarsk" ;;
        3) tz="Asia/Novosibirsk" ;;
        4) tz="Asia/Yekaterinburg" ;;
        5) tz="UTC" ;;
        6) read -p "Введите зону (напр. Europe/London): " tz ;;
        *) tz="Europe/Moscow"; warn "По умолчанию установлен Europe/Moscow" ;;
    esac

    # Защита от пустой строки для ZoneInfo
    if [ -z "$tz" ]; then tz="Europe/Moscow"; fi

    msg "Клонирование репозитория в $target_dir..."
    git clone "$REPO_URL" "$target_dir" || { error "Ошибка клонирования!"; return; }
    
    cd "$target_dir" || return

    # Создание .env
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
    echo "BOT_NAME=$bot_service_name" >> .env

    msg "Настройка Python и зависимостей..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install --no-cache-dir APScheduler==3.10.4 aiogram==3.13.1 aiosqlite==0.20.0 python-dotenv ics -q

    msg "Регистрация службы $bot_service_name..."
    USER_VAL=$(whoami)
    SERVICE_FILE="[Unit]
Description=VisitMaster Bot: $bot_service_name
After=network.target

[Service]
Type=simple
User=$USER_VAL
WorkingDirectory=$target_dir
ExecStart=$target_dir/venv/bin/python3 $target_dir/main.py
Restart=always

[Install]
WantedBy=multi-user.target"

    echo -e "$SERVICE_FILE" | sudo tee /etc/systemd/system/"$bot_service_name".service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "$bot_service_name"
    sudo systemctl start "$bot_service_name"
    
    success "Бот успешно запущен в папке $target_dir!"
    cd ..
}

manage_bots() {
    list_bots || return
    echo -ne "\n${BOLD}Введите НОМЕР бота для управления: ${NC}"
    read bot_num
    
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        echo -e "\n${BOLD}ДЕЙСТВИЕ ДЛЯ $selected_bot:${NC}"
        echo "1. Старт  2. Стоп  3. Рестарт  0. Отмена"
        read -p "Выберите вариант [1-3]: " action
        
        case $action in
            1) sudo systemctl start "$selected_bot"; success "Сервис запущен" ;;
            2) sudo systemctl stop "$selected_bot"; warn "Сервис остановлен" ;;
            3) sudo systemctl restart "$selected_bot"; success "Сервис перезагружен" ;;
            *) msg "Отмена" ;;
        esac
    else
        error "Неверный номер!"
    fi
}

view_logs() {
    list_bots || return
    echo -ne "\n${BOLD}Номер бота для просмотра логов (0 - отмена): ${NC}"
    read bot_num
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        msg "Загрузка логов $selected_bot (Ctrl+C для выхода)..."
        sudo journalctl -u "$selected_bot" -f -n 50
    else
        msg "Возврат в меню."
    fi
}

delete_bot() {
    list_bots || return
    echo -ne "\n${RED}${BOLD}Введите НОМЕР для ПОЛНОГО УДАЛЕНИЯ (0 - отмена): ${NC}"
    read bot_num
    
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        folder_path=$(grep "WorkingDirectory" "/etc/systemd/system/$selected_bot.service" | cut -d'=' -f2)

        warn "Удаление системы $selected_bot..."
        sudo systemctl stop "$selected_bot"
        sudo systemctl disable "$selected_bot"
        sudo rm "/etc/systemd/system/$selected_bot.service"
        sudo systemctl daemon-reload
        
        if [ -d "$folder_path" ]; then
            rm -rf "$folder_path"
            success "Папка проекта $folder_path удалена."
        fi
        success "Бот полностью удален из системы."
    else
        msg "Удаление отменено."
    fi
}

# Главный цикл
while true; do
    show_header
    echo -e "  ${BLUE}1.${NC} Установить нового бота"
    echo -e "  ${BLUE}2.${NC} Список ботов и статусы"
    echo -e "  ${BLUE}3.${NC} Управление (Старт/Стоп/Рестарт)"
    echo -e "  ${BLUE}4.${NC} Просмотр логов"
    echo -e "  ${BLUE}5.${NC} ${RED}Удалить бота и папку${NC}"
    echo -e "  ${BLUE}6.${NC} Выход"
    echo -ne "\n${BOLD}Выберите действие [1-6]: ${NC}"
    read choice

    case $choice in
        1) install_bot; echo -ne "\nНажмите Enter..."; read ;;
        2) list_bots; echo -ne "\nНажмите Enter..."; read ;;
        3) manage_bots; echo -ne "\nНажмите Enter..."; read ;;
        4) view_logs; echo -ne "\nНажмите Enter..."; read ;;
        5) delete_bot; echo -ne "\nНажмите Enter..."; read ;;
        6) msg "Выход."; exit 0 ;;
        *) error "Неверный выбор!"; sleep 1 ;;
    esac
done