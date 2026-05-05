import asyncio
import logging
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

# Исправленный импорт: IO всегда заглавными в APScheduler 3.x
try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
except ImportError:
    import apscheduler.schedulers.asyncio
    AsyncIOScheduler = apscheduler.schedulers.asyncio.AsyncIOScheduler

from config import BOT_TOKEN, SCHEDULER_CONFIG
from database import init_db

# Настройка логирования
logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())
# Используем корректное имя класса
scheduler = AsyncIOScheduler(config=SCHEDULER_CONFIG)

async def on_startup():
    # Инициализация БД
    await init_db()
    # Запуск планировщика, если он еще не запущен
    if not scheduler.running:
        scheduler.start()
    logging.info("Бот успешно запущен и готов к работе.")

async def main():
    # Регистрация обработчика запуска
    dp.startup.register(on_startup)
    
    # Здесь подключаются ваши роутеры (user_router, admin_router)
    
    try:
        await dp.start_polling(bot)
    finally:
        await bot.session.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logging.info("Бот остановлен.")