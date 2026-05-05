#!/bin/bash

# Цвета
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BOLD='\033[1m'
export NC='\033[0m'

# Ссылка на ваш репозиторий
REPO_URL="https://github.com/GodAzrail/VisitMaster.git"

show_header() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BOLD}         VISIT MASTER: MULTI-BOT MANAGER         ${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

msg() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_bot_list() {
    # Ищем сервисы и извлекаем их технические имена
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
    
    read -p "Введите уникальное имя папки/бота (англ): " folder_name
    bot_service_name="tg_booking_$folder_name"
    target_dir="$(pwd)/$folder_name"

    if [ -d "$target_dir" ]; then
        error "Папка $folder_name уже существует!"
        return
    fi

    read -p "Telegram Bot Token: " token
    read -p "Admin Telegram ID: " admin_id
    read -p "Timezone (Asia/Krasnoyarsk): " tz

    # 1. Клонирование в отдельную папку
    msg "Клонирование репозитория в $target_dir..."
    git clone "$REPO_URL" "$target_dir" || { error "Ошибка клонирования!"; return; }
    
    cd "$target_dir" || return

    # 2. Создание .env
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
    echo "BOT_NAME=$bot_service_name" >> .env

    # 3. Настройка окружения
    msg "Настройка Python и зависимостей..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install --no-cache-dir APScheduler==3.10.4 aiogram==3.13.1 aiosqlite==0.20.0 python-dotenv ics -q

    # 4. Создание сервиса
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
    
    success "Бот установлен в $target_dir и запущен!"
    cd ..
}

delete_bot() {
    list_bots || return
    echo -ne "\n${BOLD}Введите НОМЕР для ПОЛНОГО УДАЛЕНИЯ (0 - отмена): ${NC}"
    read bot_num
    
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        
        # Определяем папку из WorkingDirectory сервиса
        folder_path=$(grep "WorkingDirectory" "/etc/systemd/system/$selected_bot.service" | cut -d'=' -f2)

        warn "Остановка и удаление $selected_bot..."
        sudo systemctl stop "$selected_bot"
        sudo systemctl disable "$selected_bot"
        sudo rm "/etc/systemd/system/$selected_bot.service"
        sudo systemctl daemon-reload
        
        if [ -d "$folder_path" ]; then
            read -p "Удалить также папку $folder_path? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                rm -rf "$folder_path"
                success "Папка удалена."
            fi
        fi
        success "Бот $selected_bot полностью удален."
    else
        error "Неверный выбор."
    fi
}

manage_bots() {
    list_bots || return
    echo -ne "\nНомер бота для управления: "; read bot_num
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        echo -e "1. Start  2. Stop  3. Restart"; read -p "Выбор: " act
        [[ "$act" == "1" ]] && sudo systemctl start "$selected_bot" && success "Запущен"
        [[ "$act" == "2" ]] && sudo systemctl stop "$selected_bot" && warn "Остановлен"
        [[ "$act" == "3" ]] && sudo systemctl restart "$selected_bot" && success "Перезагружен"
    fi
}

view_logs() {
    list_bots || return
    echo -ne "\nНомер бота для логов: "; read bot_num
    if [[ "$bot_num" =~ ^[0-9]+$ ]] && [ "$bot_num" -ge 1 ] && [ "$bot_num" -le "${#BOTS[@]}" ]; then
        selected_bot="${BOTS[$((bot_num-1))]}"
        sudo journalctl -u "$selected_bot" -f -n 50
    fi
}

while true; do
    show_header
    echo -e "  ${BLUE}1.${NC} Установить нового бота (Клонировать в новую папку)"
    echo -e "  ${BLUE}2.${NC} Список ботов и их статус"
    echo -e "  ${BLUE}3.${NC} Управление (Старт/Стоп/Перезагрузка)"
    echo -e "  ${BLUE}4.${NC} Просмотр логов"
    echo -e "  ${BLUE}5.${NC} ${RED}Удалить бота и его папку${NC}"
    echo -e "  ${BLUE}6.${NC} Выход"
    echo -ne "\n${BOLD}Выберите действие [1-6]: ${NC}"
    read choice

    case $choice in
        1) install_bot; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        2) list_bots; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        3) manage_bots; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        4) view_logs; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        5) delete_bot; echo -ne "\nНажмите Enter для продолжения..."; read ;;
        6) msg "Завершение работы. До свидания!"; exit 0 ;;
        *) error "Неверный выбор! Попробуйте снова."; sleep 1 ;;
    esac
done