import asyncio
import logging
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

# Гибкий импорт для обхода ошибок в новых версиях Python/APScheduler
try:
    from apscheduler.schedulers.asyncio import AsyncioScheduler
except ImportError:
    import apscheduler.schedulers.asyncio
    AsyncioScheduler = apscheduler.schedulers.asyncio.AsyncioScheduler

from config import BOT_TOKEN, SCHEDULER_CONFIG
from database import init_db

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())
scheduler = AsyncioScheduler(config=SCHEDULER_CONFIG)

async def on_startup():
    await init_db()
    if not scheduler.running:
        scheduler.start()
    logging.info("Бот успешно запущен и готов к работе.")

async def main():
    # Импорт роутеров здесь во избежание круговых импортов
    # dp.include_router(user_router)
    
    dp.startup.register(on_startup)
    try:
        await dp.start_polling(bot)
    finally:
        await bot.session.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logging.info("Бот остановлен.")