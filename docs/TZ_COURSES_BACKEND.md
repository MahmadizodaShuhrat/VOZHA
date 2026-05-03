# ТЗ для бэкенд-разработчика: Курсы (полная динамика с сервера)

**Текущее состояние мобилки:** курсы загружаются из локальных
ассетов (`assets/courses/index.json` + `assets/courses/<id>/course.json`),
прогресс хранится в `SharedPreferences`. Все интеграционные точки уже
готовы — нужно подменить асет-репозиторий на API.

**Задача:** перевести курсы на бэкенд так, чтобы:

1. Админ через панель мог публиковать новые курсы и обновлять контент
   без релиза мобилки.
2. Прогресс ученика синхронизировался между устройствами.
3. Локальный кэш на устройстве работал офлайн, но при появлении сети
   подтягивал новые версии.

---

## 1. Что нужно отдавать (Endpoints)

| Метод | URL | Назначение |
|-------|-----|-----------|
| `GET` | `/api/v1/dict/courses` | Список курсов (карточки для каталога) |
| `GET` | `/api/v1/dict/courses/{id}` | Полный JSON одного курса |
| `GET` | `/api/v1/user/courses/{id}/progress` | Прогресс пользователя по курсу |
| `POST` | `/api/v1/user/courses/{id}/lessons/{lessonId}/complete` | Отметить урок как пройденный |
| `POST` | `/api/v1/user/courses/{id}/tests/{testId}/result` | Записать результат теста |
| `GET` | `/api/v1/user/certificates` | Список сертификатов пользователя (опционально) |

Все запросы требуют `Authorization: Bearer <jwt>` + заголовки
`App-Version`, `App-Platform` (как у баннеров).

---

## 2. `GET /api/v1/dict/courses` — каталог

Облегчённый список для экрана «Курсы». Без модулей и тестов — только
данные для карточки.

```json
[
  {
    "id": "english_a1",
    "title": "Английский с 0",
    "subtitle": "Полная программа обучения с нуля",
    "level": "A1 — Beginner",
    "language": "en",
    "rating": 4.9,
    "students": 1240,
    "total_minutes": 600,
    "cover_url": "https://cdn.vozhaomuz.com/courses/english_a1/cover.png",
    "preview_url": "https://cdn.vozhaomuz.com/courses/english_a1/trailer.mp4",
    "instructor": {
      "name": "Саади Тоирзода",
      "role": "Преподаватель",
      "avatar_url": "https://cdn.vozhaomuz.com/courses/english_a1/instructor.jpg"
    },
    "published_at": "2024-03-10",
    "is_active": true,
    "is_premium": false,
    "lessons_count": 24,
    "modules_count": 4,
    "localization": {
      "ru": { "title": "Английский с 0", "subtitle": "..." },
      "tg": { "title": "Англисӣ аз сифр", "subtitle": "..." },
      "en": { "title": "English from Scratch", "subtitle": "..." }
    }
  }
]
```

**Фильтры на сервере:**
- `is_active = TRUE`
- `App-Platform` (если курс зависит от платформы — обычно нет)
- `App-Version` (минимальная версия мобилки, если курс использует новые
  типы игр — см. §6)
- `is_premium` отдаём всем, мобилка сама показывает «замок» бесплатным

**Локализация:** как у баннеров — `localization[<locale>].title/subtitle`
с фолбэком на корневые `title`/`subtitle`. Локали: `ru`, `tg`, `en`.

---

## 3. `GET /api/v1/dict/courses/{id}` — полный курс

Массивная структура — то, что мобилка сейчас грузит из
`assets/courses/english_a1/course.json` (схема ниже — это ground truth,
просто перенести 1-в-1).

```json
{
  "id": "english_a1",
  "title": "Английский с 0",
  "subtitle": "Полная программа обучения с нуля",
  "level": "A1 — Beginner",
  "language": "en",
  "rating": 4.9,
  "students": 1240,
  "total_minutes": 600,
  "description": "This English course combines 4 essential modules...",
  "instructor": { "name": "...", "role": "...", "avatar_url": "..." },
  "cover_url": "...",
  "preview_url": "...",
  "published_at": "2024-03-10",
  "is_active": true,
  "is_premium": false,
  "modules": [ /* см. §3.1 */ ],
  "localization": { /* как в §2 */ }
}
```

