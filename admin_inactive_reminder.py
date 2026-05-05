from aiogram import Router, F, types
from database import get_db
from datetime import datetime, timedelta

router = Router()

@router.callback_query(F.data == "find_inactive")
async def find_inactive_users(callback: types.CallbackQuery):
    db = await get_db()
    # Ищем пользователей, чья последняя запись была > 30 дней назад
    thirty_days_ago = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d %H:%M:%S')
    
    query = """
        SELECT u.user_id, u.full_name, MAX(a.appointment_time) as last_date
        FROM users u
        JOIN appointments a ON u.user_id = a.user_id
        GROUP BY u.user_id
        HAVING last_date < ?
    """
    async with db.execute(query, (thirty_days_ago,)) as cursor:
        inactive = await cursor.fetchall()
    await db.close()

    if not inactive:
        return await callback.answer("Все клиенты активны! ✨")

    text = f"🕵️‍♂️ Найдено неактивных клиентов: {len(inactive)}\n\n"
    # Здесь можно предложить запустить по ним рассылку с акцией
    await callback.message.answer(text)