from aiogram import Router, F, types
from database import get_db

router = Router()

@router.callback_query(F.data == "admin_stats")
async def show_admin_stats(callback: types.CallbackQuery):
    db = await get_db()
    
    # 1. Общая загрузка и популярная услуга
    query_pop = """
        SELECT s.name, COUNT(a.id) as count 
        FROM appointments a JOIN services s ON a.service_id = s.id 
        WHERE a.status = 'completed' GROUP BY s.name ORDER BY count DESC LIMIT 1
    """
    # 2. Средний рейтинг
    query_rating = "SELECT AVG(rating) as avg_r, COUNT(id) as total_r FROM reviews"
    # 3. Конверсия в отзывы
    query_conv = """
        SELECT 
            (SELECT COUNT(*) FROM appointments WHERE status = 'completed') as total_apps,
            (SELECT COUNT(*) FROM reviews) as total_revs
    """
    
    async with db.execute(query_pop) as c: pop_svc = await c.fetchone()
    async with db.execute(query_rating) as c: rating_data = await c.fetchone()
    async with db.execute(query_conv) as c: conv_data = await c.fetchone()
    await db.close()

    total_apps = conv_data['total_apps'] or 1
    conv_pc = round((conv_data['total_revs'] / total_apps) * 100, 1)

    text = (
        f"📈 <b>Аналитика заведения:</b>\n\n"
        f"🔥 Популярная услуга: <b>{pop_svc['name'] if pop_svc else 'Нет данных'}</b>\n"
        f"⭐️ Средний рейтинг: <b>{round(rating_data['avg_r'] or 0, 2)} ★</b>\n"
        f"📊 Всего отзывов: <b>{rating_data['total_r']}</b>\n"
        f"💬 Конверсия в отзывы: <b>{conv_pc}%</b>\n"
        f"✅ Выполнено заказов: <b>{total_apps}</b>"
    )
    
    await callback.message.edit_text(text, parse_mode="HTML")