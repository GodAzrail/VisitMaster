from aiogram.fsm.state import State, StatesGroup

class RegistrationStates(StatesGroup):
    waiting_for_name = State()
    waiting_for_phone = State()

class AppointmentStates(StatesGroup):
    selecting_service = State()
    selecting_date = State()
    selecting_slot = State()

class ReviewStates(StatesGroup):
    waiting_for_rating = State()
    waiting_for_text = State()

class AdminStates(StatesGroup):
    main_menu = State()
    managing_services = State()
    editing_schedule = State()
    creating_broadcast = State()
    review_moderation = State()