### 3.1. `Module` (хаб уроков)

```json
{
  "id": "lesson1_beginner",
  "title": "Алфавит, приветствия и числа",
  "subtitle": "НОВИЧОК — УРОК 1",
  "main_video": {
    "url": "https://cdn.vozhaomuz.com/courses/english_a1/m1/intro.mp4",
    "thumbnail": "https://cdn.vozhaomuz.com/courses/english_a1/m1/thumb.png"
  },
  "lessons": [ /* см. §3.2 */ ],
  "final_test": { /* CourseTestData, см. §3.4, опционально */ }
}
```

- `main_video` — обязательный проигрыш перед открытием уроков модуля.
  Может быть `null` (тогда уроки открыты сразу).
- `final_test` — финальный тест модуля. Заблокирован, пока все
  `lessons` не завершены. Может быть `null`.

### 3.2. `Lesson`

```json
{
  "id": "l1_greetings",
  "type": "video_with_words",
  "title": "Алфавит и приветствия",
  "duration_label": "8 мин 45 сек",
  "duration_seconds": 525,
  "video": {
    "url": "https://cdn.vozhaomuz.com/courses/english_a1/lessons/l1.mp4",
    "thumbnail": "..."
  },
  "words": [ /* CourseWord, см. §3.3 */ ],
  "test": { /* CourseTestData, см. §3.4, опционально */ }
}
```

**`type`** (строка) — что мобилка рендерит:

| Значение | Что отображает |
|----------|----------------|
| `video` | Только видео |
| `video_with_words` | Видео + слайдер слов после просмотра |
| `pronunciation` | Тренажёр произношения |
| `quiz` | Только тест/игра, без видео |
| `words` | Только словарь, без видео |

**Поле `status` НЕ нужно от бэка** — это вычисляемое поле на клиенте
(зависит от прогресса пользователя, см. §4).

### 3.3. `CourseWord` (словарная единица)

```json
{
  "id": 900101,
  "word": "hello",
  "translation": "привет",
  "transcription": "[həˈloʊ]",
  "example": "Hello! How are you?",
  "example_translation": "Привет! Как дела?"
}
```

Все строки — обязательные, кроме `transcription`/`example`/
`example_translation` (могут быть пустыми).

`id: int` — уникален в рамках всего бэка (используется для прогресса
заучивания слов в общей системе слов).

### 3.4. `CourseTestData` (контейнер игр)

```json
{
  "test_title": "Алфавит и приветствия",
  "language": "en",
  "current_path": "",
  "sections": [
    {
      "id": "g1_choose",
      "title": "Выберите перевод",
      "questions": [ /* CourseTestQuestion, см. §3.5 */ ]
    }
  ]
}
```

- `test_title` — название теста, отображается в шапке.
- `language` — целевой язык (`en` / `ru` и т. п.).
- `current_path` — оставлять пустым (legacy от Unity).

### 3.5. `CourseTestQuestion` (одна игра)

```json
{
  "id": "g1_q1",
  "type": "MultiChoiceGame",
  "title": "Выберите правильный перевод",
  "parameter": null,
  "prompt_additional": null,
  "text_file_name": null,
  "sprite_name": null,
  "audio_name": null,
  "data_source": [ /* CourseTestOption, см. §3.6 */ ],
  "word_bank": [],
  "phrase_bank": []
}
```

**`type`** — один из 13 поддерживаемых клиентом (см. §6 для полной
матрицы).

### 3.6. `CourseTestOption` (один пункт игры)

Структура зависит от типа игры. Универсальные поля:

```json
{
  "text": "hello",
  "max_length": 0,
  "correct_answer": "привет",
  "correct_answers": [],
  "answers": ["привет", "до свидания", "спасибо", "пожалуйста"],
  "word_bank": [],
  "sprite_name": null,
  "audio_name": null
}
```

Спец-поля для отдельных игр:

| Поле | Используется в | Тип |
|------|----------------|-----|
| `blanks` | `FillBlankGame` | `[{correct_answer, correct_answers}]` |
| `category` + `items` | `CategorizeGame` | `string` + `string[]` |
| `width`, `height`, `empty`, `grid`, `words` | `CrosswordGame` | см. §6 |

---

## 4. Прогресс пользователя

### 4.1. `GET /api/v1/user/courses/{id}/progress`

```json
{
  "course_id": "english_a1",
  "completed_lessons": ["l1_greetings", "l1_numbers"],
  "completed_tests": ["t1_module_test"],
  "test_results": [
    {
      "test_id": "t1_module_test",
      "score": 85,
      "max_score": 100,
      "completed_at": "2026-05-02T10:30:00Z"
    }
  ],
  "watched_main_videos": ["lesson1_beginner"],
  "started_at": "2026-04-15T08:00:00Z",
  "last_activity_at": "2026-05-02T10:30:00Z",
  "is_completed": false,
  "completed_at": null,
  "certificate_url": null
}
```

### 4.2. `POST /api/v1/user/courses/{id}/lessons/{lessonId}/complete`

Body:
```json
{
  "duration_seconds": 540,
  "score": null
}
```

Идемпотентно — повторный вызов не создаёт дубликат.

Response — обновлённый `progress` (как в §4.1).

### 4.3. `POST /api/v1/user/courses/{id}/tests/{testId}/result`

Body:
```json
{
  "score": 85,
  "max_score": 100,
  "answers": [
    { "question_id": "g1_q1", "correct": true },
    { "question_id": "g1_q2", "correct": false }
  ]
}
```

Можно вызывать многократно — берём максимальный `score` за пользователем.

### 4.4. Сертификат

Когда `completed_lessons.length == total_lessons` И все `final_test`
сданы → бэкенд:
1. Помечает `is_completed = true`
2. Генерирует сертификат (или сохраняет данные для генерации)
3. Возвращает `certificate_url` (PDF в R2 / S3)

Альтернатива — мобилка сама генерирует PDF (как сейчас в
`certificate_pdf.dart`), а бэк просто хранит запись о факте завершения.

---

## 5. Кэширование (важно)

Курсы — большие JSON-ы. Стратегия:

| Когда | Действие |
|-------|----------|
| Первый запуск | `GET /courses` → закэшировать список |
| Открытие курса | `GET /courses/{id}` → закэшировать на диске на 24 ч |
| Холодный старт | Показать кэш + параллельно `GET /courses` (SWR) |
| `AppLifecycleState.resumed` после > 1 ч | Перезапросить список |
| Pull-to-refresh | Перезапросить всё |

**Инвалидация:** в ответе `/courses` отдавать `updated_at`. Если
`updated_at` не изменился с прошлого запроса — клиент использует кэш
без `/courses/{id}`.

```json
[
  {
    "id": "english_a1",
    "title": "...",
    "updated_at": "2026-05-02T11:31:00Z",
    ...
  }
]
```

Альтернатива — заголовок `If-Modified-Since` / `ETag`.

---

## 6. Типы игр — матрица для админ-панели

| `type` | Поля в `CourseTestOption` | Описание |
|--------|---------------------------|---------|
| `MultiChoiceGame` | `text`, `answers[]`, `correct_answer` | Один правильный из 4+ |
| `SelectAnswers` | `text`, `answers[]`, `correct_answers[]` | Несколько правильных |
| `MatchingGame` | `text`, `correct_answer` + общий `word_bank[]` | Соединить пары |
| `CollectWords` | `text` (подсказка), `correct_answer` (слово) | Собрать слово из букв |
| `FillBlankGame` | `text` (с `____`), `blanks[]` | Заполнить пропуски |
| `CategorizeGame` | `category`, `items[]` | Распределить по категориям |
| `DragDropGame` | `text`, `correct_answer` | Перетащить в зону |
| `DropdownGame` | `text`, `answers[]`, `correct_answer` | Выбрать из dropdown |
| `OrderingGame` | `text` (порядок задаётся индексом в `data_source`) | Расставить по порядку |
| `CrosswordGame` | `width`, `height`, `grid[]`, `words[]` | Кроссворд |
| `SpeakingWithAI` | `text` (фраза для произнесения) | Speech-to-text + AI оценка |
| `WriteWithAI` | `text` (промпт) | Свободный ввод + AI оценка |
| `CombinedTest` | nested `sections[]` | Контейнер для нескольких игр |

