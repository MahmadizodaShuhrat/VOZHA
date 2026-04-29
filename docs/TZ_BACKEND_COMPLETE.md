# 📋 Техническое задание для Backend-команды VozhaOmuz

**Версия**: 2026-04-24
**Автор**: Client team
**Статус**: готово к внедрению
**WebSocket endpoint**: `wss://api.vozhaomuz.com/api/v1/ws/computation`
**REST base**: `https://api.vozhaomuz.com/api/v1/`

Документ описывает **все актуальные задачи** для бэкенда в одном месте — от критичных багов, ломающих основной сценарий приглашения друзей в battle, до улучшений UX.

---

## TL;DR — за 30 секунд

1. 🔴 **Grace period баг**: после внедрения grace-логики тест показал: Phone 2 успешно вступает во время admin grace, но через ~5–6 сек (а не 60!) получает `room_not_found`. Phone 1 никогда не видит что Phone 2 заходил. Нужно проверить env-переменную, race conditions, и корректную семантику `delete_room` vs `room_not_found`. Детали — **секция 1**.
2. 🔴 **Deep link файлы**: опубликовать `assetlinks.json`, `apple-app-site-association`, HTML-landing на `api.vozhaomuz.com`. Файлы готовы, лежат в папке `deeplink-landing/`. Детали — **секция 2**.
3. 🔴 **Ranking + призы**: добавить поля `place` + `finish_time` в `MemberDto`, зафиксировать 4-минутный матч, распределение призов 50/30/20. Детали — **секция 3**.
4. 🟠 **Мелочи**: `wait_time_seconds`, structured `daily_limit_reached`, единое streak field. Детали — **секции 4–6**.
5. 🟡🟢 **Улучшения**: `new_balance`, configurable limits, единые формулы. Детали — **секции 7–10**.

Полностью клиент готов к всем изменениям — либо уже ждёт новых полей, либо адаптируется по мере их появления (см. Приложение А).

---

## Оглавление

