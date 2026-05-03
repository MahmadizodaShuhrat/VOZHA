# ТЗ: Push-уведомления для премиум-пользователей

**Версия:** 2 (расширенная)
**Дата:** 2026-05-03
**Платформа:** Firebase Cloud Messaging (FCM) — токены уже собираются мобилкой и хранятся на бэке.

---

## 0. Зачем это нужно

Две конкретные задачи от продукта:

1. **Не дать платным юзерам молча уйти.** За несколько дней до окончания премиума прилетает напоминание со скидкой / промокодом. Решение должно ловить юзеров, у которых приложение закрыто — поэтому это не локальный пуш, а серверный.

2. **Подтверждать выданный +1 день премиума за streak.** Сейчас у нас механика: каждые 10 активных дней подряд → бэк выдаёт `premium_bonus.granted: true` (см. `streak-backend-tz.md`). Внутри приложения юзер видит модалку. Если бонус выдался когда юзер был оффлайн — он узнаёт об этом только при следующем заходе. Хотим: отправлять пуш **сразу в момент выдачи**, чтобы юзер видел подарок мгновенно, как пуш в Telegram.

И отдельно — задел на будущее (раздел C): произвольные маркетинговые кампании, чтобы админ мог через панель запустить «всем free-юзерам со скидкой 50%». Это можно отложить, главное — A и B.

---

## 1. Три сценария

| # | Название | Триггер | Получатели |
|---|----------|---------|-----------|
| **A** | Premium-expiry reminder | Cron, каждый день в 09:00 (Asia/Dushanbe) | Юзеры, у которых `tariff_expired_at - now()` ∈ {7, 3, 1 день} |
| **B** | Streak-bonus granted | Inline, прямо после выдачи бонуса в `/sync-activity` | Один конкретный юзер, который только что получил +1 день премиума |
| **C** | Произвольная кампания | Админ запускает руками или по расписанию | Сегмент юзеров (free / pre / level≥X / not_seen_for≥N) |

A и B — обязательные. C — опционально, на следующую итерацию.

---

## 2. Сценарий A — напоминания об окончании премиума

### 2.1. Идея

Каждый день рано утром по Душанбе бэк проходит по всем платным юзерам, считает сколько дней до конца их премиума и отправляет напоминание тем, у кого «осталось N дней» совпадает с настроенным расписанием.

Дни задаёт админ через панель — массив `days_before`. По умолчанию `[7, 3, 1]`, но админ может добавить/убрать (например, `[14, 7, 3, 1]` или `[3, 1]` если хочет реже).

### 2.2. Алгоритм cron'а

Запускается раз в сутки в `send_at_local_hour` (по умолчанию 9) по таймзоне `timezone` (по умолчанию `Asia/Dushanbe`).

```pseudo
settings = read('premium_expiry_reminders')
if not settings.enabled: return

today = current date in settings.timezone
days_before = settings.days_before  # e.g. [7, 3, 1]

for user in users:
    if user.user_type != 'pre': continue
    if user.tariff_expired_at is null: continue

    days_left = (user.tariff_expired_at.date - today).days
    if days_left not in days_before: continue

    # Дедупликация: если уже посылали для этой пары (user, days_left, expiry_at) — пропускаем
    inserted = INSERT INTO push_premium_expiry_log
               (user_id, days_left, expiry_at)
               VALUES (user.id, days_left, user.tariff_expired_at)
               ON CONFLICT DO NOTHING
               RETURNING *
    if not inserted: continue

    template = load_template('premium_expiry_' + days_left)
    locale = user.interface_language or 'tg'
    payload = template[locale] or template['tg']

    send_fcm(
        tokens = user.fcm_tokens,
        title = payload.title,
        body = payload.body.replace('{{days}}', str(days_left)),
        data = {
            type: 'premium_expiry_reminder',
            days_left: str(days_left),
            deep_link: 'app://Premium',
            promo_code: payload.promo_code or null,
            discount_pct: payload.discount_pct or null,
        }
    )
```

### 2.3. Дедупликация — обязательна

Без неё юзер получит N пушей в день, как только cron перезапустится (debug, redeploy и т.п.). Используем композитный ключ:

```sql
CREATE TABLE push_premium_expiry_log (
    user_id     BIGINT     NOT NULL,
    days_left   INT        NOT NULL,
    expiry_at   TIMESTAMP  NOT NULL,    -- snapshot tariff_expired_at; меняется при продлении
    sent_at     TIMESTAMP  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, days_left, expiry_at)
);
```

