import os
from dotenv import load_dotenv
from zoneinfo import ZoneInfo

load_dotenv()

BOT_TOKEN = os.getenv("BOT_TOKEN")
BOT_NAME = os.getenv("BOT_NAME", "tg_booking_bot") # Имя для systemd
DB_PATH = "bot_database.db"
TIMEZONE_STR = os.getenv("TIMEZONE", "Europe/Moscow")
TZ = ZoneInfo(TIMEZONE_STR)
SUPER_ADMIN_ID = int(os.getenv("SUPER_ADMIN_ID", 0))

SCHEDULER_CONFIG = {
    'apscheduler.jobstores.default': {
        'type': 'sqlalchemy',
        'url': f'sqlite:///{DB_PATH}'
    },
    'apscheduler.timezone': TIMEZONE_STR,
}