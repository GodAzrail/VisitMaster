import asyncio
from aiogram import Router, F, types
from aiogram.fsm.context import FSMContext
from states import AdminStates
from database import get_db
from utils import send_message_safe
from main import bot

router = Router()

@router.message(AdminStates.creating_broadcast)
async def process_broadcast_text(message: types.Message, state: FSMContext):
    broadcast_text = message.text
    db = await get_db()
    async with db.execute("SELECT user_id FROM users") as cursor:
        users = await cursor.fetchall()
    
    sent_count = 0
    await message.answer(f"🚀 Начинаю рассылку на {len(users)} пользователей...")

    for user in users:
        # Используем безопасную функцию с обработкой RetryAfter
        success = await send_message_safe(bot, user['user_id'], broadcast_text)
        if success:
            sent_count += 1
        # Небольшая пауза между сообщениями для профилактики Flood
        await asyncio.sleep(0.05) 

    await message.answer(f"✅ Рассылка завершена. Доставлено: {sent_count}/{len(users)}")
    await state.clear()