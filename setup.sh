#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

show_menu() {
    echo -e "${GREEN}=== Управление VisitMaster ===${NC}"
    echo "1. Установить нового бота"
    echo "2. Показать запущенных ботов"
    echo "3. Удалить бота"
    echo "4. Выход"
    read -p "Выберите действие [1-4]: " choice
}

list_bots() {
    echo -e "${GREEN}--- Запущенные боты (systemd) ---${NC}"
    systemctl list-units --type=service | grep "tg_booking_"
}

delete_bot() {
    list_bots
    read -p "Введите полное название сервиса для удаления (например, tg_booking_mybot): " service_name
    if [ -f "/etc/systemd/system/$service_name.service" ]; then
        sudo systemctl stop $service_name
        sudo systemctl disable $service_name
        sudo rm "/etc/systemd/system/$service_name.service"
        sudo systemctl daemon-reload
        echo -e "${GREEN}Бот $service_name успешно удален.${NC}"
    else
        echo -e "${RED}Сервис не найден.${NC}"
    fi
}

install_bot() {
    echo -e "${GREEN}--- Настройка нового бота ---${NC}"
    read -p "Введите техническое имя бота (английские буквы, например: 'mybot'): " short_name
    bot_service_name="tg_booking_$short_name"
    
    read -p "Введите токен бота: " token
    read -p "Введите ID админа: " admin_id
    read -p "Введите часовой пояс (напр. Asia/Krasnoyarsk): " tz
    
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
    echo "BOT_NAME=$bot_service_name" >> .env

    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    # Принудительная установка стабильной версии для Python 3.13
    pip install --no-cache-dir APScheduler==3.10.4 aiogram==3.13.1 aiosqlite==0.20.0 python-dotenv ics
    
    CUR_DIR=$(pwd)
    USER=$(whoami)

    SERVICE_FILE="[Unit]
Description=Telegram Bot $bot_service_name
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$CUR_DIR
ExecStart=$CUR_DIR/venv/bin/python3 $CUR_DIR/main.py
Restart=always

[Install]
WantedBy=multi-user.target"

    echo "$SERVICE_FILE" | sudo tee /etc/systemd/system/$bot_service_name.service > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable $bot_service_name
    sudo systemctl start $bot_service_name
    
    echo -e "${GREEN}Бот $bot_service_name запущен!${NC}"
}

while true; do
    show_menu
    case $choice in
        1) install_bot ;;
        2) list_bots ;;
        3) delete_bot ;;
        4) exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}" ;;
    esac
done