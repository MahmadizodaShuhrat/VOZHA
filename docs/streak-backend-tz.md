# ТЗ: Streak (серия дней активности) для VozhaOmuz

**Версия:** 1.0
**Дата:** 2026-04-19
**Фронтенд:** Flutter (UI уже реализован, ждёт эндпоинт и аудит поля `days_active`)
**Backend:** ваша реализация

---

## 1. Обзор

Streak — число подряд идущих дней активности пользователя, аналог Duolingo. Пользователь видит текущее число на главном экране (🔥 N), тапает и открывает календарь с подсветкой активных дней и рекордом самой длинной серии.

Сейчас бекенд уже возвращает `days_active` в `GET /dict/profile-rating`, но:
1. Правила инкремента не задокументированы и нуждаются в аудите.
2. Нет эндпоинта для истории активности (календарь).

---

## 2. Бизнес-правила

| Параметр | Значение |
|---|---|
| Граница дня | **00:00 UTC** (не локальное время пользователя) |
| Что считается «активностью» | **Только успешно завершённая игровая сессия** — пользователь дошёл до экрана результатов (`result_game_page`). Прерванная (system back, вышел из приложения, закончилась энергия) **не считается**. Вход в приложение или просто открытие не считается. |
| Порог «серия сломалась» | gap > 1 календарного дня в UTC |
| Начальное значение при регистрации | `days_active = 0` (или 1 — если считаем регистрацию активностью) |
| Реактивация (через неделю, например) | `days_active = 1` |

---

## 3. Схема БД

### 3.1 Таблица `users` — добавить 2 поля

```sql
ALTER TABLE users ADD COLUMN days_active INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN longest_streak INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN last_active_day_utc DATE;
```

| Поле | Тип | Описание |
|---|---|---|
| `days_active` | INT | Текущая серия. Уже есть, но логика требует аудита. |
| `longest_streak` | INT | Рекорд всех времён. Обновляется при `days_active > longest_streak`. |
| `last_active_day_utc` | DATE | Последний день активности (UTC, без времени). Используется для решения про инкремент. |

### 3.2 Таблица `user_activity_days` (опционально, для календаря)

Если хотите показывать историю активности за прошлые месяцы:

```sql
CREATE TABLE user_activity_days (
  user_id INTEGER NOT NULL REFERENCES users(id),
  activity_day_utc DATE NOT NULL,
  event_count INTEGER NOT NULL DEFAULT 1,  -- сколько событий за день
  PRIMARY KEY (user_id, activity_day_utc)
);
CREATE INDEX idx_activity_user_month ON user_activity_days(user_id, activity_day_utc);
```

Альтернатива — считать активность на лету из существующих таблиц (game_results, sync_activity). Решите по нагрузке.

---

## 4. Алгоритм инкремента

При каждом событии активности (завершение игры, синк):

```python
def mark_activity(user):
    today_utc = datetime.now(timezone.utc).date()
    last = user.last_active_day_utc

    # Уже был сегодня — ничего не меняем
    if last == today_utc:
        return

    # Первый раз, или серия сломалась
    if last is None or (today_utc - last).days > 1:
        user.days_active = 1
    # Вчера был активен — продолжаем серию
    elif (today_utc - last).days == 1:
        user.days_active += 1
    # (today_utc - last).days < 0 — часы в прошлом; игнор
    else:
        return

    # Обновляем рекорд
    if user.days_active > user.longest_streak:
        user.longest_streak = user.days_active

    user.last_active_day_utc = today_utc
    user.save()

    # Опционально — лог дня в user_activity_days
    db.upsert_user_activity_day(user.id, today_utc)
```

### 4.1 Edge cases

| Сценарий | Поведение |
|---|---|
| Пользователь был активен 2026-04-17, **играет** 2026-04-19 | gap = 2 дня → `days_active = 1` (серия сбрасывается) |
| Пользователь был активен 2026-04-18, **играет** 2026-04-19 | gap = 1 день → `days_active += 1` |
| Пользователь был активен 2026-04-18 в 23:59 UTC и **играет** в 00:01 UTC 2026-04-19 | два разных дня → `days_active += 1` |
| Пользователь переводит часы на телефоне назад | backend считает только `NOW() UTC`, манипуляции игнорируются |
| Параллельные события от двух устройств одновременно | нужен row-level lock (`SELECT … FOR UPDATE`), чтобы счёт не задублировался |
| **Пользователь пропустил 5 дней, просто открывает профиль (без игры)** | `mark_activity` не срабатывает → в БД старое значение. Но `GET /dict/profile-rating` и `GET /user/activity` должны возвращать **0** через функцию `current_streak()` (см. §4.3) |

