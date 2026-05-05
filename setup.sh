#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Установка Telegram-бота записи клиентов ===${NC}"

# 1. Проверка Python
if ! command -v python3 &> /dev/null
then
    echo "Python3 не найден. Пожалуйста, установите его."
    exit
fi

# 2. Создание структуры
mkdir -p logs
mkdir -p data

# 3. Настройка окружения
if [ ! -f .env ]; then
    echo -e "${GREEN}--- Настройка переменных окружения ---${NC}"
    read -p "Введите токен бота: " token
    read -p "Введите ID главного админа: " admin_id
    read -p "Введите часовой пояс (например, Europe/Moscow): " tz
    
    echo "BOT_TOKEN=$token" > .env
    echo "SUPER_ADMIN_ID=$admin_id" >> .env
    echo "TIMEZONE=$tz" >> .env
else
    echo "Файл .env уже существует, пропускаю..."
fi

# 4. Установка зависимостей
echo -e "${GREEN}--- Установка зависимостей ---${NC}"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 5. Создание systemd сервиса
echo -e "${GREEN}--- Создание systemd сервиса ---${NC}"
CUR_DIR=$(pwd)
USER=$(whoami)

SERVICE_FILE="[Unit]
Description=Telegram Booking Bot Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$CUR_DIR
ExecStart=$CUR_DIR/venv/bin/python3 $CUR_DIR/main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target"

echo "$SERVICE_FILE" | sudo tee /etc/systemd/system/tg_booking_bot.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable tg_booking_bot.service

echo -e "${GREEN}=== Установка завершена! ===${NC}"
echo "Запустить бота: sudo systemctl start tg_booking_bot"
echo "Проверить статус: sudo systemctl status tg_booking_bot"
echo "Логи: journalctl -u tg_booking_bot -f"