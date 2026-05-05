import os
from dotenv import load_dotenv
from zoneinfo import ZoneInfo

load_dotenv()

# Основные токены и ID
BOT_TOKEN = os.getenv("BOT_TOKEN")
SUPER_ADMIN_ID = int(os.getenv("SUPER_ADMIN_ID", 0))

# Настройки времени
TIMEZONE_STR = os.getenv("TIMEZONE", "Asia/Krasnoyarsk")
TZ = ZoneInfo(TIMEZONE_STR)

# Пути и имена
DB_PATH = "bot_database.db"
BOT_NAME = os.getenv("BOT_NAME", "tg_booking_bot")

# Конфигурация планировщика
SCHEDULER_CONFIG = {
    'apscheduler.jobstores.default': {
        'type': 'sqlalchemy',
        'url': f'sqlite:///{DB_PATH}'
    },
    'apscheduler.timezone': TIMEZONE_STR,
}