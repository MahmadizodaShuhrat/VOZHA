# ТЗ для бэкенд-разработчика: Полное управление баннерами с сервера

**Цель:** Все баннеры на главном экране (включая баннер «Рейтинг») управляются с
бэкенда. Админ через панель/БД решает, какие баннеры показывать, в каком
порядке, на каких платформах/версиях, для каких локалей.

**Текущая мобилка:** уже умеет принимать баннеры с
`GET /api/v1/dict/banners` (см. §1) и фильтровать их по платформе и версии.
Не хватает явного флага активации, баннера-рейтинга и расширенных
типов действий (`link`).

---

## 1. Что уже работает

Эндпоинт: `GET /api/v1/dict/banners`

Текущий ответ — **список** объектов:

```json
[
  {
    "id": 7,
    "title": "Купи премиум со скидкой",
    "file_name": "https://cdn.vozhaomuz.com/banners/premium_summer.png",
    "link": "app://Premium",
    "position": 1,
    "app_version": 1.0,
    "platform": "android",
    "localization": {
      "ru": { "title": "Купи премиум со скидкой" },
      "tg": { "title": "Премиумро бо тахфиф харед" },
      "en": { "title": "Buy premium with discount" }
    }
  }
]
```

Заголовки запроса: `App-Version`, `App-Platform`.

Клиент:

- Фильтрует по `platform == App-Platform`.
- Фильтрует по `app_version >= App-Version`.
- Группирует по `position` — первый победивший на позиции выигрывает.
- Сортирует по `position`.

---

## 2. Что нужно добавить

### 2.1. Поле `is_active` (булево, новое)

Сейчас баннер показывается, если запись существует в БД. Это неудобно —
нельзя «выключить на 2 часа», только удалить и перезалить.

Добавить в таблицу `banners` колонку:

```sql
ALTER TABLE banners ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
```

В ответе API:

```json
{
  ...
  "is_active": true
}
```

Бэкенд **должен** возвращать только `is_active = TRUE`. Клиент дополнительно
фильтрует на всякий случай, но основная отсечка — на сервере, чтобы не
гонять зря трафик.

### 2.2. Баннер «Рейтинг»

Сейчас он захардкожен на клиенте — нельзя выключить и нельзя поменять
позицию. Цель: админ может выключить кнопкой.

#### Вариант A (рекомендуется): специальный тип

Добавить колонку `type`:

```sql
ALTER TABLE banners ADD COLUMN type VARCHAR(32) NOT NULL DEFAULT 'image';
```

Допустимые значения:

| `type` | Что рендерит клиент |
|--------|---------------------|
| `image` | Текущий баннер: `file_name` + click → `link` |
| `rating` | Спец-баннер с топ-3 игроками за день (как сейчас в коде) |

Когда `type = "rating"`:

- `file_name`, `localization` могут быть пустыми.
- Клиент сам подтягивает топ-3 через `GET /api/v1/dict/top-3-users-day`.
- Click → переходит в `AllTop30Vozhaomuz` (как сейчас).
- Поле `link` тогда служит фолбэком: если на клиенте старая версия и
  «rating» неизвестна, клиент откроет `link` (например, `app://Rating`).

Пример строки:

```json
{
  "id": 1,
  "type": "rating",
  "title": "Рейтинг",
  "file_name": "",
  "link": "app://Rating",
  "position": 0,
  "is_active": true,
  "app_version": 1.0,
  "platform": "android",
  "localization": {
    "ru": { "title": "Рейтинг" },
    "tg": { "title": "Рейтинг" },
    "en": { "title": "Rating" }
  }
}
```

#### Вариант B: оставить захардкоженным, но дать `is_rating_enabled`

Если не хочется лезть в архитектуру — добавить эндпоинт-настройку
`/api/v1/dict/banner-config`:

```json
{
  "rating_banner_enabled": true,
  "rating_banner_position": 0
}
```

Клиент перед рендером проверяет флаг. Реализуется быстрее, но
гибкость ниже (нельзя поменять текст, иконку, действие — только
включить/выключить и переместить).

**Я рекомендую Вариант A.** Он чище и масштабируется на будущие спец-типы
(`achievements`, `streak`, `daily_quest`, …).

### 2.3. Поля кампании — `valid_from`, `valid_to`

Чтобы админ заранее заводил баннеры (например «Скидка 50 % с понедельника
по пятницу») и не вспоминал их выключать вручную.

```sql
ALTER TABLE banners ADD COLUMN valid_from TIMESTAMP NULL;
ALTER TABLE banners ADD COLUMN valid_to   TIMESTAMP NULL;
```

В API:

```json
{
  ...
  "valid_from": "2026-05-15T00:00:00Z",
  "valid_to":   "2026-05-22T23:59:59Z"
}
```

Бэкенд возвращает баннер, только если `now() BETWEEN valid_from AND valid_to`
(или поле = NULL).

### 2.4. Поле `min_user_level`, `target_user_type` — таргетирование

Тоже опциональные. Например, баннер «Купи премиум» нет смысла показывать
тем, у кого премиум уже активен.

