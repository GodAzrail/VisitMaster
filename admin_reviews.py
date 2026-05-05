from aiogram import Router, F, types
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from database import get_db

router = Router()

def get_review_mgmt_kb(review_id, is_published, page):
    btns = []
    if not is_published:
        btns.append([InlineKeyboardButton(text="✅ Опубликовать", callback_data=f"rev_pub_{review_id}_{page}")])
    else:
        btns.append([InlineKeyboardButton(text="🚫 Скрыть", callback_data=f"rev_hide_{review_id}_{page}")])
    
    btns.append([InlineKeyboardButton(text="🗑 Удалить", callback_data=f"rev_del_{review_id}_{page}")])
    btns.append([InlineKeyboardButton(text="⬅️ Назад к списку", callback_data=f"rev_list_{page}")])
    return InlineKeyboardMarkup(inline_keyboard=btns)

@router.callback_query(F.data.startswith("rev_pub_"))
async def publish_review(callback: types.CallbackQuery):
    _, _, rev_id, page = callback.data.split("_")
    db = await get_db()
    await db.execute("UPDATE reviews SET is_published = 1 WHERE id = ?", (rev_id,))
    await db.commit()
    await db.close()
    await callback.answer("Отзыв опубликован!")
    # Здесь можно вызвать функцию обновления списка