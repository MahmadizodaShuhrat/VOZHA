# ТЗ: Очистка legacy Unity-баннеров

**Дата:** 2026-05-03
**Приоритет:** средний — мобилка уже скрывает их client-side, но в БД остаётся мусор.

---

## Проблема

В таблице `banners` есть **7 записей**, чей `file_name` указывает на R2-объекты в формате **Unity AssetBundle (`UnityFS`)**, а не на изображения. Flutter-клиент такие файлы отрендерить не может: декодер падает с `Invalid image data`.

Подтверждено 2026-05-03:
```bash
$ curl https://pub-d585333316fe4038b47813111c1609e0.r2.dev/banners/banner_battle_android | head -c 16
UnityFS........5.x.x          # ← magic bytes Unity 2022.3.52f1
```

Файл весит 172 KB, отдаётся как `application/octet-stream`, никаким клиентом, кроме Unity-плеера, не открывается.

---

## Список проблемных записей

| `id` | `title` | `file_name` |
|------|---------|-------------|
| 1 | UIBannerDiscount | `files/banners/banner_premium_discount_android` |
| 3 | UIBannerInstagram | `files/banners/banner_instagram_android` |
| 5 | UIBannerInviteFriend | `files/banners/banner_invite_friend_android` |
| 7 | UIBannerBattle | `files/banners/banner_battle_android` |
| 9 | UIEnglish24 | `files/banners/banner_english24_android` |
| 11 | UIWithNewUsers | `files/banners/banner_with_new_users_android` |
| 13 | UIBannerPremium | `files/banners/banner_premium_android` |

Общее: `file_name` без расширения, в R2 лежит `UnityFS`-бандл.

Запись `#18` (`Custom design 03.05.2026`, file_name заканчивается на `.png`) работает корректно — её **не трогать**.

---

## Что нужно сделать

Один из двух вариантов на каждую запись:

### Вариант А — сохранить баннер, заменить файл

1. Достать оригинальную PNG-картинку (есть в Unity-проекте, в репозитории мобилки или у дизайнера).
2. Загрузить её в R2 через админ-панель (`POST /api/v1/admin/banners/upload`).
3. Обновить `file_name` записи на новый ключ с расширением `.png`:
   ```sql
   UPDATE banners
   SET file_name = 'files/banners/banner_battle_android_v2.png'
   WHERE id = 7;
   ```

### Вариант Б — удалить запись

```sql
UPDATE banners SET is_active = FALSE WHERE id IN (1, 3, 5, 7, 9, 11, 13);
-- или hard-delete:
DELETE FROM banners WHERE id IN (1, 3, 5, 7, 9, 11, 13);
```

Если контента у вас уже нет — выбирайте Б.

---

## Проверка

После миграции:

```bash
curl -H "Authorization: Bearer <jwt>" \
     -H "App-Platform: android" \
     -H "App-Version: 2.61" \
     https://api.vozhaomuz.com/api/v1/dict/banners \
     | jq '.[] | select(.type == "image") | .file_name'
```

Каждая строка должна заканчиваться на `.png` / `.jpg` / `.webp` / `.gif`. Если есть запись без расширения — мобилка её игнорирует.

---

## Что мобилка делает сейчас

В `banner_repository.dart` добавлен defensive-фильтр: image-баннеры с `file_name` без узнаваемого расширения отбрасываются на клиенте, чтобы карусель не показывала пустые синие плашки. Это **временный костыль** — после очистки данных фильтр можно убрать (но не критично, оставить тоже безопасно).

Лог при загрузке:
```
⏭️ Skip banner #1 "UIBannerDiscount" — file_name has no image extension (likely a Unity AssetBundle)
```

---

## Контакты

Вопросы — в рабочий чат. Если поднимете PNG-замены, дайте знать — мобилка ничего дополнительно делать не должна, изменения подхватятся при следующем `GET /dict/banners`.
