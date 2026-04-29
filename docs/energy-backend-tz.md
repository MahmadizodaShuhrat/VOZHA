# ТЗ: Система энергии (Energy System) для VozhaOmuz

**Версия:** 1.0
**Дата:** 2026-04-18
**Фронтенд:** Flutter (уже реализован, ждёт эндпоинты)
**Backend:** ваша реализация

---

## 1. Обзор

Система энергии — механизм ограничения бесплатного использования приложения (аналог Duolingo hearts). Пользователь получает фиксированный "бюджет" энергии, который тратится на игровые сессии. Энергия автоматически восстанавливается со временем. Премиум-пользователи освобождены от всех ограничений.

**Цель:** ограничить бесплатное использование, стимулировать покупку Premium.

---

## 2. Бизнес-правила

| Параметр | Значение |
|---|---|
| Стартовый баланс (при регистрации) | **15.0** |
| Максимальный баланс (cap) | **15** |
| Скорость восстановления | **+1 каждые 5 минут** (300 секунд) |
| Время полной регенерации | **1 час 15 минут** (15 × 5 мин) |
| Базовая стоимость 1 игры | **−1.0** (при завершении) |
| Штраф за одну ошибку | **−0.5** (на каждое слово с ошибкой) |
| Минимальный баланс для старта игры | **≥ 1.0** |
| Премиум | **безлимит** (проверки не применяются) |

**Пример расчёта стоимости:**
- Игра без ошибок → `−1.0`
- Игра с 3 ошибочными словами → `−1.0 + (3 × 0.5) = −2.5`

---

## 3. Модель данных

### 3.1 Таблица `users` — добавить 3 поля

```sql
ALTER TABLE users ADD COLUMN energy_balance NUMERIC(4,1) NOT NULL DEFAULT 15.0;
ALTER TABLE users ADD COLUMN energy_max INTEGER NOT NULL DEFAULT 15;
ALTER TABLE users ADD COLUMN energy_last_refill_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
```

| Поле | Тип | Ограничения | Описание |
|---|---|---|---|
| `energy_balance` | NUMERIC(4,1) | ≥ 0, ≤ `energy_max` | Текущий баланс на момент `last_refill_at` |
| `energy_max` | INTEGER | > 0 | Максимум (для будущего: премиум +5, акции и т.д.) |
| `energy_last_refill_at` | TIMESTAMPTZ | UTC | Якорь для расчёта регенерации |

**Критично:** `energy_balance` хранится с точностью **0.5**, используйте `NUMERIC` / `DECIMAL`, а не `FLOAT` (избежать ошибок округления).

### 3.2 Миграция существующих пользователей

```sql
UPDATE users SET
  energy_balance = 15.0,
  energy_max = 15,
  energy_last_refill_at = NOW()
WHERE energy_last_refill_at IS NULL;
```

---

## 4. API Endpoints

**Base URL:** `https://api.vozhaomuz.com/api/v1`
**Авторизация:** `Authorization: Bearer <access_token>` (как везде)
**Формат:** JSON

### 4.1 `GET /user/energy`

Возвращает текущее состояние энергии. **Сервер должен применить регенерацию** перед ответом (см. раздел 5).

**Request:** нет body.

**Response 200:**
```json
{
  "balance": 12.5,
  "max": 15,
  "last_refill_at": "2026-04-18T10:22:00Z",
  "refill_seconds": 300
}
```

| Поле | Тип | Описание |
|---|---|---|
| `balance` | number | Текущий баланс (после регенерации) |
| `max` | integer | Максимум |
| `last_refill_at` | string (ISO 8601 UTC) | Новый якорь после применения regen |
| `refill_seconds` | integer | Сколько секунд на 1 единицу (300) |

**Response 401:** токен невалиден (interceptor клиента сам обработает).

**Для Premium:** всегда возвращать `balance = max`, и реальный `last_refill_at` неважен (можно NOW()).

---

### 4.2 `POST /user/energy/consume`

Клиент сообщает, что игровая сессия завершена. Сервер списывает энергию.

**Request body:**
```json
{
  "mistakes": 2,
  "completed": true
}
```

