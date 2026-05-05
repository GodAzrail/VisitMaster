import logging
from datetime import datetime, timedelta
from aiogram import Bot
from apscheduler.schedulers.asyncio import AsyncioScheduler

from config import TZ
from utils import send_message_safe, escape_html_safe
from database import get_db
from keyboards import get_rating_kb

logger = logging.getLogger(__name__)

async def schedule_review_request(scheduler: AsyncioScheduler, bot: Bot, appointment_id: int, user_id: int, delay_hours: int = 1):
    """
    Планирует задачу на запрос отзыва. Job ID привязан к ID записи.
    """
    run_date = datetime.now(TZ) + timedelta(hours=delay_hours)
    job_id = f"review_req_{appointment_id}"
    
    # Если задача уже была запланирована (например, статус меняли дважды), удаляем старую
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)

    scheduler.add_job(
        send_review_request,
        'date',
        run_date=run_date,
        args=[bot, appointment_id, user_id],
        id=job_id,
        replace_existing=True
    )
    logger.info(f"Scheduled review request for app_id {appointment_id} at {run_date}")

async def cancel_review_request(scheduler: AsyncioScheduler, appointment_id: int):
    """Отменяет запрос отзыва, если статус записи изменился с 'completed'."""
    job_id = f"review_req_{appointment_id}"
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)

async def send_review_request(bot: Bot, appointment_id: int, user_id: int):
    """Отправляет сообщение с кнопками оценки."""
    db = await get_db()
    try:
        # Проверяем, не оставлял ли пользователь отзыв уже
        async with db.execute("SELECT id FROM reviews WHERE appointment_id = ?", (appointment_id,)) as cursor:
            if await cursor.fetchone():
                return

        async with db.execute(
            "SELECT s.name FROM appointments a JOIN services s ON a.service_id = s.id WHERE a.id = ?", 
            (appointment_id,)
        ) as cursor:
            service = await cursor.fetchone()

        service_name = service['name'] if service else "услугу"
        
        text = (
            f"⭐️ <b>Спасибо, что посетили нас!</b>\n\n"
            f"Как прошёл ваш визит на услугу «{service_name}»?\n"
            f"Пожалуйста, оцените нашу работу или напишите отзыв текстом."
        )
        
        await send_message_safe(bot, user_id, text, reply_markup=get_rating_kb())
        
        # Логируем попытку запроса
        await db.execute(
            "INSERT INTO review_requests_log (appointment_id, attempts, last_attempt) "
            "VALUES (?, 1, CURRENT_TIMESTAMP) "
            "ON CONFLICT(appointment_id) DO UPDATE SET attempts = attempts + 1, last_attempt = CURRENT_TIMESTAMP",
            (appointment_id,)
        )
        await db.commit()
        
    except Exception as e:
        logger.error(f"Error in send_review_request: {e}")
    finally:
        await db.close()

async def save_review_to_db(user_id: int, appointment_id: int, rating: int = None, text: str = None):
    """Сохраняет отзыв с обязательным экранированием текста."""
    db = await get_db()
    safe_text = escape_html_safe(text) if text else None
    
    await db.execute(
        "INSERT INTO reviews (appointment_id, user_id, rating, review_text) VALUES (?, ?, ?, ?)",
        (appointment_id, user_id, rating, safe_text)
    )
    await db.commit()
    await db.close()