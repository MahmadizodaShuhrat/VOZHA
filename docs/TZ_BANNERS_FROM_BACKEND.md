# ТЗ для мобильного разработчика: Баннеры из БД (полное управление с бэкенда)

**Бэкенд:** задеплоен и работает (последний коммит `ba58fcc`).
**Что нужно от мобилки:** добавить новые поля в `BannerDto`, обработку `type='rating'`, новые `app://` deep-links, удалить хардкод rating-слайда, **обновить стратегию кэширования** (см. §11 — это новое).

---

## 1. Что изменилось на бэкенде

Раньше баннеры лежали в `static/banners/banners.json` на сервере — менять можно было только релизом бэкенда. Теперь они в Postgres-таблице `banners`, и существует **полностью функциональная админ-панель** на https://api.vozhaomuz.com/admin/banners (логин/пароль). Админ может в любой момент:
- включить/выключить любой баннер одним кликом,
- поменять порядок (drag-and-drop),
- загрузить новую картинку (drag-drop в R2 CDN),
- запланировать кампанию по датам,
- таргетировать на free / pre юзеров,
- редактировать локализованные title для ru/tg/en/uz.

**Это значит баннеры теперь меняются «вживую»** — мобилке нельзя кэшировать ответ API на сутки, иначе изменения админа долетят до пользователей с большим лагом. Подробности по кэшу — в §11.

**Endpoint, URL, заголовки — НЕ изменились:**

```
GET /api/v1/dict/banners
Authorization: Bearer <jwt>
App-Version: 2.57
App-Platform: android | ios
```

Изменился **только формат строки в массиве**: добавились новые опциональные поля.

---

## 2. Новый формат `BannerDto`

### Полный JSON одной строки (новое):

```json
{
  "id": 7,
  "type": "image",
  "title": "UIBannerPremium",
  "file_name": "files/banners/banner_premium_android",
  "link": "app://Premium",
  "position": 7,
  "priority": 0,
  "is_active": true,
  "app_version": 2.57,
  "platform": "android",
  "valid_from": null,
  "valid_to": null,
  "target_user_type": null,
  "min_user_level": null,
  "localization": {
    "ru": { "title": "Купи премиум" },
    "en": { "title": "Buy premium" },
    "tg": { "title": "Премиум харед" },
    "uz": { "title": "Premium sotib oling" }
  },
  "created_at": "2026-05-02T11:31:00Z",
  "updated_at": "2026-05-02T11:31:00Z"
}
```

### Поля по приоритету реализации

| Поле | Тип | Что делать на клиенте |
|------|-----|---------------------|
| `id`, `title`, `file_name`, `link`, `position`, `app_version`, `platform` | как раньше | без изменений |
| **`type`** | `"image"` \| `"rating"` | **обязательно** обработать, см. §3 |
| **`is_active`** | bool | защитный фильтр (бэк уже фильтрует, но на всякий случай) |
| `priority` | int | для устойчивой сортировки при равных `position` |
| `valid_from`, `valid_to` | RFC3339 UTC \| null | бэк уже фильтрует, клиент не считает |
| `target_user_type` | `"free"` \| `"pre"` \| null | бэк уже фильтрует |
| `min_user_level` | int \| null | бэк уже фильтрует |
| **`localization`** | объект | используется для мультиязычного title, см. §4 |
| `created_at`, `updated_at` | RFC3339 | можно игнорировать на клиенте |

---

## 3. Обработка `type='rating'` — главный фикс

### Сейчас в коде (`home_banner_section.dart`)

Хардкод rating-слайда — невозможно выключить, нельзя менять порядок, нельзя локализовать.

### Что делать

Удалить хардкод. В рендере карусели:

```dart
Widget _buildBannerCard(BannerDto banner) {
  switch (banner.type) {
    case 'rating':
      return RatingBannerWidget(banner: banner); // существующий top-3 widget
    case 'image':
    default:
      return ImageBannerWidget(banner: banner);  // обычный — картинка + клик
  }
}
```

### Поведение `RatingBannerWidget`

- Подтягивает `top-3-users-day` из существующего endpoint, **как было раньше**.
- Берёт `title` из `banner.localization[locale]?.title ?? banner.title`.
- Тап → `_handleBannerTap('app://Rating')` (или `banner.link`).

### Forward compat (важно)

Если в будущем бэк добавит новые типы (`achievements`, `streak`, `daily_quest`...), старый клиент должен **не падать**. Дефолт в `switch` на `image` гарантирует, что неизвестный тип отрисуется как обычный баннер по `file_name` + `link`. Бэк специально оставляет `link = "app://Rating"` для rating-баннера, чтобы старые клиенты тоже могли клик обработать.