**Важное свойство:** `expiry_at` входит в ключ. Если юзер продлил подписку → `tariff_expired_at` поменялся → перед новой датой можно снова прислать reminder, потому что это уже другая строка в логе.

### 2.4. Шаблоны сообщений

Хранятся в таблице `push_templates` (см. §5). Админ редактирует через панель. Минимальный набор для запуска:

| `template_key` | Условие отправки |
|----------------|------------------|
| `premium_expiry_7` | `days_left == 7` |
| `premium_expiry_3` | `days_left == 3` |
| `premium_expiry_1` | `days_left == 1` |
| `streak_premium_bonus` | при выдаче бонуса (см. §3) |

Пример полной записи в БД:

```json
{
  "template_key": "premium_expiry_7",
  "payload": {
    "ru": {
      "title": "Премиум скоро закончится",
      "body": "До конца премиума {{days}} дней. Продлите со скидкой {{discount}}%!",
      "promo_code": "PREMIUM7",
      "discount_pct": 30
    },
    "tg": {
      "title": "Премиум ба наздикӣ ба охир мерасад",
      "body": "То тамом шудани премиум {{days}} рӯз монд. Бо тахфифи {{discount}}% дароз кунед!",
      "promo_code": "PREMIUM7",
      "discount_pct": 30
    },
    "en": {
      "title": "Premium expires soon",
      "body": "{{days}} days until your premium ends. Renew with {{discount}}% off!",
      "promo_code": "PREMIUM7",
      "discount_pct": 30
    }
  }
}
```

`{{days}}` и `{{discount}}` — простые placeholders, бэк подставляет перед отправкой.

`promo_code` и `discount_pct` — опциональны. Если есть — мобилка откроет экран подписки с предзаполненным кодом и подсветит скидку.

### 2.5. FCM payload (что реально летит в Firebase)

```json
{
  "to": "<fcm_token>",
  "notification": {
    "title": "Премиум скоро закончится",
    "body": "До конца премиума 7 дней. Продлите со скидкой 30%!"
  },
  "data": {
    "type": "premium_expiry_reminder",
    "days_left": "7",
    "deep_link": "app://Premium",
    "promo_code": "PREMIUM7",
    "discount_pct": "30"
  },
  "android": { "priority": "high" },
  "apns": { "headers": { "apns-priority": "10" } }
}
```

`type` — **обязательное** поле. Мобилка по нему роутит. `deep_link`, `promo_code`, `discount_pct` — опциональны; если пустые — мобилка просто открывает страницу подписки.

Все значения в `data` — **строки** (требование FCM).

---

## 3. Сценарий B — push при выдаче streak-бонуса

Это **второй ключевой пункт ТЗ.** Ниже — детально, потому что важно правильно встроить в существующий поток `/sync-activity`.

### 3.1. Текущее состояние

Сейчас в `/api/v1/user/sync-activity` (см. `streak-backend-tz.md`) бэк уже:

1. Учитывает активность дня.
2. Если `days_active % premium_bonus_threshold == 0` (по умолчанию каждые 10 дней) — выдаёт +1 день премиума:
   - `tariff_expired_at = max(tariff_expired_at, now()) + interval '1 day'`
   - `user_type = 'pre'`
3. Возвращает в JSON блок:
   ```json
   "premium_bonus": {
     "granted": true,
     "days_added": 1,
     "milestone_streak": 10,
     "new_premium_until": "2026-05-12T03:24:17Z"
   }
   ```

Мобилка видит этот блок и показывает модалку `PremiumBonusDialog` (готовый виджет в `lib/shared/widgets/premium_bonus_dialog.dart`).

### 3.2. Что нужно добавить

В тот же обработчик `/sync-activity`, **после** успешной выдачи бонуса и **в той же транзакции**, ставим задачу на отправку пуша:

```pseudo
def sync_activity(user, ...):
    bonus = maybe_grant_premium_bonus(user)
    if bonus.granted:
        enqueue_push_streak_bonus(
            user_id = user.id,
            milestone_streak = bonus.milestone_streak,
            new_premium_until = bonus.new_premium_until,
        )
    return {..., 'premium_bonus': bonus.to_json()}
```

Реализация `enqueue_push_streak_bonus`:

```pseudo
def enqueue_push_streak_bonus(user_id, milestone_streak, new_premium_until):
    # async очередь (Sidekiq / RQ / Bull / собственная — что используете)
    queue.push('streak_bonus_push', {
        user_id: user_id,
        milestone_streak: milestone_streak,
        new_premium_until: new_premium_until,
    })
```

Воркер очереди:

```pseudo
def worker_streak_bonus_push(payload):
    user = users.find(payload.user_id)
    if not user.fcm_tokens: return  # FCM-токенов нет, пропускаем

    template = load_template('streak_premium_bonus')
    locale = user.interface_language or 'tg'
    msg = template[locale] or template['tg']

    until_local = format_date(payload.new_premium_until, locale)  # "12 мая 2026"

    send_fcm(
        tokens = user.fcm_tokens,
        title = msg.title,
        body = msg.body
                    .replace('{{streak}}', str(payload.milestone_streak))
                    .replace('{{until}}', until_local),
        data = {
            type: 'streak_premium_bonus',
            milestone_streak: str(payload.milestone_streak),
            new_premium_until: payload.new_premium_until.iso8601(),
            deep_link: 'app://Streak',
        }
    )
```

### 3.3. Зачем дополнительная очередь, а не отправлять прямо в `/sync-activity`

Три причины:

1. **Скорость ответа.** `/sync-activity` сейчас отвечает за десятки миллисекунд. FCM HTTP может занять 0.5-2 секунды. Не хочется блокировать ответ на пуш.
2. **Изоляция ошибок.** Если FCM лёг (or 429) — это не должно валить выдачу бонуса. Юзер бонус получил, в JSON `granted: true` пришёл, модалка показалась — это первично. Пуш — это бонус сверху.
3. **Retry.** Очередь даёт автоматические попытки повтора, если FCM временно недоступен.

### 3.4. Дедупликация для streak-бонуса

Не нужна на стороне этого пуша, потому что бэк уже не выдаёт один и тот же бонус дважды (см. `TZ_STREAK_PREMIUM_BONUS.md` — UNIQUE constraint на `(user_id, streak_run_id, milestone_streak)`). Раз бонус выдан → пуш ставится в очередь ровно один раз.

### 3.5. Шаблон `streak_premium_bonus`

```json
{
  "template_key": "streak_premium_bonus",
  "payload": {
    "ru": {
      "title": "🎁 +1 день премиума!",
      "body": "Вы держите серию из {{streak}} дней. Премиум до {{until}}."
    },
    "tg": {
      "title": "🎁 +1 рӯз премиум!",
      "body": "Шумо силсилаи {{streak}}-рӯзаро нигоҳ медоред. Премиум то {{until}}."
    },
    "en": {
      "title": "🎁 +1 day of Premium!",
      "body": "You're on a {{streak}}-day streak. Premium until {{until}}."
    }
  }
}
```

`{{streak}}` — `milestone_streak` (например, 10, 20, 30).
`{{until}}` — отформатированная дата на локали юзера.

### 3.6. FCM payload

```json
{
  "to": "<fcm_token>",
  "notification": {
    "title": "🎁 +1 день премиума!",
    "body": "Вы держите серию из 10 дней. Премиум до 12 мая 2026."
  },
  "data": {
    "type": "streak_premium_bonus",
    "milestone_streak": "10",
    "new_premium_until": "2026-05-12T03:24:17Z",
    "deep_link": "app://Streak"
  },
  "android": { "priority": "high" },
  "apns": { "headers": { "apns-priority": "10" } }
}
```

### 3.7. Сценарии получения

| Где юзер в момент `/sync-activity` | Что увидит |
|------------------------------------|------------|
| Приложение открыто, на главном экране | Модалка `PremiumBonusDialog` (in-app) **+** push в шторке (foreground notification) |
| Приложение свёрнуто | Push в шторке. Тап → откроет дилог streak |
| Приложение убито | Push в шторке. Тап → запустит app + откроет диалог streak |
| Телефон выключен | Push прилетит, когда телефон включат |
| FCM-токена нет | Только модалка при следующем заходе в app |

---

## 4. Сценарий C — произвольные кампании (опционально)

> Этот раздел можно реализовать после A и B. Описан схематически.

Админ через панель создаёт «кампанию»:

```json
{
  "id": 42,
  "name": "Black Friday 2026",
  "segment": {
    "user_type": "free",
    "level_min": 3,
    "registered_after": "2026-01-01",
    "last_seen_within_days": 14
  },
  "schedule": {
    "kind": "one_off",
    "send_at": "2026-11-25T09:00:00+05:00"
  },
  "template_key": "black_friday_50",
  "is_active": true
}
```

Cron раз в час смотрит активные кампании, чьё `send_at <= now()` и `executed_at IS NULL`, делает выборку по сегменту, шлёт пуши, ставит `executed_at = NOW()`.

Сегмент сначала простой (поля юзера + last_seen). Можно расширить позже.

---

## 5. Схема БД

```sql
-- Глобальные настройки (одна строка с key='premium_expiry_reminders')
CREATE TABLE push_settings (
    key         VARCHAR(64) PRIMARY KEY,
    value       JSONB       NOT NULL,
    updated_at  TIMESTAMP   NOT NULL DEFAULT NOW()
);

INSERT INTO push_settings (key, value) VALUES (
    'premium_expiry_reminders',
    '{"enabled": true, "days_before": [7, 3, 1], "send_at_local_hour": 9, "timezone": "Asia/Dushanbe"}'
);

-- Шаблоны сообщений (по template_key)
CREATE TABLE push_templates (
    template_key  VARCHAR(64) PRIMARY KEY,
    payload       JSONB       NOT NULL,    -- {ru: {title, body, promo_code, discount_pct}, tg: {...}, en: {...}}
    description   TEXT        NULL,        -- для админ-панели, что это за пуш
    updated_at    TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- Стартовый набор шаблонов
INSERT INTO push_templates (template_key, payload, description) VALUES
    ('premium_expiry_7', '{...}', 'Напоминание за 7 дней до окончания премиума'),
    ('premium_expiry_3', '{...}', 'Напоминание за 3 дня до окончания премиума'),
    ('premium_expiry_1', '{...}', 'Напоминание за 1 день до окончания премиума'),
    ('streak_premium_bonus', '{...}', 'Подтверждение +1 дня премиума за streak');

-- Лог дедупликации reminder'ов
CREATE TABLE push_premium_expiry_log (
    user_id     BIGINT      NOT NULL,
    days_left   INT         NOT NULL,
    expiry_at   TIMESTAMP   NOT NULL,
    sent_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, days_left, expiry_at)
);

-- Индекс для быстрых debug-запросов "история юзера"
CREATE INDEX idx_expiry_log_user ON push_premium_expiry_log (user_id, sent_at DESC);

-- (опционально, под раздел C) Кампании
CREATE TABLE push_campaigns (
    id            BIGSERIAL    PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    segment       JSONB        NOT NULL,
    schedule      JSONB        NOT NULL,
    template_key  VARCHAR(64)  NOT NULL REFERENCES push_templates(template_key),
    is_active     BOOLEAN      NOT NULL DEFAULT FALSE,
    executed_at   TIMESTAMP    NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);
```

Где брать `fcm_tokens` — там же, где сейчас (поле в `users` или отдельная таблица `user_devices`). Если у юзера несколько устройств — шлём на все активные токены, пушу в `data` это безразлично.

---

## 6. Endpoints для админ-панели

Все требуют `is_admin` JWT (как у `/admin/banners`).

| Метод | URL | Что делает |
|-------|-----|------------|
| `GET` | `/api/v1/admin/push/settings` | Текущие настройки expiry-reminder |
| `PATCH` | `/api/v1/admin/push/settings` | Обновить (toggle `enabled`, изменить `days_before` / часы / TZ) |
| `GET` | `/api/v1/admin/push/templates` | Список всех шаблонов |
| `GET` | `/api/v1/admin/push/templates/:key` | Один шаблон с полным `payload` |
| `PATCH` | `/api/v1/admin/push/templates/:key` | Обновить тексты / промокод / скидку |
| `POST` | `/api/v1/admin/push/test-send` | Прислать самому себе пуш по `template_key` (для проверки текста) |
| `GET` | `/api/v1/admin/push/expiry-log?user_id=X` | История expiry-пушей конкретного юзера (debug) |
| `POST` | `/api/v1/admin/push/dry-run-cron` | Запустить cron в режиме dry-run, вернуть «кому бы пришло сейчас», без реальных отправок |

`test-send` обходит `push_premium_expiry_log` — иначе тестовый пуш заблокировал бы прод-отправку.

---

## 7. Локализация