Полная схема `CrosswordGame`:
```json
{
  "width": 10, "height": 10, "empty": "#",
  "grid": ["##H##", "HELLO", "##L##"],
  "words": [
    {
      "word": "HELLO",
      "direction": "across",
      "start": { "x": 0, "y": 1 },
      "letters": [
        { "char": "H", "x": 0, "y": 1 },
        { "char": "E", "x": 1, "y": 1 },
        { "char": "L", "x": 2, "y": 1 },
        { "char": "L", "x": 3, "y": 1 },
        { "char": "O", "x": 4, "y": 1 }
      ],
      "question": "Приветствие",
      "sprite": "wave.png"
    }
  ]
}
```

---

## 7. Хранение медиа

**Видео, картинки, аудио** — в Cloudflare R2 (как баннеры).

Соглашение по ключам:
```
courses/<course_id>/cover.png
courses/<course_id>/trailer.mp4
courses/<course_id>/instructor.jpg
courses/<course_id>/modules/<module_id>/intro.mp4
courses/<course_id>/lessons/<lesson_id>.mp4
courses/<course_id>/sprites/<name>.png
courses/<course_id>/audio/<name>.mp3
```

В JSON отдавать **полные публичные URL** (`https://...`), не относительные пути.

**Кэш:** заголовки `Cache-Control: public, max-age=31536000, immutable`.
При замене медиа — новое имя файла (UUID-based), не overwrite, чтобы
кэш мобилки не протухал.

---

## 8. Структура БД (рекомендация)

```sql
CREATE TABLE courses (
  id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  subtitle VARCHAR(500),
  level VARCHAR(64),
  language VARCHAR(8) NOT NULL,
  rating NUMERIC(2,1) DEFAULT 0,
  students INT DEFAULT 0,
  total_minutes INT DEFAULT 0,
  description TEXT,
  cover_url TEXT,
  preview_url TEXT,
  instructor JSONB NOT NULL,
  published_at DATE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  app_version NUMERIC(3,2) DEFAULT 1.0,
  localization JSONB,
  modules JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE user_course_progress (
  user_id BIGINT NOT NULL,
  course_id VARCHAR(64) NOT NULL,
  completed_lessons TEXT[] NOT NULL DEFAULT '{}',
  completed_tests TEXT[] NOT NULL DEFAULT '{}',
  watched_main_videos TEXT[] NOT NULL DEFAULT '{}',
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_activity_at TIMESTAMP NOT NULL DEFAULT NOW(),
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMP NULL,
  certificate_url TEXT NULL,
  PRIMARY KEY (user_id, course_id),
  FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE
);

CREATE TABLE user_test_results (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  course_id VARCHAR(64) NOT NULL,
  test_id VARCHAR(128) NOT NULL,
  score INT NOT NULL,
  max_score INT NOT NULL,
  answers JSONB,
  completed_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, course_id, test_id, completed_at)
);
```

---

## 9. Админ-панель (рекомендации)