| Поле | Тип | Обязательное | Описание |
|---|---|---|---|
| `mistakes` | integer (≥ 0) | да | Количество **уникальных слов с ошибками** (не суммарное количество ошибок) |
| `completed` | boolean | да | `true`, если игра доведена до конца; `false` для будущих случаев частичной оплаты |

**Логика сервера:**
1. Применить регенерацию (раздел 5)
2. Если `is_premium` → **не списывать, вернуть текущее состояние** (balance = max)
3. Рассчитать `cost` (раздел 6)
4. `new_balance = max(0, balance - cost)` — **не ниже 0**
5. Сохранить в БД
6. Вернуть то же, что `GET /user/energy`

**Response 200:** идентична `GET /user/energy` (новое состояние).

**Response 400** (опционально — клиент уже делает gate, но для защиты):
```json
{ "error": "insufficient_energy", "balance": 0.5, "required": 1.5 }
```

---

## 5. Алгоритм регенерации

Запускается в каждом запросе перед возвратом данных. **Должен быть идемпотентным** — повторный вызов не должен ломать состояние.

```python
def apply_regen(user) -> None:
    if user.is_premium:
        return  # Premium не регенерирует — у них всегда max

    now = datetime.now(timezone.utc)
    elapsed_seconds = (now - user.energy_last_refill_at).total_seconds()

    if elapsed_seconds <= 0:
        return  # защита от перевода часов назад

    REFILL_SECONDS = 300
    units_earned = int(elapsed_seconds // REFILL_SECONDS)  # ТОЛЬКО целые единицы

    if units_earned <= 0:
        return

    # КРИТИЧНО: anchor ДОЛЖЕН двигаться даже когда balance на cap.
    # Иначе время, проведённое на max, "банкуется" и моментально
    # возвращает всю энергию после первого же /consume.
    # Regen — это часы реального времени, а не резервуар.
    new_balance = min(
        Decimal(user.energy_max),
        user.energy_balance + Decimal(units_earned)
    )
    new_anchor = user.energy_last_refill_at + timedelta(
        seconds=units_earned * REFILL_SECONDS
    )

    user.energy_balance = new_balance
    user.energy_last_refill_at = new_anchor
    db.commit()
```

### ⚠️ Частая ошибка: ранний return при balance == max

**НЕПРАВИЛЬНО:**
```python
if elapsed_seconds <= 0 or user.energy_balance >= user.energy_max:
    return  # ← БАГ: anchor не продвигается пока balance на cap
```

**Последствие:** пользователь сидит на max целый день → потом играет одну игру
(`balance = 15 → 12`) → hot restart через 5 минут → balance внезапно возвращается
к 15. Regen "накопился" за день, пока anchor стоял на месте.

**ПРАВИЛЬНО:** проверять только `elapsed_seconds <= 0`. Пусть
`new_balance = min(max, balance + units)` сама клампит — arithmetic natural-cap,
но anchor продвигается.

**Почему carry-over важен:**
Если пользователь заходит каждые 7 минут, без carry-over он теряет 2 минуты на каждом заходе (получит +1, но `last_refill_at = NOW()`). С carry-over он получит +1, а оставшиеся 2 минуты посчитаются в следующий раз.

---

## 6. Расчёт стоимости

```python
BASE_COST = Decimal("1.0")
MISTAKE_PENALTY = Decimal("0.5")

def compute_cost(mistakes: int, completed: bool) -> Decimal:
    cost = Decimal("0")
    if completed:
        cost += BASE_COST
    cost += Decimal(mistakes) * MISTAKE_PENALTY
    return cost
```

---

## 7. Регистрация нового пользователя

При создании User в `/auth/register-oauth2`, `/auth/sms/confirm-code`, Google/Apple OAuth — **поля уже заданы через DEFAULT**, но явно убедитесь:

```python
new_user = User(
    ...,
    energy_balance=Decimal("15.0"),
    energy_max=15,
    energy_last_refill_at=datetime.now(timezone.utc),
)
```

---

## 8. Премиум (обход)

Premium определяется по `user.user_type == 'pre'` или `user.tariff_name IS NOT NULL` (как сейчас).

**Во всех эндпоинтах Energy:**

```python
if user.is_premium():
    return {
        "balance": user.energy_max,
        "max": user.energy_max,
        "last_refill_at": now_utc_iso(),
        "refill_seconds": 300,
    }
# Для /consume: просто return без списания
```