1. [🔴 КРИТИЧНО: Баг в grace period при разрыве WS админа](#1--критично-баг-в-grace-period-при-разрыве-ws-админа)
2. [🔴 КРИТИЧНО: Deep link — публикация файлов на api.vozhaomuz.com](#2--критично-deep-link--публикация-файлов-на-apivozhaomuzcom)
3. [🔴 КРИТИЧНО: Правильный расчёт результатов и призов в Battle](#3--критично-правильный-расчёт-результатов-и-призов-в-battle)
4. [🟠 ВЫСОКИЙ: `wait_time_seconds` в `room_created`](#4--высокий-wait_time_seconds-в-room_created)
5. [🟠 ВЫСОКИЙ: Structured `daily_limit_reached` ответ](#5--высокий-structured-daily_limit_reached-ответ)
6. [🟠 ВЫСОКИЙ: Единое поле для streak в `/profile-rating`](#6--высокий-единое-поле-для-streak-в-profile-rating)
7. [🟡 СРЕДНИЙ: Атомарное обновление money в syncProgress](#7--средний-атомарное-обновление-money-в-syncprogress)
8. [🟡 СРЕДНИЙ: Конфигурируемый battle daily limit](#8--средний-конфигурируемый-battle-daily-limit)
9. [🟢 НИЗКИЙ: `count_learned_words` — единая формула](#9--низкий-count_learned_words--единая-формула)
10. [🟢 НИЗКИЙ: Version description — локализованные поля](#10--низкий-version-description--локализованные-поля)
11. [🔧 Инфраструктура: тестовое окружение и API документация](#11--инфраструктура-тестовое-окружение-и-api-документация)
12. [Приложение А: Клиент-готовность](#приложение-а-клиент-готовность)
13. [Приложение Б: Рекомендованный порядок внедрения](#приложение-б-рекомендованный-порядок-внедрения)

---

## 1. 🔴 КРИТИЧНО: Баг в grace period при разрыве WS админа

### Контекст

Backend недавно внедрил grace period логику для WS админа: при разрыве сокета админа комната не удаляется мгновенно — ждёт 60 секунд (waiting phase) или 120 секунд (in-game) на реконнект. Подтверждено сообщением от бэкенд-разработчика о внедрении:
- `TypeRoomRestored = "room_restored"`
- `RoomAdminGraceWaiting = 60s` / `RoomAdminGraceInGame = 120s`
- `finalizeAdminLeft` и `tryRestoreAdminSession` функции
- `RoomManager.AdminDisconnectedAt` + `AdminCleanupTimer`

Клиент обновлён соответствующе:
- Обрабатывает событие `room_restored` — ресинхронизирует state
- На WS-реконнекте автоматически шлёт `check_room` с JWT, чтобы `tryRestoreAdminSession` сработал при первом аутентифицированном фрейме

### Баг-репорт (воспроизведён на реальных устройствах 2026-04-24)

#### Условия теста
- Два разных физических Android-устройства, Phone 1 и Phone 2
- **Две разные учётки** VozhaOmuz (разные `user_id`)
- Обе в одной и той же версии клиента (production release APK)

#### Шаги воспроизведения

| № | Устройство | Действие |
|---|------------|----------|
| 1 | Phone 1 (создатель) | Создаёт комнату → код `840650` → waiting room. WS-сокет установлен, админ = user_id Phone 1 |
| 2 | Phone 1 | Жмёт Share → открывается Telegram, VozhaOmuz уходит в фон. Сокет Phone 1 разрывается (MIUI / Android background network limits). **Phone 1 остаётся в Telegram**, отправляет ссылку и НЕ возвращается в VozhaOmuz в течение теста. |
| 3 | Phone 1 | Отправляет ссылку `vozhaomuz://battle?room_id=840650` второму телефону |
| 4 | Phone 2 | Получает сообщение в Telegram, тапает на ссылку |
| 5 | Phone 2 | Приложение открывается (cold или warm start), Battle > Join Room, код автозаполнен |
| 6 | Phone 2 | Автоматически срабатывает `check_room` → сервер отвечает `check_room` (успех) → UI показывает карточку комнаты с именем создателя + кнопка "Присоединиться" |
| 7 | Phone 2 | Жмёт "Присоединиться" → клиент шлёт `join_to_room` |
| 8 | Phone 2 | Получает `join_new_member` — UI показывает waiting room с ДВУМЯ участниками (создатель + сам Phone 2). ✅ Join успешно обработан на сервере |
| 9 | Phone 1 | **НЕ получает** `join_new_member`. Даже когда пользователь Phone 1 всё-таки возвращается в приложение (через Telegram → VozhaOmuz), список участников у него не обновляется — остаётся только он сам |
| 10 | Phone 2 | **≈ 5–6 секунд спустя после шага 8** получает `room_not_found` (а не `delete_room`!), UI показывает "Хона ёфт нашуд". Сокет Phone 2 разрывается. |

#### Критические вопросы для backend

1. **Почему `room_not_found`, а не `delete_room`?**
   Эти события семантически разные. При истечении admin grace клиент ожидает `delete_room`, чтобы показать "Создатель закрыл комнату". `room_not_found` — это код "такой комнаты вообще нет", который выглядит как полное отсутствие комнаты, хотя на самом деле она была и её только что удалили.

2. **Почему 5–6 секунд, а не 60?**
   `RoomAdminGraceWaiting = 60` согласно спеке. Откуда 5–6 секунд? Варианты:
   - env-переменная `ROOM_ADMIN_GRACE_WAITING_SECONDS` не подхвачена на проде
   - Переопределена на меньшее значение
   - Есть другой, более короткий таймаут (ping? session timeout?), срабатывающий раньше

3. **Сохраняются ли новые members, добавленные во время admin grace?**
   Сценарий: Phone 1 ушёл в grace (WS conn == nil). Phone 2 успешно вступил (`join_to_room` обработан, member добавлен в `room.Members`). Phone 1 возвращается в приложение, реконнектится, получает `room_restored`. В `room_restored.data.members` должен быть Phone 2. Это так?

4. **Логирование**
   Добавить серверные логи по событиям:
   - `admin_socket_close`: userID, roomID, timestamp, grace_duration, expected_expiry
   - `try_restore_admin_session`: userID, roomID, timer_canceled, new_socket
   - `finalize_admin_left`: roomID, elapsed_grace, broadcast_targets
   - `join_to_room`: userID, roomID, admin_status (connected / in_grace / gone)
   - `check_room`: userID, roomID, admin_status
   - На любом `room_not_found` → логировать *почему*: not_found_at_lookup / admin_grace_expired_mid_flight / etc.

### Ожидаемое поведение после фикса

- Phone 2 после `join_to_room` остаётся в комнате до истечения admin grace (60 сек с момента Phone 1-го разрыва).
- Если Phone 1 возвращается до истечения grace — получает `room_restored` с полным списком members, включая Phone 2. Комната продолжает работать. На Phone 1 список участников обновляется без разрывов.
- Если grace истекает без возврата Phone 1 — сервер рассылает **`delete_room`** (а не `room_not_found`) всем оставшимся членам. Клиент отрендерит "Создатель закрыл комнату".

### Теоретически правильная семантика событий

| Событие | Когда сервер шлёт |
|---------|-------------------|
| `room_not_found` | Клиент пришёл с `check_room` / `join_to_room` для комнаты, которой **никогда не было** (или её удалили очень давно) |
| `delete_room` | Комната **была активна, а сейчас закрывается** по любой причине (admin ушёл, game закончилась с таймаутом, админ грейс истёк) |

Сейчас эти два события, похоже, смешиваются. Нужно чётко разделить.

### Grace period — полное описание требований (для справки)

Если grace ещё не полностью внедрён / что-то нужно переделать:

**При разрыве WS админа** (псевдокод):
```python
on_admin_socket_close(room):
  if room.game_started:
    # Игра уже идёт — ждём дольше (2 минуты), всё равно участники могут доиграть
    room.admin_disconnected_at = now
    schedule_cleanup(room, delay=120s)
  else:
    # Ещё ожидание в waiting room
    room.admin_disconnected_at = now
    schedule_cleanup(room, delay=60s)

  # НЕ отправляем delete_room другим участникам пока
  # Комната остаётся в списке публичных комнат (если была публичной)
```

**При реконнекте того же user_id**:
```python
on_ws_connect_with_auth(user_id, socket):
  existing_room = find_room_where_admin_is(user_id)
  if existing_room and existing_room.admin_disconnected_at:
    # Админ вернулся — восстанавливаем
    existing_room.admin_disconnected_at = null
    cancel_cleanup_timer(existing_room)
    existing_room.admin_socket = socket
    # Отправить админу текущее состояние комнаты (список участников, phase, etc)
    send(socket, 'room_restored', existing_room.state)
```

**При истечении grace period**:

Поведение зависит от фазы матча.

1. **Waiting room** (игра ещё не началась):
   ```python
   # Забираем комнату, ждущую игроков, которой больше никто не управляет
   broadcast(room.members, 'delete_room')
   remove_from_public_list(room)
   delete_room(room)
   ```

2. **In-game** (игра уже идёт): **НЕ удаляем комнату**, а передаём админа случайному активному игроку, чтобы матч можно было доиграть. Грубо:
   ```python
   on_cleanup_timer_fires_in_game(room):
     if room.admin_disconnected_at is null:
       return  # Админ успел вернуться
     candidates = [
       m for m in room.members
       if m.user_id > 0         # не бот
       and not m.has_left
       and m.conn is not None   # его сокет жив
     ]
     if len(candidates) == 0:
       # Все люди разбежались — ставим руку на контроль, удаляем
       broadcast(room.members, 'delete_room')
       delete_room(room)
       return
     new_admin = random.choice(candidates)
     room.admin = new_admin
     for m in room.members:
       m.is_admin = (m.user_id == new_admin.user_id)
     broadcast(room.members, 'admin_changed', {
       'new_admin_id': new_admin.user_id,
       'members': room.members,  # с обновлёнными is_admin флагами
     })
   ```

### Событие `admin_changed` (сервер → клиент)

Клиент уже обрабатывает это событие — обновляет `state.isAdmin` и список участников, новому админу открываются кнопки управления (finish_test и пр.). Если событие не придёт, клиент просто останется в игре без админа (finish_test некому будет прислать), так что важно либо передать админа, либо удалить комнату.

```json
{
  "type": "admin_changed",
  "data": {
    "new_admin_id": 42,
    "members": [
      {"id": 42, "name": "Azamat", "is_admin": true, ...},
      {"id": 7,  "name": "Shuhrat", "is_admin": false, ...}
    ]
  }
}
```

Ключевое: обновить `is_admin` на каждом члене, не только прислать новый `new_admin_id` — клиент использует `is_admin` как источник истины при рендеринге.

### Чек-лист проверки

- [ ] Тест: создать комнату → Share → Telegram → вернуться → комната всё ещё активна
- [ ] Тест: создать комнату → force-kill приложения → через 60с комната удалена
- [ ] Тест: создать комнату → разрыв сокета → реконнект через 30с → комната восстановлена, участники остались
- [ ] Тест: создать комнату → разрыв сокета → реконнект через 65с → комната удалена (grace прошёл), всем участникам пришёл `delete_room`
- [ ] Тест: разрыв во время игры (не waiting) → grace 2 минуты → реконнект в течение этого времени восстанавливает сессию
- [ ] **Тест баг-репорта**: Phone 1 создаёт → Share → в фоне → Phone 2 открывает deeplink и жмёт Join → оба видят друг друга → Phone 1 возвращается → комната продолжает работать без ошибок
- [ ] env-переменная `ROOM_ADMIN_GRACE_WAITING_SECONDS` на проде = 60 (или ≥60)
- [ ] `join_to_room` корректно обрабатывается во время admin grace (не возвращает `room_not_found`)
- [ ] При истечении grace шлётся `delete_room`, не `room_not_found`
- [ ] `room_restored.data.members` содержит members, добавленных во время grace

---

## 2. 🔴 КРИТИЧНО: Deep link — публикация файлов на `api.vozhaomuz.com`

### Проблема

Сейчас `https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=X` возвращает JSON. Когда пользователь нажимает на ссылку в Telegram/WhatsApp:
- Android → Telegram открывает внутренний WebView → показывает голый JSON (ужасный UX)
- iOS → Safari → тот же JSON

Приложение **не открывается автоматически**, потому что нет верификационных файлов на домене `api.vozhaomuz.com`.

Мы сделали временный фолбэк на GitHub Pages (`https://mahmadizodashuhrat.github.io/vozhaomuz-landing/`), куда клиент сейчас направляет share-ссылки. Это работает, но брендировано не очень (в мессенджерах видно "github.io" вместо нашего домена). Правильно — переключиться на родной домен, как только бэкенд опубликует нужные файлы.

### Что нужно опубликовать на `api.vozhaomuz.com`

| URL | Содержимое | Content-Type | Примечание |
|-----|-----------|--------------|-----------|
| `/.well-known/assetlinks.json` | Android App Links verification | `application/json` | Нужен ровно этот путь |
| `/.well-known/apple-app-site-association` | iOS Universal Links | `application/json` | **БЕЗ расширения `.json`** в URL! |
| `/api/v1/deeplink?page=X&room_id=Y` | HTML landing-страница (не JSON) | `text/html` | Заменить текущий endpoint |

**Общие требования ко всем трём файлам**:
- HTTPS с настоящим сертификатом (не self-signed)
- Без редиректов (3xx) — отдаются напрямую с 200 OK
- Без авторизации (публичные файлы)
- Стабильный доступ (кеширование на 1 час нормально)

### 2.1. `assetlinks.json` (Android)

**URL**: `https://api.vozhaomuz.com/.well-known/assetlinks.json`

**Содержимое** (готово — файл [`deeplink-landing/.well-known/assetlinks.json`](../deeplink-landing/.well-known/assetlinks.json)):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.vozhaomuz",
      "sha256_cert_fingerprints": [
        "86:F4:94:9A:4E:E1:49:AB:3F:6E:12:F2:13:CA:1E:65:7E:A5:31:DE:FE:3C:0A:4D:F5:3A:0B:04:F3:45:F8:A2",
        "B4:3E:F4:41:45:AF:91:61:7D:70:BD:76:4F:A1:0A:1E:3E:23:7B:F4:1F:DA:63:D7:93:63:BD:08:90:85:86:94"
      ]
    }
  }
]
```

Первый SHA-256 — production signing key (`android/app/user.keystore`), второй — debug.

**Проверка**:
```bash
curl -i https://api.vozhaomuz.com/.well-known/assetlinks.json
# HTTP/2 200
# content-type: application/json
```

Также через Google verifier:
```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://api.vozhaomuz.com&relation=delegate_permission/common.handle_all_urls
```

### 2.2. `apple-app-site-association` (iOS)

**URL**: `https://api.vozhaomuz.com/.well-known/apple-app-site-association` — **ровно этот путь, БЕЗ `.json`**!

**Содержимое** (готово в [`deeplink-landing/.well-known/apple-app-site-association`](../deeplink-landing/.well-known/apple-app-site-association)):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "B65SR885N5.com.donishsoft.vozhaomuz1",
        "paths": ["/api/v1/deeplink*", "/api/v1/deeplink/*"]
      }
    ]
  }
}
```

**Важно**: значения уже подставлены:
- `B65SR885N5` — Apple Developer Team ID (извлечён из `ios/Runner.xcodeproj/project.pbxproj`)
- `com.donishsoft.vozhaomuz1` — iOS production Bundle Identifier (**отличается** от Android-ского `com.vozhaomuz`, это нормально)

Если в будущем Bundle ID в Xcode меняется — обновить и здесь.

**Проверка**:
```bash
curl -i https://api.vozhaomuz.com/.well-known/apple-app-site-association
# HTTP/2 200
# content-type: application/json
```

### 2.3. Landing HTML на `/api/v1/deeplink`

**URL**: `https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=XXXXX`

**Сейчас**: возвращает JSON. **Нужно**: возвращать HTML-страницу, которая:

1. Красиво отображает код комнаты
2. Пытается открыть приложение через custom scheme `vozhaomuz://battle?room_id=XXX`
3. Если приложение не установлено → редирект в Play Store / App Store
4. Показывает кнопку "Открыть VozhaOmuz" (для Telegram WebView, где автоопен может не сработать)

**Готовый HTML**: файл [`deeplink-landing/index.html`](../deeplink-landing/index.html) — 100% готов, берите как есть. Тестировано, работает на всех основных мессенджерах.

Ключевой JavaScript внутри:

```javascript
const params = new URLSearchParams(window.location.search);
const roomId = params.get('room_id') || '';
const page = params.get('page') || 'battle';
const customLink = `vozhaomuz://${page}?room_id=${encodeURIComponent(roomId)}`;

// Попытка автооткрытия
setTimeout(() => { window.location.href = customLink; }, 400);

// Фолбэк на Store через 2.5s если app не открылся
setTimeout(() => {
  if (document.hidden) return; // app открыл, мы в фоне
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('android')) {
    window.location.href = 'https://play.google.com/store/apps/details?id=com.vozhaomuz';
  } else if (/iphone|ipad|ipod/.test(ua)) {
    window.location.href = 'https://apps.apple.com/app/vozhaomuz';
  }
}, 2500);
```

### После публикации — клиент переключится обратно

Клиент-команда обновит 3 файла за 10 минут:
1. `android/app/src/main/AndroidManifest.xml` — host в intent-filter на `api.vozhaomuz.com`
2. `ios/Runner/Runner.entitlements` — `applinks:api.vozhaomuz.com`
3. `lib/feature/battle/presentation/screens/waiting_opponent_page.dart` — share URL

### Чек-лист

- [ ] `/.well-known/assetlinks.json` опубликован на `api.vozhaomuz.com`
- [ ] `/.well-known/apple-app-site-association` опубликован (БЕЗ `.json` в URL)
- [ ] Оба файла отдаются HTTPS 200 с `Content-Type: application/json`
- [ ] `/api/v1/deeplink?page=X&room_id=Y` возвращает HTML, а не JSON
- [ ] Landing-страница делает JS-редирект на `vozhaomuz://` custom scheme
- [ ] Фолбэк на Play Store / App Store работает, если приложение не установлено
- [ ] Google verifier показывает статус OK для `api.vozhaomuz.com`
- [ ] Тест на реальном устройстве: ссылка в Telegram → приложение открывается напрямую

---

## 3. 🔴 КРИТИЧНО: Правильный расчёт результатов и призов в Battle

### Проблема

Сейчас экран результатов имеет три серьёзных бага:

1. **Место в таблице определяется только по `score`** — нет tie-breaker'ов. Dart `List.sort` нестабильный, поэтому при равенстве score два игрока получают случайные места — на разных устройствах разный порядок.
2. **`won_coins` приходит с бэкенда, но алгоритм непрозрачный** — клиент не знает формулу. Нет гарантии, что при одинаковых score суммарный приз не выплачивается дважды.
3. **Нет поля `finish_time`** — невозможно различить двух игроков с одинаковым score (быстрее ответивший должен быть выше).
4. **Длительность матча зашита где-то непрозрачно** (~90 сек). Продуктовое требование — **ровно 4 минуты** (240 сек).

### Требования

#### 3.1. Длительность матча — 240 секунд

В событии `start_game`:

```
start_time = now (server UTC)
end_time   = start_time + 240 seconds
```

Клиент уже корректно парсит `start_time` / `end_time` из payload (с `.toUtc()`). Никаких изменений на клиенте не требуется — только зафиксировать 240 секунд на сервере.

#### 3.2. Трекинг `finish_time` для каждого игрока

Сервер обязан записывать момент, когда игрок закончил тест:

- **Триггер**: последний (N-й) ответ через `answered`, OR явный `finish_test`, OR истечение `end_time` матча (тогда `finish_time = end_time` для не успевших).
- **Источник времени**: серверные часы UTC. Клиентское время не использовать — нет доверия.
- **Формат**: ISO-8601 UTC, миллисекундная точность: `"2026-04-24T10:03:42.531Z"`.

#### 3.3. Детерминированное ранжирование

Все игроки сортируются по строгой цепочке tie-breaker'ов:

```sql
ORDER BY
  has_left       ASC,   -- 1) ушедшие всегда в конце
  score          DESC,  -- 2) больше очков → выше
  correct_answers DESC, -- 3) при равенстве — больше правильных
  answered       DESC,  -- 4) при равенстве — больше отвеченных вопросов
  finish_time    ASC,   -- 5) при равенстве — кто быстрее закончил
  id             ASC    -- 6) последний fallback для стабильности
```

#### 3.4. Поле `place` в каждом `MemberDto`

Сервер обязан сам вычислять место и присылать в payload событий `results` (и `finish_test`, если используется):

```json
{
  "id": 123,
  "name": "Azamat",
  "score": 180,
  "correct_answers": 18,
  "answered": 20,
  "won_coins": 2400,
  "has_left": false,
  "place": 1,                               // ← НОВОЕ
  "finish_time": "2026-04-24T10:03:42.531Z" // ← НОВОЕ
}
```

**Правила назначения `place`**:
- **Боты** (`id < 0`) → `place = null`. Боты не участвуют в нумерации мест.
- **Ушедшие** (`has_left: true`) → `place = null`. Без места.
- **Реальные активные игроки** (`id > 0, has_left: false`) → `place = 1, 2, 3, …` в порядке из 3.3.

То есть `place` — позиция **среди людей, доигравших матч**. Это то, что клиент использует для подиума, медалей и призов.

#### 3.5. Распределение приза — 50 / 30 / 20

**Призовой фонд**:
```
pool = money_count × count(real_human_members)

где real_human_members = игроки с id > 0 (включая тех, кто has_left)
```

Обоснование: только люди платят entry fee. Боты не платят — в pool не входят. Ушедшие теряют взнос — он остаётся в фонде для призёров.

**Распределение** (при 3+ доигравших людях):

| `place` | Доля | Пример (pool = 1000) |
|---------|------|----------------------|
| 1       | 50%  | 500 монет |
| 2       | 30%  | 300 монет |
| 3       | 20%  | 200 монет |
| 4+ / null | 0  | 0 монет |

**Округление** (чтобы `sum == pool`, без потерянных монет):
```
first  = round_half_up(pool × 0.50)
second = round_half_up(pool × 0.30)
third  = pool − first − second     // остаток целиком 3-му
```

#### 3.6. Edge cases

**Меньше 3 доигравших людей** (`has_left: false, id > 0`):

| Доигравших людей | Распределение |
|------------------|---------------|
| 0 | Pool "сгорает", никто не получает |
| 1 | 1-е место = 100% pool |
| 2 | 1-е = 70%, 2-е = 30% |
| 3+ | 50 / 30 / 20 (стандарт) |

**Боты**: `place = null`, `won_coins = 0`. В pool не входят. Клиент рендерит отдельно без медалей.

**Пример**: 4 участника — бот, А (score=200), Б (score=150), В (score=100):
- бот: place=null, won_coins=0
- А: place=1, won_coins = 50% pool
- Б: place=2, won_coins = 30% pool
- В: place=3, won_coins = 20% pool

**Ушедшие**: `place = null`, `won_coins = 0`. Присутствуют в `results.members` (клиент рендерит бейдж "⨯ вышел").

**Все ушли**: Pool "сгорает". Событие `results` всё равно шлётся.

**Никто не ответил**: fallback по `finish_time` и `id`. Дубликатов мест не бывает.

**1 человек + боты**: Человек = 1-е место = 100% pool. Pool = money_count × 1.

### JSON contract — изменения

**До**:
```json
{
  "type": "results",
  "data": {
    "members": [
      { "id": 1, "name": "A", "score": 180, "correct_answers": 18, "answered": 20, "won_coins": 500 }
    ]
  }
}
```

**После**:
```json
{
  "type": "results",
  "data": {
    "members": [
      {
        "id": 1,
        "name": "A",
        "score": 180,
        "correct_answers": 18,
        "answered": 20,
        "won_coins": 500,
        "has_left": false,
        "place": 1,
        "finish_time": "2026-04-24T10:03:42.531Z"
      }
    ]
  }
}
```

Поля `place` и `finish_time` **обязательны** для каждого члена в payload:
- `place`: `int` или `null` (для ботов и ушедших)
- `finish_time`: ISO-8601 UTC или `null` (если игрок не закончил, например `has_left: true` до истечения таймера)

Эти же поля должны приходить в событии `finish_test`, если оно используется.

### UI-требования (важно: визуально экран не меняется)

Экран результатов (Unity 3D-стиль: подиум + таблица) **сохраняет все анимации**:

1. **ShieldPlaceAnimation** — большой щит-медаль (1 / 2 / 3 / 4+). Рендерится на основе `place`. Если `place == null` — не рендерится (бот / ушедший).
2. **Подиум top-3** — золото / серебро / бронза только для `place ∈ {1, 2, 3}`. Боты и ушедшие на подиум не попадают.
3. **Таблица лидеров** — все участники. У реальных доигравших — номер `place`. У ботов — бейдж "Bot". У ушедших — "⨯ вышел".

**Единственное изменение в UI-логике**: вместо "место = индекс в отсортированном массиве + 1" → "место = `member.place` (от сервера)".

**Новое в UI**: отображение **времени прохождения теста**. В таблице + на подиуме + в personal summary игрока. Формат:
- ≤ 60 сек → `45 с`
- > 60 сек → `1:23` (минуты:секунды)
- Не закончил → `—`
- Ушёл → `⨯ вышел`

Клиент вычисляет время сам, как `finish_time − start_time`.

### Тест-кейсы (проверить после внедрения)

Обозначения: `money_count = 10` везде, если не указано иное.

#### Кейс 1: Обычный матч, 5 реальных игроков, разные score
- Pool = 10 × 5 = 50 монет
- Финальные score: A=250, B=200, C=200, D=150, E=80 (B и C с одинаковым score+correct+answered, B закончил раньше)
- Ожидание: A=1 (25), B=2 (15), C=3 (10), D=4 (0), E=5 (0). Сумма = 50 ✓

#### Кейс 2: Ничья двух игроков, только двое в комнате
- Pool = 10 × 2 = 20
- Оба: score=200, correct=18, answered=20. A закончил 10:03:00, B — 10:03:15
- Ожидание (§3.6 — 2 доигравших): A=1 (14 = 70%), B=2 (6 = 30%). Сумма = 20 ✓

#### Кейс 3: Бот в "топ-3"
- Участники: bot1 (id=-1, score=300), A (id=5, score=200), Б (id=6, score=150), В (id=7, score=100)
- Pool = 10 × 3 = 30 (бот не платит)
- Ожидание:
  - bot1: place=null, won_coins=0
  - A: place=1, won_coins=15 (50%)
  - Б: place=2, won_coins=9 (30%)
  - В: place=3, won_coins=6 (20% = 30−15−9)
  - Сумма: 15+9+6 = 30 ✓

#### Кейс 4: Массовый уход
- 10 человек, 7 ушли, 3 доиграли (A, B, C)
- Pool = 10 × 10 = 100
- Ожидание:
  - A: place=1, won_coins=50
  - B: place=2, won_coins=30
  - C: place=3, won_coins=20
  - 7 ушедших: place=null, won_coins=0, бейдж "⨯ вышел" в UI
  - Сумма: 100 ✓

#### Кейс 5: 200-player матч
- Pool = 10 × 200 = 2000
- Ожидание: place=1 → 1000 (50%), place=2 → 600 (30%), place=3 → 400 (20%), place=4..200 → 0
- Сумма: 2000 ✓

#### Кейс 6: Один человек + комната из ботов
- Участники: human (id=42), bot1, bot2, bot3
- Pool = 10 × 1 = 10 (только человек платит)
- Ожидание: human=1 (10, 100% pool), боты = null, won_coins=0
- Сумма: 10 ✓

#### Кейс 7: Grace period — разрыв и реконнект админа
- Админ создал комнату, WS разорвался (ушёл в share). После реконнекта доиграть матч.
- Проверить: `place`, `finish_time`, `won_coins` посчитаны корректно, админ не потерял результат, для других участников таблица не изменилась.

#### Кейс 8: Округление при нечётном pool
- money_count = 7, 5 игроков → pool = 35
- Ожидание:
  - 1-е: round_half_up(35 × 0.5) = round(17.5) = 18
  - 2-е: round_half_up(35 × 0.3) = round(10.5) = 11
  - 3-е: 35 − 18 − 11 = 6
  - Сумма: 35 ✓ (инвариант `sum == pool`)

### Чек-лист

- [ ] В `start_game`: `end_time − start_time == 240 сек` (4 минуты)
- [ ] Сервер записывает `finish_time` (последний `answered` / `finish_test` / истечение таймера)
- [ ] Сортировка использует полную цепочку tie-breaker'ов
- [ ] Поле `place` приходит в `MemberDto` в payload `results` (и `finish_test`)
- [ ] Поле `finish_time` приходит как ISO-8601 UTC
- [ ] `won_coins` = 50/30/20 от `pool = money_count × count(real_human_members)` (боты в pool не входят)
- [ ] Округление: half-up для 1-го и 2-го, 3-е получает остаток. `sum == pool`
- [ ] Боты: `place = null`, `won_coins = 0`, не в pool
- [ ] Ушедшие: `place = null`, `won_coins = 0`, но присутствуют в `results.members`
- [ ] Edge cases: 3+ → 50/30/20; 2 → 70/30; 1 → 100%; 0 → сгорает
- [ ] Все 8 тест-кейсов выше проходят

---

## 4. 🟠 ВЫСОКИЙ: `wait_time_seconds` + надёжная подсадка ботов

### Проблема 4.1 — `wait_time_seconds`

Клиент раньше показывал 60-секундный countdown "Ожидание игроков" — хардкодом. Мы убрали визуальный таймер, оставили только watchdog 180 секунд как safety net. Сейчас отображается "Ожидание игроков…" без конкретного числа.

### Что нужно

В событии `room_created` прислать серверное значение длительности ожидания:

```json
{
  "type": "room_created",
  "data": {
    "room_id": "534825",
    "wait_time_seconds": 60,    // ← НОВОЕ
    ...
  }
}
```

**Клиент**: вернём визуальный countdown, читающий `wait_time_seconds`. Если поле отсутствует (старый backend) — оставим просто "Ожидание игроков…".

### Проблема 4.2 — Боты иногда не подсаживаются

Пользователи сообщают: в некоторых bot-комнатах (одиночный игрок ждёт подсадки) после истечения `wait_time_seconds` боты **не появляются**, а через какое-то время комната просто умирает. Пользователь сидит на экране "Ожидание игроков" до бесконечности (или пока watchdog 180s не покажет диалог "Соперники не найдены").

Это — серверный баг (точная причина неизвестна без логов). Возможно race condition в bot spawn logic, либо таймер подсадки не срабатывает при определённых условиях.

### Что нужно

- Убедиться, что **после `wait_time_seconds` сервер гарантированно подсаживает ботов** в любую активную bot-комнату
- Добавить логирование: когда bot spawn должен сработать, когда фактически сработал, сколько ботов добавлено
- Тест-кейс: создать комнату, не приглашать никого, дождаться `wait_time_seconds` → боты должны появиться в 100% случаев

**Клиент**: уже имеет watchdog 180s, показывает диалог "Рақибон ёфт нашуданд" с кнопкой "Попробовать снова" если боты не пришли. Это spa safety net, не решение — реальная проблема должна уйти на бэкенде.

---

## 5. 🟠 ВЫСОКИЙ: Structured `daily_limit_reached` ответ

### Проблема

Сейчас при превышении дневного лимита (3 попытки в battle для non-premium) сервер шлёт текстовое поле `message` на русском. Это попадает в UI таджикских / английских пользователей как сырая кириллица — ошибка локализации.

### Что нужно

Структурированное событие:

```json
{
  "type": "daily_limit_reached",
  "data": {
    "limit": 3,                           // сколько попыток разрешено в день
    "resets_at": "2026-04-25T00:00:00Z"   // UTC когда сбрасывается
  }
}
```

**Клиент**: уже перехватывает `type=daily_limit_reached` и подменяет на локализованный текст. Но дополнительные поля `limit` и `resets_at` позволят показать точнее: "Вы использовали 3/3 попытки. Сброс через 4ч 12м".

---

## 6. 🟠 ВЫСОКИЙ: Единое поле для streak в `/profile-rating`

### Проблема

Разные варианты endpoint-а `/profile-rating` возвращают разные имена одного и того же поля: `daysActive`, `days_active`, `active_days`, `streak`. Это — **дневной streak** (последовательные дни активности), а не общее число сыгранных дней.

### Что нужно

Зафиксировать одно имя. Рекомендация: `current_streak` или `days_active`, значение = **последовательные дни активности** (то, что показывается огоньком на home screen).

**Клиент**: сейчас читает из `/user/activity`, потому что там стабильно. Согласование `/profile-rating` позволит брать streak из любого endpoint'а.

---

## 7. 🟡 СРЕДНИЙ: Атомарное обновление money в syncProgress

### Проблема

После завершения учебной сессии клиент делает оптимистичное обновление money (добавляет заработанные монеты локально), потом ждёт `getProfile()`. Если `getProfile()` вернёт старые данные до того, как backend обработал начисление — optimistic update затрётся.

### Что нужно

В ответе `syncProgress` прислать `new_balance` — точное значение после начисления:

```json
{
  "count": 15,                  // сколько монет начислено
  "new_balance": 1845,          // ← НОВОЕ, итоговый баланс после начисления
  "new_achievements": [...]
}
```

**Клиент**: используем `new_balance` напрямую, нет race-condition-ов.

---

## 8. 🟡 СРЕДНИЙ: Конфигурируемый battle daily limit

### Проблема

Лимит 3 попытки/день для non-premium сейчас захардкожен на клиенте. Продукту может захотеться изменить (например, 10 попыток для новых пользователей в первый день).

### Что нужно

Отдавать лимит в `/profile-rating` или `/user/settings`:

```json
{
  "battle_daily_limit": 3,       // сколько попыток в день у non-premium
  "battle_daily_remaining": 1    // сколько осталось сегодня
}
```

**Клиент**: будем читать вместо хардкода. `remaining` позволит показать "Осталось 1 битва на сегодня".

---

## 9. 🟢 НИЗКИЙ: `count_learned_words` — единая формула

### Проблема

Сервер считает "выучено" как `state > 0`, клиент — как `state == 2`. Результат: счётчики на разных устройствах разные.

### Что нужно

Зафиксировать одну формулу. Предложение: "выучено" = `state >= 1`. Согласовать с продуктом. Клиент подстроится.

---

## 10. 🟢 НИЗКИЙ: Version description — локализованные поля

### Проблема

`/version-info` возвращает `description` в одном языке.

### Что нужно

Локализованный объект:

```json
{
  "version": "1.4.2",
  "update_required": false,
  "description": {
    "tg": "Навигоркарди нав…",
    "ru": "Обновления…",
    "en": "Updates…"
  }
}
```

**Клиент**: уже готов. Берёт `description[locale]` с фолбэком на `tg` → любой доступный.

---

## 11. 🔧 Инфраструктура: тестовое окружение и API документация

### Тестовая среда

- Тестовый URL бэкенда (staging / dev) для проверки изменений до продакшна
- Тестовые учётки: premium / non-premium / admin
- Возможность сбросить дневной лимит battle для тестового пользователя (`POST /dev/reset-daily-limits`)

### Документация

- **Swagger / OpenAPI** для REST endpoints (`/profile-rating`, `/user/activity`, `/sync-progress` и т.д.)
- **WebSocket events documentation**: список всех типов сообщений client↔server с JSON-примерами. Сейчас часть приходится реверсить.

---

## Приложение А: Клиент-готовность

| # | Задача | Статус клиента |
|---|--------|---------------|
| 1 | Grace period | ✅ Обрабатывает `room_restored`, на реконнекте шлёт `check_room` с JWT. Готов к работе, как только фиксируется баг (секция "Баг-репорт"). |
| 2 | Deep link | ✅ Уже настроен на GitHub Pages фолбэк. После публикации backend'ом файлов на `api.vozhaomuz.com` — 10-минутная правка 3 файлов. |
| 3 | Ranking + призы | ⏳ При получении `place`, `finish_time` от сервера — подхватит автоматически. Если поля отсутствуют — fallback на текущую сортировку по score (backwards-compatible). |
| 4 | `wait_time_seconds` | ⏳ При получении — вернёт визуальный countdown. |
| 5 | `daily_limit_reached` | ✅ Уже парсит `type` события, шлёт локализованное сообщение. Дополнительные поля улучшат UX. |
| 6 | Streak field | ✅ Читает из `/user/activity`, не блокирует. Единое поле — upgrade path. |
| 7 | `new_balance` | ⏳ При получении — сразу использует вместо optimistic update. |
| 8 | Configurable daily limit | ⏳ При получении — читает из profile вместо хардкода. |
| 9 | `count_learned_words` | ⏳ Подстроится под серверную формулу. |
| 10 | Localized description | ✅ Уже парсит `description[locale]`. |
| 11 | Infrastructure / docs | — (не блокирует релизы, но ускорит отладку) |

---

## Приложение Б: Рекомендованный порядок внедрения

### Неделя 1 (критичные фиксы)

1. **Фикс бага grace period** (секция 1, "Баг-репорт") — самая критичная задача, ломает основной сценарий приглашения друзей. Начать с серверных логов, потом — проверка env-переменных и race conditions.

2. **Публикация deep-link файлов** (секция 2) — 3 файла, файлы уже готовы. Несколько часов работы, огромный эффект на UX.

### Неделя 2 (product-полиш)

3. **Ranking + призы** (секция 3) — большая, но изолированная задача. Можно делать параллельно с другими. 8 тест-кейсов чётко описаны.

4. **`wait_time_seconds`** (секция 4) — мелкий полиш, 30 минут работы.

### Неделя 3 (улучшения)

5. **`daily_limit_reached` structured** (секция 5)
6. **Streak field унификация** (секция 6)
7. **`new_balance` в syncProgress** (секция 7)
8. **Configurable daily limit** (секция 8)

### Когда дойдут руки (nice-to-have)

9. **`count_learned_words` формула** (секция 9)
10. **Localized version description** (секция 10)
11. **Testing infrastructure** (секция 11)

---

## Контакты

Клиентская сторона готова по каждому пункту, либо есть понятный план обновления — см. Приложение А. По каждому вопросу — welcome обсуждать форматы JSON, семантику полей, приоритеты.

**Файлы, прилагаемые к ТЗ**:

- [`deeplink-landing/`](../deeplink-landing/) — готовые файлы для секции 2 (assetlinks.json, AASA, index.html). Хостятся на GitHub Pages как временный фолбэк: https://mahmadizodashuhrat.github.io/vozhaomuz-landing/

**Предыдущие отдельные ТЗ** (консолидированы в этот документ, можно использовать для ссылок):
- [TZ_BACKEND_MASTER.md](TZ_BACKEND_MASTER.md) — первая версия master-документа
- [TZ_BACKEND_ROOM_DISCONNECT_GRACE.md](TZ_BACKEND_ROOM_DISCONNECT_GRACE.md) — детально grace period + баг-репорт
- [TZ_DEEP_LINK_BACKEND.md](TZ_DEEP_LINK_BACKEND.md) — детально deep link
- [TZ_BACKEND_BATTLE_RANKING_AND_PRIZES.md](TZ_BACKEND_BATTLE_RANKING_AND_PRIZES.md) — детально ranking + призы
