import asyncio
import logging
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

# 1. Импорт настроек и БД
from config import BOT_TOKEN, SCHEDULER_CONFIG
from database import init_db

# 2. ИМПОРТ ВАШИХ РОУТЕРОВ 
# Замените 'handlers' на название вашей папки с обработчиками
# Предположим, у вас есть файлы handlers/user.py и handlers/admin.py
try:
    from handlers.user import router as user_router
    from handlers.admin import router as admin_router
    HAS_HANDLERS = True
except ImportError:
    logging.warning("Файлы обработчиков не найдены. Бот запустится в режиме ожидания.")
    HAS_HANDLERS = False

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# Инициализация бота и диспетчера
bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())

# Исправленный импорт планировщика (как обсуждали ранее)
try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
except ImportError:
    import apscheduler.schedulers.asyncio
    AsyncIOScheduler = apscheduler.schedulers.asyncio.AsyncIOScheduler

scheduler = AsyncIOScheduler(config=SCHEDULER_CONFIG)

async def on_startup():
    """Действия при запуске бота"""
    # Создаем таблицы в БД если их нет
    await init_db()
    
    # Запуск планировщика
    if not scheduler.running:
        scheduler.start()
        
    logging.info("--- БОТ УСПЕШНО ЗАПУЩЕН И ГОТОВ К РАБОТЕ ---")

async def main():
    # Регистрация функции запуска
    dp.startup.register(on_startup)
    
    # 3. ПОДКЛЮЧЕНИЕ РОУТЕРОВ
    # Если роутеры импортированы, добавляем их в диспетчер
    if HAS_HANDLERS:
        dp.include_router(user_router)
        dp.include_router(admin_router)
        logging.info("Все роутеры успешно подключены.")
    
    try:
        # Удаляем вебхуки и запускаем polling (прослушивание серверов Telegram)
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)
    finally:
        # Закрываем сессию при выключении
        await bot.session.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logging.info("Бот принудительно остановлен.")