Premium-пользователи не должны даже попадать в эту БД-колонку (она сохраняется, но игнорируется).

---

## 9. Edge Cases

| Сценарий | Поведение |
|---|---|
| Пользователь в оффлайне 3 часа → заходит | `apply_regen` посчитает 36 единиц, баланс поднимется до `min(15, old + 36)` = 15 (cap) |
| Пользователь поменял системное время назад | `elapsed_seconds < 0` → `return` без изменений. Отрицательное время нельзя. |
| Запрос `/consume` с `mistakes = 30` | `cost = 1 + 15 = 16.0`, `balance` упадёт до `0` (не ниже). |
| Пользователь стал Premium в середине сессии | Клиент вызовет `setPremium(true)`; следующий `/consume` ничего не спишет |
| Параллельные запросы `/consume` (2 сессии одновременно) | Используйте **row-level lock** (`SELECT ... FOR UPDATE`) для безопасного вычитания |

---

## 10. Транзакции и конкурентность

Обязательно оборачивать `apply_regen + consume` в транзакцию с блокировкой:

```sql
BEGIN;
SELECT * FROM users WHERE id = :user_id FOR UPDATE;
-- apply regen + deduct
UPDATE users SET energy_balance = :new_balance, energy_last_refill_at = :new_anchor WHERE id = :user_id;
COMMIT;
```

Без lock два одновременных завершения игр могут оба прочитать balance=5, оба списать 1, и оба записать 4 — потеряется одно списание.

---

## 11. Логирование

Для отладки и анализа добавить таблицу `energy_transactions` (опционально, но рекомендуется):

```sql
CREATE TABLE energy_transactions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  delta NUMERIC(4,1) NOT NULL,  -- +1.0 (regen) или -1.5 (game)
  reason TEXT NOT NULL,         -- 'regen', 'game_completed', 'game_abandoned'
  metadata JSONB,               -- {"mistakes": 3, "completed": true}
  balance_after NUMERIC(4,1) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_energy_tx_user_time ON energy_transactions(user_id, created_at DESC);
```

Это даст возможность в будущем показать пользователю "историю энергии" и помочь в отладке жалоб.

---

## 12. План тестирования (backend)

| Тест | Ожидание |
|---|---|
| GET /user/energy сразу после регистрации | `balance = 15, max = 15` |
| GET через 10 минут без действий | `balance = 15` (cap), `last_refill_at` не двигается |
| POST /consume с `{mistakes: 0, completed: true}` | `balance` = 14.0 |
| POST /consume с `{mistakes: 2, completed: true}` | `balance` = 12.0 (14 − 1 − 1) |
| GET через 5 мин 30 сек после balance=12 | `balance = 13`, `last_refill_at` сдвинут на +300 сек |
| POST /consume при `balance=0` | `balance = 0` (не отрицательный), либо 400 |
| Premium user, POST /consume | `balance = max`, ничего не списалось |
| 2 одновременных POST /consume | Оба списания учтены, lock работает |

---

## 13. Контракт с фронтендом

**Ничего менять в клиенте не нужно** — все URL и JSON-форматы уже заложены:
- `lib/core/constants/app_constants.dart` — `energyGet`, `energyConsume`
- `lib/core/services/energy_service.dart` — парсер JSON

Как только backend задеплоит `/user/energy` и `/user/energy/consume` — клиент автоматически начнёт синхронизироваться. До этого клиент работает на локальном кэше (fallback).

---

## 14. Оценка трудозатрат (для backend)

| Задача | Часы |
|---|---|
| Миграция БД + поля в User | 1 |
| `apply_regen` + unit-тесты | 2 |
| `GET /user/energy` | 1 |
| `POST /user/energy/consume` + блокировка | 2 |
| Premium обход | 0.5 |
| Установка дефолта на регистрацию | 0.5 |
| Логирование транзакций (опционально) | 2 |
| Интеграционные тесты | 2 |
| **Итого** | **~8–11 часов** |

---

## 15. Контакты

Все вопросы по фронтенду — к команде Flutter. Спецификация составлена на основе уже написанной клиентской логики; любые отклонения от этого ТЗ потребуют изменений в мобильном приложении.