Все шаблоны хранят `{ru, tg, en}`. Бэк выбирает локаль по полю `users.interface_language` (если есть) или по последнему `App-Language` хедеру юзера (надо хранить, если ещё нет).

Если локаль неизвестна или нет такой записи в шаблоне — fallback `tg` (это default-локаль приложения).

Ключ `tg` (не `tj`!) — синхронизируем с тем, что мобилка использует в баннерах и курсах.

---

## 8. Edge cases

| Ситуация | Что делает бэк |
|----------|----------------|
| Юзер удалил приложение, FCM-токен невалиден | FCM вернёт `NotRegistered` или `InvalidRegistration` — помечаем токен как `inactive=true`, больше на него не шлём. Лог в `expiry_log` оставляем (он не виноват) |
| У юзера нет FCM-токенов | Пропускаем, в логах `skipped: no_token` |
| Юзер продлил подписку **в день** reminder'а | Дубликат не уйдёт — композитный ключ включает `expiry_at`, и он уже сменился, так что для нового `expiry_at` запись свежая. Reminder придёт за N дней до новой даты |
| `tariff_expired_at` истекает в полночь | Cron бежит в 9:00 локального — никаких пограничных гонок. Сначала истечение, потом cron не находит юзера среди `pre`, потому что он уже `free` |
| Юзер отключил пуши в системе | FCM либо отдаст 200 без доставки, либо `MismatchSenderId` — игнорируем, действий не предпринимаем |
| Двое (или больше) устройств у юзера | Шлём на **все активные** FCM-токены. Дедупликация — на уровне юзера, не устройства |
| Streak-бонус и expiry-reminder в один день | Пушаются оба — это разные `type`, мобилка различает. Не конфликтуют |
| Тест-сенд через админку | Идёт мимо `expiry_log`, никаких побочек на прод |
| FCM временно недоступен (5xx) | Очередь повторяет 3 раза с экспоненциальной задержкой. После 3 неудач — лог + `skipped: fcm_error` |
| `premium_bonus.granted` = true, но пуш-воркер упал | Бонус всё равно выдан в БД, юзер увидит модалку при следующем заходе в app. Пуш повторится в очереди |
| Локаль юзера = `de` (или любая другая, не `ru/tg/en`) | Fallback на `tg` |
| Юзер `pre`, но `tariff_expired_at IS NULL` | Скипаем — это вечный премиум или сломанная запись, логируем как warning |
| Несколько streak-бонусов подряд (юзер прошёл milestone 10 → 20 → 30 за один `/sync-activity`) | Это невозможно, milestone проверяется ровно по одному (см. streak-backend-tz). Если всё-таки случится — на каждый `granted: true` ставится своя задача в очередь, шлются N пушей |

---

## 9. Чек-лист реализации

### Бэк — обязательное

- [ ] Таблицы `push_settings`, `push_templates`, `push_premium_expiry_log` созданы и проиндексированы
- [ ] Стартовые шаблоны (4 штуки: `premium_expiry_7/3/1` + `streak_premium_bonus`) залиты на `ru/tg/en`
- [ ] Cron-задача запускается ежедневно в 09:00 Asia/Dushanbe, читает настройки из `push_settings`
- [ ] `/sync-activity` ставит в очередь `streak_bonus_push` сразу при `bonus.granted == true` (в той же транзакции)
- [ ] Очередь имеет retry с backoff на FCM 5xx
- [ ] Невалидные токены (`NotRegistered`) помечаются `inactive=true`
- [ ] FCM payload содержит `type` — это критично для мобилки
- [ ] Дедупликация работает (повторный запуск cron не шлёт второй пуш)

### Бэк — админ-панель

- [ ] 8 endpoint'ов из §6 реализованы и заведены в админ-UI
- [ ] Возможность редактировать тексты шаблонов с превью на 3 локали
- [ ] `test-send` присылает себе пуш с реальным шаблоном
- [ ] `dry-run-cron` показывает таблицу «кому бы ушло» без отправки
- [ ] `expiry-log` показывает последние 30 пушей юзера (для саппорта)

### Мобилка (отдельная задача после бэка)

- [ ] `_handleNotificationTap` различает `data.type`:
  - `premium_expiry_reminder` → `MySubscriptionPage(prefilledPromo: data.promo_code)`
  - `streak_premium_bonus` → открыть streak-страницу или показать `PremiumBonusDialog`