### 4.3 Lazy expiry on read — **обязательно**

Записи в `days_active` происходят только при активности. Если пользователь просто перестал играть, запись не обновляется, но серия сломана де-факто. Поэтому **на чтении** всегда применяйте:

```python
def current_streak(user) -> int:
    """Возвращает актуальный streak с учётом lazy-expiry."""
    if user.last_active_day_utc is None:
        return 0
    today_utc = datetime.now(timezone.utc).date()
    gap = (today_utc - user.last_active_day_utc).days
    if gap > 1:
        return 0  # серия сломана, но ещё не «прописана» в БД
    return user.days_active
```

Используйте `current_streak(user)` везде, где отдаёте значение клиенту:
- в `GET /dict/profile-rating` → поле `days_active`
- в `GET /user/activity` → поле `current_streak`

Без этого клиент увидит устаревшее число («17 дней подряд») у человека, который не заходил неделю.

Опционально — при следующем `mark_activity` вы всё равно пересчитаете значение (gap > 1 → `days_active = 1`), так что запись в БД «самоисцелится» при возвращении пользователя.

### 4.2 Работа с оплаченным сломом серии

Если захочется монетизировать (Duolingo-style: «восстанови серию за 100 монет»):

```python
def buy_streak_repair(user, days_to_restore):
    if user.streak_repair_available():
        user.days_active += days_to_restore
        if user.days_active > user.longest_streak:
            user.longest_streak = user.days_active
        user.save()
```

На MVP не обязательно, но схема не мешает.

---

## 5. API

### 5.1 `GET /user/activity` — новый эндпоинт

Возвращает список активных дней за указанный месяц + текущие стрик-показатели. Используется клиентским календарём.

**Request:**
```
GET /api/v1/user/activity?year=2026&month=4
Authorization: Bearer <token>
```

| Параметр | Тип | Обязательный | Дефолт |
|---|---|---|---|
| `year` | int | нет | текущий год UTC |
| `month` | int (1–12) | нет | текущий месяц UTC |

**Response 200:**
```json
{
  "year": 2026,
  "month": 4,
  "active_dates": [
    "2026-04-15",
    "2026-04-16",
    "2026-04-17",
    "2026-04-19"
  ],
  "current_streak": 3,
  "longest_streak": 18
}
```

| Поле | Тип | Описание |
|---|---|---|
| `active_dates` | string[] ISO date | Дни, когда пользователь был активен (в UTC). Без времени. |
| `current_streak` | int | = `users.days_active` |
| `longest_streak` | int | = `users.longest_streak` |

**Response 401:** токен невалиден.

Клиент уже умеет запрашивать этот эндпоинт и отображать календарь — достаточно чтобы он просто заработал.

### 5.2 `GET /dict/profile-rating` — существующий, аудит

Уже возвращает `days_active`. Проверьте:
- Инкремент делается по правилам §4 (событие активности, а не cron-джоб)
- Граница дня — **UTC**, не локальная TZ сервера
- Значение совпадает с `users.days_active` из §3

### 5.3 Формат дат — важно

- Все даты — в **UTC**, без времени (`YYYY-MM-DD`, ISO 8601 calendar date)
- Клиент **парсит их как UTC** (не локальное время), чтобы `"2026-04-19"` не превращался в 18 число в TZ с отрицательным offset
- Параметр `year` и `month` в запросе — **тоже UTC**. Если пользователь в UTC+12 открывает 1 апреля в 00:30 локального времени, его UTC всё ещё 31 марта → фронт должен запросить `year=2026&month=3` по умолчанию

### 5.4 Поведение по граничным запросам

| Запрос | Ответ |
|---|---|
| `year=2026&month=5` (месяц в будущем) | 200 с `active_dates = []`, `current_streak` и `longest_streak` — актуальные |
| `year=2020&month=1` (задолго до регистрации) | 200 с `active_dates = []` |
| `year=2026&month=13` (невалидный месяц) | 400 `{"error":"invalid_month"}` |
| Не авторизован | 401 |
| Попытка посмотреть чужую активность (не предусмотрено API) | Эндпоинт работает только с текущим `user.id` из JWT |

---

## 6. Где вызывать `mark_activity(user)`

Варианты (выбирайте один или несколько):

1. **Каждый успешный POST `/users/activity`** (из `result_game_page`) — **рекомендуется**
2. Каждый успешный POST `/remember-new-words/*` (в syncProgress)
3. Каждый вход в `/auth/login` — **не рекомендуется**, иначе можно просто открывать app и получать серию без обучения

