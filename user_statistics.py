import logging
from database import get_db

async def get_user_stats_text(user_id: int) -> str:
    db = await get_db()
    try:
        # Сводная статистика
        query = """
            SELECT 
                COUNT(id) as total_visits,
                SUM((SELECT price FROM services WHERE id = service_id)) as total_spent,
                MAX(appointment_time) as last_visit
            FROM appointments 
            WHERE user_id = ? AND status = 'completed'
        """
        async with db.execute(query, (user_id,)) as cursor:
            main_stats = await cursor.fetchone()

        # Средняя оценка, которую поставил пользователь
        async with db.execute("SELECT AVG(rating) FROM reviews WHERE user_id = ?", (user_id,)) as cursor:
            avg_rating_row = await cursor.fetchone()
            avg_rating = round(avg_rating_row[0], 1) if avg_rating_row[0] else 0

        if not main_stats or main_stats['total_visits'] == 0:
            return "📊 <b>Ваша статистика:</b>\n\nУ вас пока нет завершенных визитов."

        text = (
            f"📊 <b>Ваша статистика:</b>\n"
            f"━━━━━━━━━━━━━━━\n"
            f"✅ Всего визитов: <b>{main_stats['total_visits']}</b>\n"
            f"💰 Потрачено всего: <b>{main_stats['total_spent'] or 0} ₽</b>\n"
            f"📅 Последний визит: <b>{main_stats['last_visit']}</b>\n"
            f"⭐️ Ваша средняя оценка: <b>{avg_rating} ★</b>\n"
        )
        return text
    finally:
        await db.close()