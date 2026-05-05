import os
from dotenv import load_dotenv
from zoneinfo import ZoneInfo

load_dotenv()

# Telegram Bot Token
BOT_TOKEN = os.getenv("BOT_TOKEN")

# Путь к базе данных
DB_PATH = "bot_database.db"

# Часовой пояс (по умолчанию Москва, можно менять через .env)
TIMEZONE_STR = os.getenv("TIMEZONE", "Europe/Moscow")
TZ = ZoneInfo(TIMEZONE_STR)

# ID главного администратора (из .env)
SUPER_ADMIN_ID = int(os.getenv("SUPER_ADMIN_ID", 0))

# Настройки планировщика
SCHEDULER_CONFIG = {
    'apscheduler.jobstores.default': {
        'type': 'sqlalchemy',
        'url': f'sqlite:///{DB_PATH}'
    },
    'apscheduler.executors.default': {
        'class': 'apscheduler.executors.pool:ThreadPoolExecutor',
        'max_workers': '20'
    },
    'apscheduler.job_defaults.coalesce': 'false',
    'apscheduler.job_defaults.max_instances': '3',
    'apscheduler.timezone': TIMEZONE_STR,
}