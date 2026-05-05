from aiogram import Router, F, types
from aiogram.filters import CommandStart, StateFilter
from aiogram.fsm.context import FSMContext
from datetime import datetime, timedelta

from database import get_db
from states import RegistrationStates, AppointmentStates
from keyboards import get_registration_kb, get_main_menu_kb
from reminders import send_visit_reminder
from main import bot, scheduler # Импорт из main для доступа к scheduler
from config import TZ

router = Router()

@router.message(CommandStart())
async def cmd_start(message: types.Message, state: FSMContext):
    db = await get_db()
    async with db.execute("SELECT * FROM users WHERE user_id = ?", (message.from_user.id,)) as cursor:
        user = await cursor.fetchone()
    await db.close()

    if user:
        await message.answer(f"С возвращением, {user['full_name']}!", reply_markup=get_main_menu_kb())
    else:
        await message.answer("Добро пожаловать! Давайте зарегистрируемся. Введите ваше ФИО:", reply_markup=types.ReplyKeyboardRemove())
        await state.set_state(RegistrationStates.waiting_for_name)

@router.message(RegistrationStates.waiting_for_name)
async def process_name(message: types.Message, state: FSMContext):
    await state.update_data(full_name=message.text)
    await message.answer("Отлично! Теперь поделитесь номером телефона, нажав на кнопку ниже:", reply_markup=get_registration_kb())
    await state.set_state(RegistrationStates.waiting_for_phone)

@router.message(RegistrationStates.waiting_for_phone, F.contact)
async def process_phone(message: types.Message, state: FSMContext):
    data = await state.get_data()
    db = await get_db()
    await db.execute(
        "INSERT INTO users (user_id, full_name, phone) VALUES (?, ?, ?)",
        (message.from_user.id, data['full_name'], message.contact.phone_number)
    )
    await db.commit()
    await db.close()
    
    await message.answer("Регистрация завершена!", reply_markup=get_main_menu_kb())
    await state.clear()

# Пример упрощенной логики записи (для краткости)
@router.message(F.text == "📅 Записаться")
async def start_appointment(message: types.Message, state: FSMContext):
    # Здесь должна быть логика выбора услуги и времени
    # После выбора времени (app_time_dt):
    # 1. Сохраняем в БД
    # 2. Планируем напоминания:
    
    # scheduler.add_job(send_visit_reminder, 'date', 
    #                   run_date=app_time_dt - timedelta(hours=24), 
    #                   args=[bot, app_id, user_id, "24h"])
    await message.answer("Функционал выбора услуг и времени будет реализован в следующем шаге.")

@router.message(F.text == "📊 Моя статистика")
async def show_stats(message: types.Message):
    from user_statistics import get_user_stats_text
    text = await get_user_stats_text(message.from_user.id)
    await message.answer(text)