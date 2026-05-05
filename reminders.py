import logging
from datetime import timedelta
from aiogram import Bot
from config import TZ
from utils import send_message_safe
from database import get_db

logger = logging.getLogger(__name__)

async def send_visit_reminder(bot: Bot, appointment_id: int, user_id: int, time_type: str):
    """
    Отправка напоминания за 24 часа или 1 час до визита.
    """
    db = await get_db()
    try:
        async with db.execute(
            "SELECT a.appointment_time, s.name FROM appointments a "
            "JOIN services s ON a.service_id = s.id WHERE a.id = ?", (appointment_id,)
        ) as cursor:
            row = await cursor.fetchone()
            
        if not row:
            return

        service_name = row['name']
        app_time = row['appointment_time']
        
        text = (
            f"🔔 Напоминание о визите!\n"
            f"Услуга: <b>{service_name}</b>\n"
            f"Время: <b>{app_time}</b>\n\n"
            f"Ждем вас!"
        )
        
        await send_message_safe(bot, user_id, text)
        
        # Логируем отправку
        await db.execute(
            "INSERT INTO notifications_log (user_id, type) VALUES (?, ?)",
            (user_id, f"reminder_{time_type}")
        )
        await db.commit()
    except Exception as e:
        logger.error(f"Error sending reminder: {e}")
    finally:
        await db.close()