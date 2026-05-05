import asyncio
import logging
import os
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage

# 1. Импорт настроек и базы данных
from config import BOT_TOKEN, SCHEDULER_CONFIG
from database import init_db

# 2. Попытка импорта ваших обработчиков
# ВНИМАНИЕ: Проверьте, что папка 'handlers' существует и в ней есть файлы 'user.py' и 'admin.py'
try:
    from handlers.user import router as user_router
    from handlers.admin import router as admin_router
    HAS_HANDLERS = True
except ImportError as e:
    logging.warning(f"Не удалось импортировать обработчики: {e}")
    logging.warning("Бот запущен в РЕЖИМЕ ОЖИДАНИЯ. Проверьте структуру папок и наличие файлов в handlers/")
    HAS_HANDLERS = False

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

# 3. Настройка планировщика (APScheduler)
try:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
except ImportError:
    # Запасной вариант для разных версий библиотеки
    import apscheduler.schedulers.asyncio
    AsyncIOScheduler = apscheduler.schedulers.asyncio.AsyncIOScheduler

scheduler = AsyncIOScheduler(config=SCHEDULER_CONFIG)

# Инициализация бота и диспетчера
bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(storage=MemoryStorage())

async def on_startup():
    """Функция, выполняемая при запуске бота"""
    # Инициализация базы данных (создание таблиц)
    await init_db()
    
    # Запуск планировщика задач
    if not scheduler.running:
        scheduler.start()
    
    logging.info("--- СИСТЕМА ГОТОВА: Бот авторизован и запущен ---")

async def main():
    # Регистрация обработчика запуска
    dp.startup.register(on_startup)
    
    # 4. ПОДКЛЮЧЕНИЕ РОУТЕРОВ
    # Если файлы найдены, подключаем их к основному диспетчеру
    if HAS_HANDLERS:
        dp.include_router(user_router)
        dp.include_router(admin_router)
        logging.info("Все обработчики (user, admin) успешно подключены.")
    
    try:
        # Очищаем очередь накопившихся сообщений и запускаем прослушивание
        await bot.delete_webhook(drop_pending_updates=True)
        await dp.start_polling(bot)
    finally:
        # Закрываем соединение при остановке
        await bot.session.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logging.info("Бот остановлен пользователем.")