# 🔗 ТЗ: Deep Link — Backend

## Проблема

Сейчас пользователь отправляет пригласительную ссылку в Telegram:

```
https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=534825
```

Когда кто-то нажимает на ссылку — **приложение не открывается**. Вместо этого:
- Android через Telegram → открывается в Chrome, затем возвращает в Telegram → приложение не открывается
- iOS → открывается в Safari, приложение не открывается

## Причина

1. **Android**: Для верификации App Links Google требует файл:
   ```
   https://api.vozhaomuz.com/.well-known/assetlinks.json
   ```
   Без этого файла `autoVerify="true"` не работает — приложение не активируется.

2. **iOS**: Для Universal Links Apple требует файл:
   ```
   https://api.vozhaomuz.com/.well-known/apple-app-site-association
   ```
   Без этого файла iOS открывает ссылку в Safari.

3. **Telegram**: Открывает ссылки во **встроенном WebView** — даже когда оба файла опубликованы. Поэтому нужна landing-страница (специальная HTML-страница).

---

## Что нужно сделать (Backend)

### 1️⃣ Публикация `assetlinks.json` (Android App Links)

**URL**: `https://api.vozhaomuz.com/.well-known/assetlinks.json`

**Content-Type**: `application/json`

**Содержимое**:
```json
[
  {
    "relation": [
      "delegate_permission/common.handle_all_urls"
    ],
    "target": {
      "namespace": "android_app",
      "package_name": "com.vozhaomuz",
      "sha256_cert_fingerprints": [
        "XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
      ]
    }
  }
]
```

**Требования**:
- Правильный Content-Type: `application/json`
- HTTPS с настоящим сертификатом (не self-signed)
- Без редиректов (3xx)
- Без паролей и authentication — файл должен быть публичным

**Откуда взять SHA-256 fingerprint?**
- Production signing key из Google Play Console:
  - Play Console → App → **Setup → App integrity** → "App signing key certificate" → SHA-256
- Также добавьте debug key (для тестирования):
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
  ```
  Скопируйте SHA-256

**Проверка**:
```bash
curl -i https://api.vozhaomuz.com/.well-known/assetlinks.json
```
- Должен вернуть HTTP 200
- Content-Type: application/json
- Body: JSON array

Также через Google verifier:
```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://api.vozhaomuz.com&relation=delegate_permission/common.handle_all_urls
```

---

### 2️⃣ Публикация `apple-app-site-association` (iOS Universal Links)

**URL**: `https://api.vozhaomuz.com/.well-known/apple-app-site-association`

**Content-Type**: `application/json` (**БЕЗ** `.json` расширения в URL!)

**Содержимое**:
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.vozhaomuz",
        "paths": [
          "/api/v1/deeplink*",
          "/api/v1/deeplink/*"
        ]
      }
    ]
  }
}
```

**Требования**:
- URL **без** `.json` расширения
- Content-Type: `application/json`
- HTTPS с настоящим сертификатом
- Без редиректов
- Публичный, без авторизации

**Откуда взять `TEAM_ID`?**
- Apple Developer Account → **Membership** → Team ID (10 символов: буквы и цифры)
- `com.vozhaomuz` — Bundle Identifier приложения

**Проверка**:
```bash
curl -i https://api.vozhaomuz.com/.well-known/apple-app-site-association
```
- Должен вернуть HTTP 200
- Content-Type: application/json

---

### 3️⃣ Landing-страница на `/api/v1/deeplink`

**URL**: `https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=XXXXX`

**Сейчас**: этот endpoint предположительно возвращает JSON.

**Нужно**: возвращать специальную HTML-страницу, которая:

1. Если открыта на **мобильном устройстве** (User-Agent содержит `Android`, `iPhone`, `iPad`):
   - Сначала попытается открыть приложение через **custom scheme** `vozhaomuz://battle?room_id=XXX`
   - Если через 2 секунды приложение не открылось → редирект в Play Store / App Store
   - Также показывает кнопку "Open in VozhaOmuz" (для Telegram WebView)

2. Если открыта на **компьютере (Desktop)**:
   - Показывает HTML со ссылками на Play Store / App Store
   - QR-код с custom scheme

**Пример HTML-страницы** (которую нужно отдавать):