---

## 4. Локализация

### Поле `localization` — приоритетнее `title`

Бэк отдаёт **и** старый `title`, **и** новый `localization`. Логика выбора:

```dart
String resolveTitle(BannerDto b, String locale) {
  // locale: 'ru' / 'en' / 'tg' / 'uz' (из настроек приложения)
  final loc = b.localization?[locale];
  if (loc != null && loc['title'] is String && (loc['title'] as String).isNotEmpty) {
    return loc['title'] as String;
  }
  return b.title; // fallback на старое поле
}
```

`tg` для таджикского (не `tj`!) — синхронизировано с `localization` ключами на бэке. Если в проекте используется `tj` — маппить.

---

## 5. Защитная фильтрация на клиенте (опционально, но желательно)

Бэк уже отфильтровал `is_active`, `valid_*`, `target_user_type`, `platform`, `app_version`. **Но**: если бэк-сторож сломается или клиент кэширует старый ответ — фильтр на клиенте подстрахует.

```dart
bool isBannerVisible(BannerDto b) {
  if (b.isActive == false) return false;
  if (b.platform != currentPlatform) return false;
  if (b.appVersion > appVersion) return false;
  if (b.validFrom != null && DateTime.now().toUtc().isBefore(b.validFrom!)) return false;
  if (b.validTo != null && DateTime.now().toUtc().isAfter(b.validTo!)) return false;
  return true;
}
```

`target_user_type`/`min_user_level` на клиенте можно не проверять — это серверная ответственность.

---

## 6. Сортировка на клиенте

```dart
banners.sort((a, b) {
  final byPos = a.position.compareTo(b.position);
  if (byPos != 0) return byPos;
  return b.priority.compareTo(a.priority); // выше priority — выше в списке
});
```

При равных `position` бэк уже ставит `priority DESC`. Клиент-side сортировка нужна только если получаешь баннеры из нескольких источников или объединяешь с локальным кэшем.

---

## 7. Расширение deep-link router'а (важно)

Существующий handler `_handleBannerTap(String link)` сейчас знает 4 маршрута: `app://Premium`, `app://UIBuyCoins`/`UICoinPage`, `app://UIInviteFriend`, `app://UIBattlePage`.

**Добавить новые** (бэк может выдавать их в `link`):

| `link` | Куда вести |
|--------|-----------|
| `app://Rating` | Открывает экран рейтинга (`AllTop30Vozhaomuz`) |
| `app://Courses` | Переключает таб «Курсы» |
| `app://CourseDetail/<id>` | Открывает детали курса по id |
| `app://Streak` | Открывает диалог «Файлоилии шумо» (streak-страница) |
| `app://Achievements` | Открывает экран достижений |
| `app://Profile` | Открывает профиль |
| `app://MyWords` | Переключает таб «Калимаҳои ман» |
| `app://Shop` | Открывает магазин коинов |
| `app://Settings` | Открывает настройки |
| `app://Promo/<code>` | Открывает экран промокода с пред-заполненным `<code>` |

**Forward-compat:** если link неизвестен — log + ничего не делать (не падать). Можно показать toast «Обновите приложение».

```dart
void _handleBannerTap(String link) {
  if (link.startsWith('https://')) {
    launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    return;
  }
  if (!link.startsWith('app://')) return;

  final route = link.substring('app://'.length);
  final segments = route.split('/');
  final action = segments.first;
  final arg = segments.length > 1 ? segments.sublist(1).join('/') : null;

  switch (action) {
    case 'Premium':           Navigator.push(/* MySubscriptionPage */); break;
    case 'UICoinPage':
    case 'UIBuyCoins':        Navigator.push(/* CoinShopPage */); break;
    case 'UIInviteFriend':    Navigator.push(/* InviteFriendPage */); break;
    case 'UIBattlePage':      Navigator.push(/* BattlePage */); break;
    case 'Rating':            Navigator.push(/* AllTop30Page */); break;
    case 'Courses':           homeTabController.animateTo(coursesTabIndex); break;
    case 'CourseDetail':      if (arg != null) Navigator.push(/* CourseDetailPage(id: int.parse(arg)) */); break;
    case 'Streak':            showStreakDialog(); break;
    case 'Achievements':      Navigator.push(/* AchievementsPage */); break;
    case 'Profile':           Navigator.push(/* ProfilePage */); break;
    case 'MyWords':           homeTabController.animateTo(myWordsTabIndex); break;
    case 'Shop':              Navigator.push(/* ShopPage */); break;
    case 'Settings':          Navigator.push(/* SettingsPage */); break;
    case 'Promo':             Navigator.push(/* PromoPage(prefilled: arg) */); break;
    default:
      debugPrint('Unknown banner link: $link');
      // optionally: показать «Обновите приложение для этой акции»
  }
}
```

