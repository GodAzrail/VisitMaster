from aiogram.types import ReplyKeyboardMarkup, KeyboardButton, InlineKeyboardMarkup, InlineKeyboardButton

def get_registration_kb():
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="📱 Отправить номер телефона", request_contact=True)]
        ],
        resize_keyboard=True,
        one_time_keyboard=True
    )

def get_main_menu_kb(is_admin=False):
    buttons = [
        [KeyboardButton(text="📅 Записаться"), KeyboardButton(text="📋 Мои записи")],
        [KeyboardButton(text="⭐️ Отзывы"), KeyboardButton(text="📊 Моя статистика")],
        [KeyboardButton(text="✏️ Мои данные")]
    ]
    if is_admin:
        buttons.append([KeyboardButton(text="🔐 Админ-панель")])
    
    return ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True)

def get_rating_kb():
    buttons = [
        [InlineKeyboardButton(text=f"{i} ★", callback_data=f"rate_{i}") for i in range(1, 6)],
        [InlineKeyboardButton(text="❌ Пропустить", callback_data="skip_review")]
    ]
    return InlineKeyboardMarkup(inline_keyboard=buttons)