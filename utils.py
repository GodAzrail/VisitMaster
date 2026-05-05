import asyncio
import html
import logging
from aiogram import Bot
from aiogram.exceptions import TelegramRetryAfter
from config import TZ

logger = logging.getLogger(__name__)

def escape_html_safe(text: str) -> str:
    """Экранирует HTML-теги, ограничивая длину до 500 символов."""
    if not text:
        return ""
    return html.escape(text[:500])

async def send_message_safe(bot: Bot, user_id: int, text: str, reply_markup=None):
    """Безопасная отправка сообщения с обработкой лимитов (Rate Limits)."""
    try:
        return await bot.send_message(
            chat_id=user_id,
            text=text,
            reply_markup=reply_markup,
            parse_mode="HTML"
        )
    except TelegramRetryAfter as e:
        logger.warning(f"Flood limit hit. Sleeping for {e.retry_after} seconds.")
        await asyncio.sleep(e.retry_after)
        return await send_message_safe(bot, user_id, text, reply_markup)
    except Exception as e:
        logger.error(f"Failed to send message to {user_id}: {e}")
        return None

def format_datetime(dt):
    """Приведение времени к строке в локальном часовом поясе."""
    return dt.astimezone(TZ).strftime("%d.%m.%Y %H:%M")