Duolingo считает серию только если пользователь **прошёл урок или сделал минимум N XP**. Для VozhaOmuz проще всего — считать активным день, в который пользователь завершил хотя бы одну игровую сессию.

---

## 7. Edge-case при миграции

У текущих пользователей `last_active_day_utc` будет NULL после ALTER. Первая же игра после деплоя даст им `days_active = 1`, сбрасывая то, что было в `days_active`.

Решение: одноразовая миграция:

```sql
UPDATE users
SET last_active_day_utc = CURRENT_DATE - INTERVAL '1 day'
WHERE days_active > 0 AND last_active_day_utc IS NULL;
```

Так серия не сломается у активных пользователей в день релиза. Тех, у кого `days_active = 0`, не трогаем — они всё равно начнут с 1 при следующей игре.

---

## 8. Концепция «freeze» (опционально)

Duolingo даёт 1 «заморозку» в неделю — если день пропущен, серия не ломается. Для MVP можно не делать, но если хочется:

```sql
ALTER TABLE users ADD COLUMN streak_freeze_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN streak_freeze_last_refilled DATE;
```

Логика: при проверке gap > 1 — если `streak_freeze_count > 0`, использовать заморозку вместо сброса. Раз в неделю `streak_freeze_count` пополняется до 2.

На MVP — пропустить.

---

## 9. Тест-план

| Сценарий | Ожидание |
|---|---|
| Новый пользователь, первая игра | `days_active=1`, `longest_streak=1`, `last_active_day_utc=today` |
| Та же игра через 5 минут | `days_active=1` (не изменился), `last_active_day_utc` не трогается |
| Игра на следующий день (UTC) | `days_active=2`, `longest_streak=2` |
| Игра через 3 дня (пропуск) | `days_active=1` |
| Игра в 23:59 UTC + игра в 00:01 UTC | `days_active=2` (граница суток сработала) |
| `longest_streak=10`, текущий `days_active=5`, пользователь продолжает серию до 11 | `longest_streak=11` |
| Параллельные запросы от двух устройств на границе дня | Только одно `+1`, lock держит состояние |
| `GET /user/activity?year=2026&month=4` для пользователя с 3 днями активности | `active_dates` содержит ровно эти 3 даты в формате UTC |
| `GET /user/activity` без `year`/`month` | По умолчанию — текущий месяц UTC |
| **Lazy-expiry**: `days_active=10` в БД, `last_active_day_utc = today - 5 days`, `GET /dict/profile-rating` | Response `days_active = 0` (серия уже сломана, см. §4.3) |
| **Lazy-expiry**: после предыдущего сценария игра в today | `days_active = 1` (reset через mark_activity), lazy-expiry больше не применяется |
| `year=2026&month=5` (будущий месяц) | 200, `active_dates = []`, `current_streak` и `longest_streak` — актуальные |
| Прерванная игра (system back до result_page) | `days_active` не изменился, `last_active_day_utc` не обновлён |

---

## 10. Контракт с фронтендом

Клиент уже содержит:
- `StreakHistoryDialog` (`lib/shared/widgets/streak_history_dialog.dart`) — открывается тапом по 🔥 на home
- `profileRatingProvider` — читает `days_active`
- Placeholder-данные: пока эндпоинта `/user/activity` нет, клиент подсвечивает последние `days_active` дней как активные. Когда эндпоинт заработает, достаточно заменить одну функцию (`_buildPlaceholder`) на реальный запрос.

**Ничего дополнительно в client API менять не нужно**, если соблюсти формат ответа из §5.1.

---

## 11. Оценка трудозатрат (backend)

| Задача | Часы |
|---|---|
| Миграция БД (+3 поля в users, опц. user_activity_days) | 1 |
| Логика `mark_activity` + unit-тесты | 3 |
| **Функция `current_streak()` + lazy-expiry в profile-rating и /user/activity** | 2 |
| Вызовы в местах активности (game result, sync-activity) | 1 |
| `GET /user/activity` + фильтр по месяцу + edge cases | 2 |
| Аудит `days_active` в profile-rating | 1 |
| Блокировки, race-condition тесты | 2 |
| Миграция существующих пользователей | 0.5 |
| **Итого** | **~12–14 часов** |

---

## 12. Открытые вопросы

1. Считаем ли активным пользователя, который открыл app, но не прошёл ни одной игры? *(рекомендация: нет)*
2. Нужна ли монетизация «восстановление серии»? *(на MVP — нет)*
3. Хранить ли `user_activity_days` или считать на лету? *(рекомендация: хранить, быстрее для большого числа users)*
4. Нужно ли событие `streak_broken` в аналитику? *(useful для retention метрик)*

Ответьте по каждому — скорректируем ТЗ.
