# Courses

This document explains how the Courses feature is structured and how
to add or edit course content while the real backend is in
development.

---

## Table of contents

1. [Architecture](#architecture)
2. [Folder layout](#folder-layout)
3. [JSON schema](#json-schema)
4. [Game data formats](#game-data-formats)
5. [Adding a new course](#adding-a-new-course)
6. [Progress tracking](#progress-tracking)
7. [Replacing the mock backend](#replacing-the-mock-backend)
8. [Open TODOs](#open-todos)

---

## Architecture

```
Course (top-level)
└── Module ("Урок 1 — Новичок")
    ├── mainVideo            — intro video shown at the top of the hub
    ├── Lessons (sub-lessons)
    │   ├── video            — lesson video
    │   ├── words[]          — vocabulary introduced (currently surfaced
    │   │                      only as data; the vocabulary intro page
    │   │                      was removed per UX decision)
    │   └── test             — CourseTestData with sections of games
    └── finalTest            — module-wide test, runs every game
```

### Screen flow

```
Bottom nav → Courses tab        (CoursesTabPage)
   ↓ tap a featured course
Course detail page              (CourseDetailPage)
   ↓ tap a module hub card
Lesson hub page                 (LessonHubPage)
   ├── tap mainVideo            → LessonPlayerPage  → pop back
   ├── tap a sub-lesson card    → LessonPlayerPage  → pop back
   ├── tap "Изучать слова N/M"  → ChoseLearnKnowPage (the 4000-essential
   │                              learn flow)
   └── tap "Пройти тест"        → CourseTestPage    → pop back
```

After every successful pop back to the course detail screen, the
module's progress refreshes via `courseProgressProvider`.

---

## Folder layout

```
lib/feature/courses/
├── data/
│   ├── models/
│   │   ├── course_fixture.dart           ← top-level course/module/lesson models
│   │   ├── course_models.dart            ← legacy 4000-essential course models
│   │   └── course_test_models.dart       ← test/quiz models (used by game widgets)
│   └── repository/
│       ├── course_content_repository.dart   ← interface + AssetCourseContentRepository
│       └── course_progress_repository.dart  ← interface + LocalCourseProgressRepository
├── presentation/
│   ├── providers/
│   │   ├── course_fixture_provider.dart   ← courseByIdProvider, courseContentRepositoryProvider
│   │   └── course_progress_provider.dart  ← courseProgressProvider, applyProgress()
│   ├── screens/
│   │   ├── courses_tab_page.dart        — bottom-nav tab
│   │   ├── course_detail_page.dart      — tabs: Контент / Маълумот / Шарҳҳо
│   │   ├── lesson_hub_page.dart         — single module hub (screenshot design)
│   │   ├── lesson_player_page.dart      — video player with first-watch lock
│   │   ├── course_test_page.dart        — game orchestrator (existing)
│   │   ├── certificate_pdf.dart         — printable PDF certificate
│   │   └── lesson_words_page.dart       — legacy
│   ├── theme/
│   │   └── course_theme.dart            — CourseColors / CourseMotion tokens
│   └── widgets/
│       ├── course_error_boundary.dart   — friendly fallback for crashed widgets
│       └── games/                       — all 13 game widgets used by CourseTestPage
└── …

assets/courses/
├── index.json                             ← list of course IDs
└── english_a1/
    └── course.json                        ← full content for the demo course
```

---

## JSON schema

Top of `assets/courses/<id>/course.json`:

```json
{
  "id": "english_a1",
  "title": "...",
  "subtitle": "...",
  "level": "A1 — Beginner",
  "rating": 4.9,
  "students": 1240,
  "language": "en",
  "publishedAt": "2024-03-10",
  "totalMinutes": 600,
  "instructor": { "name": "...", "role": "...", "avatarUrl": null },
  "coverUrl": null,
  "previewUrl": "https://.../intro.mp4",
  "description": "...",
  "modules": [ ... ]
}
```

A `module` is a hub:

```json
{
  "id": "lesson1_beginner",
  "title": "Алфавит, приветствия и числа",
  "subtitle": "НОВИЧОК — УРОК 1",
  "mainVideo": { "url": "...", "thumbnail": null },
  "lessons": [ ... ],
  "finalTest": { ... }   // CourseTestData (see below)
}
```

A `lesson` is one sub-activity:

```json
{
  "id": "l1_greetings",
  "type": "video_with_words",
  "title": "Алфавит и приветствия",
  "durationLabel": "8 мин 45 сек",
  "durationSeconds": 525,
  "status": "current",                    // completed / current / locked
  "video": { "url": "...", "thumbnail": null },
  "words": [
    {
      "id": 900101,
      "word": "hello",
      "translation": "привет",
      "transcription": "[həˈloʊ]",
      "example": "Hello! How are you?",
      "exampleTranslation": "Привет! Как дела?"
    }
  ],
  "test": { ... }                         // optional CourseTestData
}
```

**Note:** The JSON's `status` field is treated as a *seed* — once the
user has any progress in `SharedPreferences`, the persisted set
overrides it. See [Progress tracking](#progress-tracking).

---

## Game data formats

`CourseTestData` is a list of sections, each with a list of
`questions`. Every question has a `type` that maps to one of the
widgets in `lib/feature/courses/presentation/widgets/games/`.

The mapping lives in `course_test_page.dart::_buildGameWidget`. Both
the bare and `UI`-prefixed names map to the same widget (legacy Unity
naming).

### Common envelope

```json
{
  "test_title": "...",
  "language": "en",
  "sections": [
    {
      "id": "section1",
      "title": "...",
      "questions": [ /* one or more questions */ ]
    }
  ]
}
```

### MultiChoiceGame

Pick one answer per row.

```json
{
  "id": "q1",
  "type": "MultiChoiceGame",
  "title": "Выберите правильный перевод",
  "data_source": [
    {
      "text": "hello",
      "answers": ["привет", "до свидания", "спасибо", "пожалуйста"],
      "correct_answer": "привет"
    }
  ]
}
```

### SelectAnswers / SelectMoreAnswers

Same shape as MultiChoice, but the question is "select 1 (or many)
correct answers from the list". `SelectMoreAnswers` requires
`multiSelect: true` in the widget — keep `correct_answers` (plural)
in the JSON when you want multiple right answers:

```json
{
  "type": "SelectMoreAnswers",
  "data_source": [
    {
      "text": "Which are greetings?",
      "answers": ["hello", "goodbye", "five", "please"],
      "correct_answers": ["hello", "goodbye"]
    }
  ]
}
```

### MatchingGame

Drag-match left items to right items. Right items live in
`word_bank`.

```json
{
  "type": "MatchingGame",
  "title": "Соедините слово с переводом",
  "data_source": [
    { "text": "hello", "correct_answer": "привет" },
    { "text": "goodbye", "correct_answer": "до свидания" }
  ],
  "word_bank": ["привет", "до свидания"]
}
```

### CollectWords

Tap letters in order to spell the answer.

```json
{
  "type": "CollectWords",
  "data_source": [
    { "text": "привет", "correct_answer": "hello" }
  ]
}
```

### FillBlankGame

Sentence with blanks (`____`) to fill in.

```json
{
  "type": "FillBlankGame",
  "data_source": [
    {
      "text": "Hello! ____ are you?",
      "blanks": [{ "correct_answer": "How" }]
    }
  ]
}
```

### Ordering

Reorder the items in `wordBank` to match the correct sequence.

```json
{
  "type": "Ordering",
  "data_source": [
    { "text": "Build the sentence", "correct_answers": ["I", "am", "happy"] }
  ],
  "word_bank": ["am", "I", "happy"]
}
```

### DropDownGame

A sentence with one or more dropdowns; pick the correct option for
each.

```json
{
  "type": "DropDownGame",
  "data_source": [
    {
      "text": "She [...] a teacher.",
      "answers": ["is", "are", "am"],
      "correct_answer": "is"
    }
  ]
}
```

### DragDropItems

Drag items into matching slots. Matches the matching game UX in spirit
but keeps drag affordance distinct.

```json
{
  "type": "DragDropItems",
  "data_source": [
    { "text": "hello", "correct_answer": "привет" }
  ],
  "word_bank": ["привет", "до свидания"]
}
```

### CategorizeGame

Place items into one of several named categories.

```json
{
  "type": "CategorizeGame",
  "data_source": [
    { "category": "fruits", "items": ["apple", "banana"] },
    { "category": "animals", "items": ["cat", "dog"] }
  ],
  "word_bank": ["apple", "banana", "cat", "dog"]
}
```

### CrossWord

Crossword grid. Most complex format — see `course_test_models.dart`
and `crossword_game.dart` for the shape.

### SpeakingWithAI / WriteWithAI

Open-ended speech and writing tasks scored by an AI prompt. They use
`text_file_name`, `prompt_additional`, and OpenAI / Azure speech
calls. Fixture authors should provide the prompt, an example answer,
and reference text. (Not yet exercised by the demo course.)

---

## Adding a new course

1. Create `assets/courses/<id>/course.json` following the schema
   above.
2. Add `<id>` to the `courses` array in `assets/courses/index.json`.
3. Re-run `flutter pub get` if you added new asset folders. The
   `pubspec.yaml` `assets:` block currently uses
   `assets/courses/` and `assets/courses/<id>/`.
4. Hot-restart the app. The new course shows up on the Courses tab
   automatically.

---

## Progress tracking

* Storage key: `course_progress_<courseId>` in `SharedPreferences`.
* Value: `{"completed":["lessonId1","lessonId2", ...]}`.
* On first run we seed it from the JSON's `status: "completed"`
  lessons so the demo content reflects the fixture immediately.
* Every subsequent change goes through
  `markLessonCompleted(ref, courseId, lessonId)` →
  `LocalCourseProgressRepository.markCompleted(...)`.
* Consumers watch `courseProgressProvider(courseId)` and rebuild on
  invalidation.
* `applyProgress(modules, completedIds)` rewrites lesson statuses on
  the way to the UI: completed → completed, first non-completed →
  current, the rest → locked.

The progress data is **not signed** — a determined user can edit
prefs and mark everything done. Acceptable for an MVP; if anti-cheat
matters, sign with HMAC or move auth to the backend.

---

## Replacing the mock backend

When the real API is ready:

1. Implement `CourseContentRepository` against your API client (e.g.
   Dio):

   ```dart
   class ApiCourseContentRepository implements CourseContentRepository {
     final Dio dio;
     ApiCourseContentRepository(this.dio);
     // …
   }
   ```

2. Override the provider at app start (or in your Riverpod scope):

   ```dart
   ProviderScope(
     overrides: [
       courseContentRepositoryProvider.overrideWithValue(
         ApiCourseContentRepository(dio),
       ),
     ],
     child: MyApp(),
   );
   ```

3. Same drill for `CourseProgressRepository` once the user-progress
   API ships.

The screens, models, and the rest of the feature stay untouched.

---

## Open TODOs

* **Locale-aware JSON content** — currently all titles/descriptions
  are Russian only. Either add per-locale JSON files
  (`course.tg.json`, `course.ru.json`, `course.en.json`) or move to
  inline `{ "ru": ..., "tg": ..., "en": ... }` objects on each field.
* **Split JSON per module** — the demo course is ~370 lines and
  growing. Split into `course.json` (meta) + `modules/<moduleId>.json`
  to keep diffs readable.
* **Use Freezed for models** — replace hand-written `fromJson`
  parsers with `freezed` + `json_serializable`. Saves ~150 lines and
  prevents silent null bugs.
* **Final-test lock** — the "Пройти тест" button is currently always
  tappable for testing. Re-enable the
  `unlocked = allSubLessonsCompleted` gate once the backend tracks
  test attempts.
* **Cover all 13 game types in the demo** — the fixture currently
  exercises four (`MultiChoiceGame`, `MatchingGame`, `CollectWords`,
  `SelectAnswers`). Add at least one example per remaining type.
* **Course content versioning** — once the backend is online, hash or
  version every course payload so we can invalidate local caches when
  content changes.