```html
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VozhaOmuz - Присоединиться к соревнованию</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; text-align: center; padding: 40px 20px; background: #F2F7FF; }
    .logo { width: 120px; height: 120px; margin: 0 auto 24px; }
    h1 { color: #1D2939; font-size: 24px; margin-bottom: 8px; }
    p { color: #667085; font-size: 16px; margin-bottom: 32px; }
    .btn { display: inline-block; background: #2E90FA; color: white; padding: 14px 32px; border-radius: 14px; text-decoration: none; font-weight: 600; font-size: 16px; margin: 8px; }
    .btn-store { background: #1D2939; }
  </style>
</head>
<body>
  <img src="/logo.png" class="logo" alt="VozhaOmuz">
  <h1>Присоединиться к Соревнованию</h1>
  <p>Код комнаты: <strong id="roomId"></strong></p>

  <!-- Основная кнопка: откроет приложение -->
  <a id="openApp" class="btn" href="#">Открыть VozhaOmuz</a>

  <!-- Ссылки на магазины приложений -->
  <div style="margin-top: 40px;">
    <a href="https://play.google.com/store/apps/details?id=com.vozhaomuz" class="btn btn-store">Google Play</a>
    <a href="https://apps.apple.com/app/vozhaomuz/id0000000000" class="btn btn-store">App Store</a>
  </div>

  <script>
    // Получаем room_id из query string
    const params = new URLSearchParams(window.location.search);
    const roomId = params.get('room_id') || '';
    const page = params.get('page') || 'battle';

    document.getElementById('roomId').textContent = roomId;

    // Custom scheme link
    const customLink = `vozhaomuz://${page}?room_id=${roomId}`;
    document.getElementById('openApp').href = customLink;

    // Пробуем автоматически открыть приложение
    // (если не сработает — пользователь нажмёт кнопку)
    const ua = navigator.userAgent.toLowerCase();
    const isAndroid = ua.includes('android');
    const isIOS = /iphone|ipad|ipod/.test(ua);

    if (isAndroid || isIOS) {
      // Одна автоматическая попытка
      setTimeout(() => {
        window.location.href = customLink;
      }, 500);

      // Если через 3 секунды эта страница всё ещё видна — приложение не установлено
      setTimeout(() => {
        if (isAndroid) {
          window.location.href = 'https://play.google.com/store/apps/details?id=com.vozhaomuz';
        } else if (isIOS) {
          window.location.href = 'https://apps.apple.com/app/vozhaomuz/id0000000000';
        }
      }, 3000);
    }
  </script>
</body>
</html>
```

**После этого**, даже в Telegram WebView пользователь увидит кнопку "Открыть VozhaOmuz" — нажав на неё, приложение откроется.

---

## Чек-лист публикации

Выполните всё и сообщите Client-разработчику:

- [ ] `/.well-known/assetlinks.json` опубликован (Android)
- [ ] `/.well-known/apple-app-site-association` опубликован (iOS, **без** .json расширения)
- [ ] Оба файла отдаются по HTTPS с Content-Type: application/json
- [ ] `https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=X` возвращает HTML landing page (не JSON)
- [ ] Landing page протестирована с custom scheme `vozhaomuz://battle?room_id=X` (Android + iOS)
- [ ] Store fallback-и работают (Play Store + App Store)

---

## Со стороны Client

Client уже готов:
- ✅ AndroidManifest: intent-filter для https + vozhaomuz scheme
- ✅ iOS Info.plist: FlutterDeepLinkingEnabled + CFBundleURLSchemes
- ✅ iOS Entitlements: associated-domains
- ✅ DeepLinkService принимает оба формата URL
- ✅ Share text включает custom scheme как fallback

**Важно**: Схемы Client:
```
vozhaomuz://battle?room_id=XXXXX          # custom scheme (fallback)
https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=XXXXX  # universal link
```

Обе ссылки должны вести на одно и то же действие (открытие battle room с указанным кодом).

---

## Сценарии работы (после backend fix)

### Сценарий 1: Telegram → Android
1. Пользователь нажимает на ссылку в Telegram
2. Telegram → Chrome (напрямую или сначала через WebView)
3. Chrome → проверяет `https://api.vozhaomuz.com/.well-known/assetlinks.json` → fingerprint верный
4. Android → открывает приложение → DeepLinkService читает из query `page=battle&room_id=X` → страница Join заполняется кодом
5. ✅

### Сценарий 2: Обязательно используется Telegram WebView
1. Тап на ссылку в Telegram → открывается внутренний Telegram WebView
2. Показывается HTML landing page
3. JavaScript fire-ит `vozhaomuz://battle?room_id=X`
4. Android → открывает приложение (custom scheme не требует верификации)
5. ✅

### Сценарий 3: Приложение не установлено
1. Тап → landing page
2. JavaScript fire-ит custom scheme
3. Приложения нет → через 3 секунды JavaScript редиректит в Play Store/App Store
4. ✅

---

## Контакты

Если есть вопросы — задавайте в этом канале или через Client-разработчика.
Client-сторона уже подготовлена и протестирована. После публикации файлов, ссылки заработают без каких-либо изменений на стороне клиента.