---

## 8. Изменения в `BannerDto`

### Текущая (предположительно)

```dart
@freezed
class BannerDto with _$BannerDto {
  const factory BannerDto({
    required int id,
    required String title,
    @JsonKey(name: 'file_name') required String fileName,
    required String link,
    required int position,
    @JsonKey(name: 'app_version') required double appVersion,
    required String platform,
  }) = _BannerDto;
}
```

### Новая

```dart
@freezed
class BannerDto with _$BannerDto {
  const factory BannerDto({
    required int id,
    @Default('image') String type,
    required String title,
    @JsonKey(name: 'file_name') required String fileName,
    required String link,
    required int position,
    @Default(0) int priority,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'app_version') required double appVersion,
    required String platform,
    @JsonKey(name: 'valid_from') DateTime? validFrom,
    @JsonKey(name: 'valid_to') DateTime? validTo,
    @JsonKey(name: 'target_user_type') String? targetUserType,
    @JsonKey(name: 'min_user_level') int? minUserLevel,
    @Default({}) Map<String, dynamic> localization,
  }) = _BannerDto;

  factory BannerDto.fromJson(Map<String, dynamic> json) => _$BannerDtoFromJson(json);
}
```

После изменения — `dart run build_runner build --delete-conflicting-outputs` чтобы пересобрать `.g.dart`/`.freezed.dart`.

---

## 9. Сценарии тестирования

### A. Базовое поведение (не должно сломаться)

- [ ] Запустить приложение на android и ios — баннеры отображаются как и раньше.
- [ ] Тап по существующим баннерам (`UIBannerPremium`, `UIBannerBattle` и т.д.) ведёт куда раньше.
- [ ] При `App-Version: 0` — баннеры не приходят (`appVersion <= caller's`).

### B. Новый функционал

- [ ] Rating-баннер пришёл с `type='rating'` — отрисовался как widget (с top-3), не как картинка.
- [ ] Title rating-баннера локализован: на ru → «Рейтинг», на en → «Rating», на tg → «Рейтинг», на uz → «Reyting».
- [ ] Тап по rating-баннеру открывает экран рейтинга.
- [ ] Старая мобилка (без обновления) получает rating-баннер с `type='rating'`, рендерит как обычный (без картинки), но клик ведёт на рейтинг через `link='app://Rating'`. Не падает.

### C. Бэк-управление (просим админа)

- [ ] Админ через `/api/v1/admin/banners` выключает баннер (`PATCH {is_active: false}`) — следующий запрос мобилки уже не возвращает его.
- [ ] Админ создаёт новый баннер — следующий запрос мобилки его возвращает.
- [ ] Админ ставит `target_user_type: "free"` — premium-юзер баннер не получает.
- [ ] Админ ставит `valid_from = завтра` — баннер не приходит сегодня; завтра приходит.

### D. Edge cases

- [ ] `localization = {}` (пустой объект) — фоллбек на `title`.
- [ ] Локаль `de` (нет в `localization`) — фоллбек на `title`.
- [ ] `link = "app://NewActionWeDontKnow"` — лог, без падения.
- [ ] Сетевой fail на `/dict/banners` — карусель пустая, не крашится.

---

## 10. Что бэкенд **гарантирует**

1. **JSON-форма списка не сломалась** — старые поля все на месте, тип не изменился. Старые клиенты продолжат работать.
2. **Новые поля опциональны** — все имеют `@Default` или `null`, парсятся без ошибок.
3. **Server-side фильтры** для `is_active`, `valid_from/to`, `target_user_type`, `platform`, `app_version`. Клиент в норме их не проверяет (но можно для подстраховки).
4. **`type='rating'` приходит ровно одна строка** на платформу (две — android+ios). При выключении админкой пропадает корректно.

---

## 11. Кэш и refresh policy ⚠️ ВАЖНО

Раньше баннеры можно было кэшировать долго — они менялись только релизом. **Теперь админ может в любой момент** через web-панель:
- выключить `UIBannerPremium` если у нас закончилась акция,
- запустить новый баннер кампании,
- поменять `link` на другую страницу,
- залить новую картинку поверх старого `file_name`.

Если мобилка покажет старый кэш сутки — пользователь увидит просроченную акцию или мёртвую ссылку.

### Рекомендуемая стратегия

