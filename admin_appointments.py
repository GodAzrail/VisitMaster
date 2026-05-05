from aiogram import Router, F, types
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from database import get_db
from review_requests import schedule_review_request, cancel_review_request
from main import scheduler, bot # Доступ к планировщику

router = Router()

@router.callback_query(F.data.startswith("status_complete_"))
async def mark_as_completed(callback: types.CallbackQuery):
    """Отметка записи как выполненной и планирование запроса отзыва."""
    app_id = int(callback.data.split("_")[2])
    
    db = await get_db()
    # Получаем user_id для планировщика
    async with db.execute("SELECT user_id FROM appointments WHERE id = ?", (app_id,)) as cursor:
        row = await cursor.fetchone()
    
    if row:
        user_id = row['user_id']
        # Обновляем статус в БД
        await db.execute("UPDATE appointments SET status = 'completed' WHERE id = ?", (app_id,))
        await db.commit()
        
        # ТРИГГЕР: Планируем запрос отзыва через 1 час (настраиваемо)
        await schedule_review_request(scheduler, bot, app_id, user_id, delay_hours=1)
        
        await callback.answer("✅ Статус обновлен. Запрос отзыва запланирован.")
        await callback.message.edit_text(f"Запись #{app_id} выполнена.")
    
    await db.close()

@router.callback_query(F.data.startswith("status_cancel_"))
async def cancel_appointment_admin(callback: types.CallbackQuery):
    """Отмена записи и отмена запланированного отзыва."""
    app_id = int(callback.data.split("_")[2])
    
    db = await get_db()
    await db.execute("UPDATE appointments SET status = 'cancelled' WHERE id = ?", (app_id,))
    await db.commit()
    await db.close()
    
    # ОТМЕНА ТРИГГЕРА: Удаляем задачу из планировщика, если она была
    await cancel_review_request(scheduler, app_id)
    
    await callback.answer("❌ Запись отменена, запрос отзыва удален.")
    await callback.message.delete()