Аналогично баннерам (https://api.vozhaomuz.com/admin/banners). По
адресу `/admin/courses`:

- Список всех курсов с toggle `is_active`.
- Создать/редактировать курс — большая форма с tabs:
  - **Общее:** title, subtitle, level, instructor, обложка, тизер
  - **Модули:** drag-and-drop, для каждого — main_video + список уроков
  - **Уроки:** title, type, video URL, words (список), test (см. ниже)
  - **Тесты:** для каждого — секции, для каждой секции — вопросы,
    для каждого вопроса — type + data_source[]
  - **Локализация:** title/subtitle для ru/tg/en
- **Превью** — открывает мобильный мокап с полным курсом.
- **Загрузка медиа** — drag-drop в R2, возвращает URL для вставки в JSON.

JSON-импорт/экспорт — обязательно. Формат — то же `course.json`, что
сейчас в ассетах. Это позволяет:
- Перевести существующий курс одной заливкой.
- Бекапить/откатывать.
- Редактировать большие куски в IDE.

---

## 10. Чек-лист миграции

### Шаг 1 — бэк (без мобилки)
- [ ] Создать таблицы (§8)
- [ ] Залить `english_a1/course.json` (есть в репо мобилки —
      `assets/courses/english_a1/course.json`)
- [ ] Реализовать `GET /api/v1/dict/courses` (§2)
- [ ] Реализовать `GET /api/v1/dict/courses/{id}` (§3)
- [ ] Открыть `/admin/courses` для редактирования
- [ ] Дать тестовый JWT мобильному разработчику для проверки

### Шаг 2 — прогресс (без мобилки)
- [ ] Реализовать `GET /api/v1/user/courses/{id}/progress` (§4.1)
- [ ] Реализовать `POST .../lessons/{lessonId}/complete` (§4.2)
- [ ] Реализовать `POST .../tests/{testId}/result` (§4.3)

### Шаг 3 — мобилка переключается
- [ ] Создать `ApiCourseContentRepository` (Dio-backed) с теми же
      методами что у `AssetCourseContentRepository`
      (`loadAll()`, `loadById(id)`)
- [ ] Создать `RemoteCourseProgressRepository` с
      `load(courseId)`/`save(...)`/`markCompleted(...)` против бэка
- [ ] Подменить override-ы в `course_fixture_provider.dart` и
      `course_progress_provider.dart`
- [ ] Кэш на диске (Hive / shared_preferences) на 24 ч
- [ ] SWR — показывать кэш, рядом перезапрашивать
- [ ] Лайфсайкл — `refreshIfStale` после resume > 1 ч

### Шаг 4 — сертификаты (опционально)
- [ ] Бэк хранит факт завершения курса.
- [ ] Мобилка по-прежнему генерирует PDF локально (`certificate_pdf.dart`)
      и шлёт через share sheet — бэк не нужен.
- [ ] Если хотим серверный сертификат — `GET /api/v1/user/certificates`
      возвращает список с `certificate_url`.

---

## 11. Edge cases

| Кейс | Поведение бэка | Поведение мобилки |
|------|----------------|-------------------|
| `is_active = false` | Не возвращать | — |
| Курс удалён, но прогресс есть | Прогресс остаётся, но `course_id` 404 | Скрыть карточку |
| Мобилка устаревшей версии шлёт `complete` | Принять, ответить 200 | — |
| Сеть упала на `/courses/{id}` | — | Показать кэш + retry |
| Видео CDN недоступен | — | Показать toast «Загрузите урок позже» |
| Локаль клиента — `de` (нет в `localization`) | Отдать корневой `title` | — |
| Игра с типом, который мобилка не знает | Отдать как есть | Показать «Обновите приложение» вместо игры |
| Прогресс конфликтует (offline writes) | last-write-wins по `completed_at` | Шлём все накопленные `complete`-ы при появлении сети |

---

## 12. Сводка для мобильной стороны (после деплоя бэка)

После того как §10 шаги 1–2 готовы, мобилке нужно:

| Файл | Что меняется |
|------|--------------|
| `lib/feature/courses/data/repository/course_content_repository.dart` | Добавить `ApiCourseContentRepository` |
| `lib/feature/courses/data/repository/course_progress_repository.dart` | Добавить `RemoteCourseProgressRepository` |
| `lib/feature/courses/presentation/providers/course_fixture_provider.dart` | Заменить override на API-реализацию |
| `lib/feature/courses/presentation/providers/course_progress_provider.dart` | Заменить override на API-реализацию |
| `lib/feature/courses/data/models/course_fixture.dart` | Сверить JSON-ключи (snake_case) с тем, что отдаст бэк |

Объём — ~4-6 часов на интеграцию + тесты. Модели уже готовы, схема
один-в-один совпадает.

---

## Контакты

Любые вопросы по структуре `data_source` для конкретной игры — пишите,
покажу как мобилка её парсит. Эталонный JSON со всеми типами игр —
`assets/courses/english_a1/course.json` в репо мобилки.
