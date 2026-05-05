import asyncio
import logging
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage
from apscheduler.schedulers.asyncio import AsyncioScheduler

from config import BOT_TOKEN, SCHEDULER_CONFIG
from database import init_db

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Инициализация бота и диспетчера
bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())

# Инициализация планировщика APScheduler
scheduler = AsyncioScheduler(config=SCHEDULER_CONFIG)

async def on_startup():
    # Инициализация БД (WAL mode включен внутри init_db)
    await init_db()
    # Запуск планировщика
    scheduler.start()
    logging.info("Бот успешно запущен и готов к работе.")

async def main():
    # Здесь в будущем будут подключены роутеры:
    # dp.include_router(user_router)
    # dp.include_router(admin_router)
    
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