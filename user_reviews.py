from database import get_db

async def get_public_reviews(limit: int = 5):
    """Возвращает последние опубликованные отзывы заведения."""
    db = await get_db()
    query = """
        SELECT r.rating, r.review_text, u.full_name, r.created_at 
        FROM reviews r
        JOIN users u ON r.user_id = u.user_id
        WHERE r.is_published = 1
        ORDER BY r.created_at DESC LIMIT ?
    """
    async with db.execute(query, (limit,)) as cursor:
        rows = await cursor.fetchall()
    await db.close()
    
    if not rows:
        return "📢 Пока отзывов нет. Будьте первыми!"
    
    text = "📢 <b>Отзывы наших клиентов:</b>\n\n"
    for row in rows:
        stars = "⭐" * row['rating'] if row['rating'] else "📝"
        text += f"{stars} <b>{row['full_name']}</b>\n«{row['review_text']}»\n<i>{row['created_at']}</i>\n\n"
    return text