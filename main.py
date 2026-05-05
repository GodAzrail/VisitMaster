import asyncio
import logging
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

# 1. Импорт конфига и БД
from config import BOT_TOKEN, SCHEDULER_CONFIG
from database import init_db

# 2. Импорт ВСЕХ модулей с роутерами
# Мы импортируем их напрямую, так как папки handlers нет
try:
    from user_handlers import router as user_router
    from admin_appointments import router as admin_app_router
    from admin_broadcast import router as admin_br_router
    from admin_reviews import router as admin_rev_router
    from admin_schedule import router as admin_sch_router
    from admin_services import router as admin_ser_router
    from admin_statistics import router as admin_stat_router
    from user_reviews import router as user_rev_router
    # Добавьте остальные, если в них есть router
    HAS_HANDLERS = True
except ImportError as e:
    logging.error(f"Ошибка импорта: {e}")
    HAS_HANDLERS = False

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Починка импорта планировщика для Python 3.13
try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
except ImportError:
    import apscheduler.schedulers.asyncio
    AsyncIOScheduler = apscheduler.schedulers.asyncio.AsyncIOScheduler

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())
scheduler = AsyncIOScheduler(config=SCHEDULER_CONFIG)

async def on_startup():
    await init_db()
    if not scheduler.running:
        scheduler.start()
    logging.info("Бот успешно инициализирован.")

async def main():
    dp.startup.register(on_startup)

    # 3. Регистрация ВСЕХ роутеров в диспетчере
    if HAS_HANDLERS:
        dp.include_router(user_router)
        dp.include_router(admin_app_router)
        dp.include_router(admin_br_router)
        dp.include_router(admin_rev_router)
        dp.include_router(admin_sch_router)
        dp.include_router(admin_ser_router)
        dp.include_router(admin_stat_router)
        dp.include_router(user_rev_router)
        logging.info("Все модули логики подключены.")

    await bot.delete_webhook(drop_pending_updates=True)
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())