```sql
ALTER TABLE banners ADD COLUMN target_user_type VARCHAR(16) NULL;
   -- 'free' | 'pre' | NULL (всем)
ALTER TABLE banners ADD COLUMN min_user_level   INT NULL;
   -- 1, 2, 3, или NULL
```

В API:

```json
{
  ...
  "target_user_type": "free",
  "min_user_level": null
}
```

Бэкенд знает текущего пользователя по JWT, фильтрует на сервере.

### 2.5. Расширить набор `link` (`app://...`)

Сейчас клиент знает 4 in-app страницы:

- `app://Premium`
- `app://UIBuyCoins` / `app://UICoinPage`
- `app://UIInviteFriend`
- `app://UIBattlePage`

**Добавим (мобилка реализует):**

| `link` | Куда ведёт |
|--------|-----------|
| `app://Rating` | Открывает экран рейтинга (`AllTop30Vozhaomuz`) |
| `app://Courses` | Переключает таб «Курс» |
| `app://CourseDetail/<id>` | Открывает детали курса по id |
| `app://Streak` | Открывает диалог «Фаъолияти шумо» (streak) |
| `app://Achievements` | Открывает экран достижений |
| `app://Profile` | Открывает профиль |
| `app://MyWords` | Переключает таб «Калимаҳои ман» |
| `app://Shop` | Открывает магазин/коинов |
| `app://Settings` | Открывает настройки профиля |
| `app://Promo/<code>` | Открывает экран промокода с пред-заполненным `<code>` |

Бэкенду делать ничего не нужно — это формат, который мобилка договаривается
понимать. Просто админ в панели сможет выбрать из выпадающего списка.

### 2.6. Поле `priority` (опционально, на будущее)

Иногда два баннера попадают в одну `position`. Сейчас побеждает первый
выпавший в JSON, что недетерминированно (Go map order). Лучше иметь
`priority: int` и сортировать по `(position ASC, priority DESC)`.

```sql
ALTER TABLE banners ADD COLUMN priority INT NOT NULL DEFAULT 0;
```

---

## 3. Новые/изменённые поля — итоговая схема

```json
{
  "id": 7,
  "type": "image",
  "title": "Купи премиум",
  "file_name": "https://cdn.vozhaomuz.com/banners/premium.png",
  "link": "app://Premium",
  "position": 1,
  "priority": 0,
  "is_active": true,
  "app_version": 1.0,
  "platform": "android",
  "valid_from": null,
  "valid_to": null,
  "target_user_type": "free",
  "min_user_level": null,
  "localization": {
    "ru": { "title": "Купи премиум" },
    "tg": { "title": "Премиум харед" },
    "en": { "title": "Buy premium" }
  }
}
```

**Обязательные новые поля:** `type`, `is_active`.
**Опциональные новые поля:** `valid_from`, `valid_to`, `target_user_type`,
`min_user_level`, `priority`.

Старые поля (`id`, `title`, `file_name`, `link`, `position`, `app_version`,
`platform`, `localization`) — остаются без изменений.

---

## 4. Логика бэкенда при ответе

```pseudo
banners = SELECT * FROM banners WHERE is_active = TRUE
filter banners by:
   platform == request.App-Platform
   app_version <= request.App-Version
   (valid_from IS NULL OR valid_from <= NOW())
   (valid_to   IS NULL OR valid_to   >= NOW())
   (target_user_type IS NULL OR target_user_type == user.user_type)
   (min_user_level   IS NULL OR min_user_level   <= user.level)

ORDER BY position ASC, priority DESC
```

Так клиент получает уже отфильтрованный, отсортированный список и
просто рисует сверху вниз.

---

## 5. Эндпоинт без изменений

Тот же путь, тот же метод, та же авторизация:

```
GET /api/v1/dict/banners
Authorization: Bearer <jwt>
App-Version: 1.0
App-Platform: android | ios
```

Ответ — массив с новыми полями (см. §3).

---

## 6. Админ-панель (рекомендации)

Доступ: только админам (по флагу `is_admin` в JWT).

Действия:

1. **Список всех баннеров** — таблица с колонками:
   `id | title | type | platform | position | is_active | valid_from–valid_to | actions`
2. **Создать/редактировать** — форма с полями из §3 + загрузка картинки в
   CDN.
3. **Toggle is_active** — кнопка прямо в таблице, без захода в форму.
4. **Drag-and-drop position** — мышкой переставлять.
5. **Превью** — в форме показывать как баннер будет выглядеть на устройстве
   (мобильный мокап).

Отдельные эндпоинты админки:

- `POST /api/v1/admin/banners` — создать
- `PATCH /api/v1/admin/banners/{id}` — изменить (включая `is_active`)
- `DELETE /api/v1/admin/banners/{id}` — удалить (или soft-delete)
- `GET /api/v1/admin/banners` — все баннеры, включая `is_active = false` и
  истёкшие, с пагинацией.

---

## 7. Edge cases