- [ ] `MySubscriptionPage` уже принимает `prefilledPromo` (проверить, при необходимости пробросить)
- [ ] Foreground push показывается через `flutter_local_notifications` с тем же `data` (тап → тот же роутер)
- [ ] Бэйдж на иконке (опционально)

---

## 10. План тестирования (для QA)

### A — premium-expiry reminders

1. Тест-юзер `pre`, `tariff_expired_at` = завтра 23:59 → cron в 09:00 присылает `premium_expiry_1` ✅
2. Тест-юзер `pre`, `tariff_expired_at` = через 3 дня → cron присылает `premium_expiry_3` ✅
3. Тот же юзер на следующий день: cron присылает `premium_expiry_2`? **Нет** — `2` нет в `days_before`. Если завтра уже `days_left=2`, никакой второй пуш не уйдёт
4. Cron перезапустить вручную в течение того же дня → пуш не дублируется (`ON CONFLICT` ловит)
5. Юзер продлил подписку → новый `tariff_expired_at` → за 7 дней до новой даты приходит свежий reminder
6. Юзер отключил пуши на телефоне → ничего не шлём, тихо
7. Юзер удалил приложение → FCM `NotRegistered` → токен помечен inactive → больше не пытаемся

### B — streak bonus push

1. Тест-юзер на milestone-9, делает упражнение → `days_active=10` → `granted=true` → пуш приходит **сразу**, в течение 5 секунд
2. То же, но в момент `sync-activity` юзер свернул приложение → push в шторке, тап открывает streak-диалог
3. То же, но юзер выключил телефон сразу после `sync-activity` → push прилетит, когда включит
4. У юзера два устройства (телефон+планшет) → push приходит на оба
5. Бонус выдан, но FCM временно вернул 503 → очередь делает retry → пуш приходит со 2-й/3-й попытки
6. Воркер очереди упал, не отправив пуш → бонус всё равно учтён в БД, юзер увидит модалку при следующем входе в app. Пуш потерян (acceptable).

### Локализация

1. Юзер с `interface_language='ru'` → текст на русском
2. Юзер с `interface_language='tg'` → текст на таджикском
3. Юзер с `interface_language='en'` → на английском
4. Юзер с `interface_language='de'` → fallback на `tg`
5. Юзер без `interface_language` → fallback на `tg`

### Админ-панель

1. Изменить `days_before` с `[7, 3, 1]` на `[14, 7, 3, 1]` → следующий день cron включает 14
2. Изменить тексты шаблона `premium_expiry_7` → следующая отправка использует новые тексты
3. Сменить `discount_pct` с 30 на 50 → следующая отправка содержит 50 в `data` payload
4. Запустить `test-send` себе → push прилетает, `expiry_log` НЕ обновился
5. `dry-run-cron` показывает список юзеров и какие шаблоны им бы прислали — без реальных пушей

---

## 11. Сроки

| Шаг | Сложность | Ориентировочно |
|-----|-----------|----------------|
| A. Premium-expiry reminders + cron + дедупликация | 🟡 средняя | 1-2 дня |
| B. Streak-bonus push + очередь + retry | 🟢 малая | 0.5-1 день |
| Админ-панель (CRUD шаблонов + test-send + dry-run) | 🟡 средняя | 1-2 дня |
| C. Произвольные кампании + сегменты | 🔴 большая | 3-5 дней |

**Минимум для релиза:** A + B + базовая админ-панель (просто toggle и редактирование текстов). C — отложить.

**Полный объём:** 4-6 рабочих дней бэкенда.

---

## 12. Что НЕ делаем (out of scope)

- A/B тесты текстов
- Аналитика open-rate / CTR пушей (будет — но не в этой итерации)
- iOS критические уведомления (`apns-push-type: alert` хватает)
- Веб-пуши (только мобильные FCM)
- SMS-рассылка (есть отдельный канал, не путать)

---

## 13. Связанные документы

- `streak-backend-tz.md` — как работает streak и `days_active`
- `TZ_BANNERS_FROM_BACKEND.md` — паттерн админ-панели (использовать ту же авторизацию и стиль)
- `lib/feature/rating/data/models/premium_bonus_dto.dart` — формат `premium_bonus` в ответе мобилки

---

## Контакты

Любые вопросы по сегментам, шаблонам, dedup-логике или формату FCM payload — пишите в рабочий чат. Если что-то непонятно по интеграции с `/sync-activity` или формату `premium_bonus` — у меня есть полный контекст по streak-фиче, помогу разобраться.
