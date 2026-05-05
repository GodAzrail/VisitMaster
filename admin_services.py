from aiogram import Router, F, types
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from database import get_db

router = Router()

def get_services_keyboard(services, page: int = 0, limit: int = 5):
    """Клавиатура услуг с пагинацией."""
    start = page * limit
    end = start + limit
    current_services = services[start:end]
    
    builder = []
    for s in current_services:
        builder.append([InlineKeyboardButton(text=f"✏️ {s['name']} - {s['price']}₽", callback_data=f"edit_svc_{s['id']}")])
    
    navigation = []
    if page > 0:
        navigation.append(InlineKeyboardButton(text="⬅️", callback_data=f"svc_page_{page-1}"))
    if end < len(services):
        navigation.append(InlineKeyboardButton(text="➡️", callback_data=f"svc_page_{page+1}"))
    
    if navigation:
        builder.append(navigation)
    builder.append([InlineKeyboardButton(text="➕ Добавить услугу", callback_data="add_service")])
    
    return InlineKeyboardMarkup(inline_keyboard=builder)

@router.callback_query(F.data.startswith("svc_page_"))
async def paginate_services(callback: types.CallbackQuery):
    page = int(callback.data.split("_")[2])
    db = await get_db()
    async with db.execute("SELECT * FROM services") as cursor:
        services = await cursor.fetchall()
    await db.close()
    
    await callback.message.edit_reply_markup(reply_markup=get_services_keyboard(services, page))