| Когда обновлять | Действие |
|-----------------|----------|
| Холодный старт приложения (после splash) | Запросить список заново |
| Возврат на `HomePage` из другого таба / экрана | Если прошло > 5 минут с последнего fetch — перезапросить |
| `AppLifecycleState.resumed` (приложение из фона > 10 минут) | Перезапросить |
| Pull-to-refresh жест на главной | Перезапросить (опционально, желательно) |

Между запросами держать список в памяти / SWR-стиль (показывать кэш + параллельно обновлять). На диск кэшировать **не больше 30 минут** — это компромисс между traffic и оперативностью.

### Если бэкенд недоступен

Кэш в памяти/диске — fallback. Не показывать пустоту, не падать. Старая карусель лучше пустой. После восстановления сети — обновить.

### Невалидация картинок

Имя файла (`file_name`) на бэке детерминированное, **новая картинка = новый `file_name`**: бэк генерирует имя `<UTC-time>_<random6>_<base>.png` при upload. Старая картинка остаётся в R2 под старым именем. Это значит:
- если `file_name` тот же — картинка точно та же, можно кэшировать вечно (`Cache-Control: max-age=31536000, immutable` бэк уже выставляет на R2)
- если `file_name` новый — это другой файл, кэш по URL автоматически miss'ится

То есть **кэш по `file_name`/URL не нужно инвалидировать вручную**. Просто меняется `BannerDto.fileName` → следующий рендер берёт новый URL.

---

## 12. Сводка изменений в проекте

| Файл | Что менять |
|------|-----------|
| `lib/feature/home/data/banner_dto.dart` (или похожий) | Добавить новые поля, см. §8 |
| `lib/feature/home/presentation/widgets/home_banner_section.dart` | Удалить хардкод rating-слайда; switch по `type`; правильный resolve title; добавить refresh-policy (см. §11) |
| `lib/feature/home/presentation/widgets/banner_card.dart` (или похожий) | Поддержка `RatingBannerWidget` |
| `lib/core/utils/banner_link_router.dart` (или где сейчас `_handleBannerTap`) | Добавить новые `app://...` маршруты, см. §7 |
| `lib/feature/home/presentation/widgets/rating_banner_widget.dart` (новый) | Рендер top-3 + Title из localization |
| Repo / провайдер баннеров | Refresh on resume + 5-min staleness check |

Объём — ~3-4 часа с тестами и refresh-логикой.

---

## 13. Что уже готово на стороне админки (контекст)

Это не нужно делать мобильному разработчику — просто чтобы понимать что баннеры действительно меняются вживую и что админ работает через панель, не через ручные SQL-запросы:

- **Web UI**: https://api.vozhaomuz.com/admin/banners (логин/пароль), embedded Vue-приложение
- **Auth**: `POST /api/v1/admin/login` (username + password из env `ADMIN_LOGIN_USERNAME` / `ADMIN_LOGIN_PASSWORD`) → JWT на 30 дней
- **Image upload**: `POST /api/v1/admin/banners/upload` (multipart) → грузит в Cloudflare R2 (`vozhaomuz-bundles` bucket), возвращает `file_name` и публичный URL. PNG/JPG/WebP, до 5MB.
- **CDN**: `https://pub-d585333316fe4038b47813111c1609e0.r2.dev/banners/<имя>` — публичный URL для отрисовки в мобилке. Бэк уже выставляет `Cache-Control: public, max-age=31536000, immutable` — DefaultImageCache во Flutter сработает идеально.
- **Все `is_active` / `valid_from` / `target_user_type` фильтры** работают на сервере, мобилка получает уже отфильтрованный список.

---

## 14. Endpoints (только справочно, мобилке не нужно)

| Метод | URL | Описание |
|-------|-----|----------|
| `POST` | `/api/v1/admin/login` | Username/password → JWT (для админ-панели) |
| `GET` | `/api/v1/admin/banners` | Все баннеры включая выключенные (для админ-панели) |
| `GET` | `/api/v1/admin/banners/:id` | Один баннер |
| `POST` | `/api/v1/admin/banners` | Создать |
| `PATCH` | `/api/v1/admin/banners/:id` | Частичное обновление (тык по toggle is_active = одно PATCH) |
| `DELETE` | `/api/v1/admin/banners/:id` | Hard-delete (для скрытия используется PATCH is_active=false) |
| `POST` | `/api/v1/admin/banners/upload` | Загрузить картинку в R2 |

Все `/admin/*` (кроме `/login`) требуют `Authorization: Bearer <jwt>` + `user_id ∈ ADMIN_USER_IDS`.

---

## Контакт

Если новый `app://...` маршрут не описан в §7, или нужна поддержка дополнительного типа баннера — пиши. Бэк готов добавлять, мобилке нужно будет только раскидать в `_handleBannerTap`.