| Кейс | Поведение бэкенда | Поведение мобилки |
|------|-------------------|-------------------|
| `is_active = false` | Не возвращать | — |
| `valid_to < now()` | Не возвращать | — |
| Баннер `type = "rating"`, но эндпоинт топ-3 пуст | Возвращать как есть | Клиент скрывает |
| Несколько баннеров на одной `position` | Сортировка по `priority DESC`, дальше по `id` | Уже корректно |
| Старая мобилка получает `type = "rating"`, но её код не знает | — | Клиент рендерит как `image` (фолбэк), `link` ведёт на `app://Rating` |
| Локаль клиента отсутствует в `localization` | Возвращать `title` без перевода | Клиент использует `title` |
| `target_user_type = "free"` для премиум-юзера | Не возвращать | — |
| Часовой пояс — не UTC | `valid_from`/`valid_to` всегда UTC | Клиент не пересчитывает |

---

## 8. Миграция данных (для дев-сервера)

```sql
-- 1. Колонки
ALTER TABLE banners ADD COLUMN type VARCHAR(32) NOT NULL DEFAULT 'image';
ALTER TABLE banners ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE banners ADD COLUMN priority INT NOT NULL DEFAULT 0;
ALTER TABLE banners ADD COLUMN valid_from TIMESTAMP NULL;
ALTER TABLE banners ADD COLUMN valid_to TIMESTAMP NULL;
ALTER TABLE banners ADD COLUMN target_user_type VARCHAR(16) NULL;
ALTER TABLE banners ADD COLUMN min_user_level INT NULL;

-- 2. Спец-баннер «Рейтинг»
INSERT INTO banners (
   type, title, file_name, link, position, is_active,
   app_version, platform, localization
) VALUES (
   'rating', 'Рейтинг', '', 'app://Rating', 0, TRUE,
   1.0, 'android', '{"ru":{"title":"Рейтинг"},"tg":{"title":"Рейтинг"},"en":{"title":"Rating"}}'
), (
   'rating', 'Rating', '', 'app://Rating', 0, TRUE,
   1.0, 'ios', '{"ru":{"title":"Рейтинг"},"tg":{"title":"Рейтинг"},"en":{"title":"Rating"}}'
);
```

---

## 9. Тестирование (чек-лист QA)

- [ ] Баннер с `is_active = false` **не** приходит мобилке.
- [ ] Баннер с `valid_to` в прошлом **не** приходит.
- [ ] Баннер с `valid_from` в будущем **не** приходит.
- [ ] `target_user_type = "free"` отдаётся только free-юзерам.
- [ ] `target_user_type = "pre"` отдаётся только премиум-юзерам.
- [ ] Баннер `type = "rating"` приходит корректно с пустым `file_name`.
- [ ] Несколько баннеров на одинаковой `position` — отдаются по `priority DESC`.
- [ ] Заголовок `App-Version: 0.5` отсекает баннер с `app_version: 1.0`.
- [ ] Заголовок `App-Platform: ios` фильтрует только iOS-баннеры.
- [ ] Удаление баннера через админку → следующий запрос мобилки уже не
  возвращает его.
- [ ] Создание баннера через админку → следующий запрос мобилки его
  возвращает (без перезапуска бэкенда).
- [ ] Locale `tg` корректно подставляется из `localization`.
- [ ] Если у клиента локаль `de` (нет в `localization`), приходит `title` без перевода.

---

## 10. Что мобилка реализует со своей стороны

После того как бэкенд это задеплоит:

1. ✅ В `BannerDto` добавить поле `type` (`image` | `rating`).
2. ✅ В `BannerDto` добавить поле `is_active` (фильтр на клиенте — на всякий случай).
3. ✅ В `BannerDto` добавить опциональные `valid_from`, `valid_to`,
   `target_user_type`, `min_user_level`, `priority` (используются только
   как fallback-фильтр).
4. ✅ В `BannerCarousel` рендер `type = "rating"` показывает текущий
   spec-виджет (топ-3 игроки + трофей), `type = "image"` остаётся как сейчас.
5. ✅ В `_handleBannerTap` добавить новые `app://...` маршруты (см. §2.5).
6. ✅ Удалить hardcoded rating slide из `home_banner_section.dart` после
   проверки, что бэкенд отдаёт rating-баннер.

Это ~1 час работы со стороны мобилки.

---

## 11. Сроки и приоритеты

| Шаг | Сложность | Зачем |
|-----|----------|-------|
| `is_active` + `type = "rating"` | 🟢 малая | Минимально позволяет админу выключить/включить любой баннер |
| `valid_from` / `valid_to` | 🟡 средняя | Позволяет планировать кампании заранее |
| `target_user_type` / `min_user_level` | 🟡 средняя | Таргетирование = выше CTR |
| Админка с UI | 🔴 большая | Удобство менеджмента |

Минимальный набор для релиза — `is_active` + `type` (рейтинг). Остальное
дёшево добавляется поверх в следующих итерациях.

---

## Контакты

Любые вопросы по полям, edge cases, или миграции данных — пишите в
рабочий чат, всё проясним до того, как начнёте дёргать таблицу.
