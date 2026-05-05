from aiogram import Router, F, types
from database import get_db

router = Router()

@router.callback_query(F.data == "manage_schedule")
async def show_schedule_settings(callback: types.CallbackQuery):
    db = await get_db()
    async with db.execute("SELECT * FROM schedule_settings ORDER BY day_of_week") as cursor:
        settings = await cursor.fetchall()
    await db.close()
    
    days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    text = "📅 <b>Настройки расписания:</b>\n\n"
    
    builder = []
    for s in settings:
        status = "✅" if s['is_working'] else "❌"
        text += f"{days[s['day_of_week']]}: {s['start_time']}-{s['end_time']} {status}\n"
        builder.append([InlineKeyboardButton(text=f"Изменить {days[s['day_of_week']]}", callback_data=f"edit_day_{s['day_of_week']}")])
    
    await callback.message.edit_text(text, reply_markup=InlineKeyboardMarkup(inline_keyboard=builder), parse_mode="HTML")