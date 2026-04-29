# VozhaOmuz Deep Link Landing

Landing page + verification files for VozhaOmuz battle invite deep links.

## Structure

```
deeplink-landing/
├── index.html                            ← Landing page (Android + iOS + Desktop)
└── .well-known/
    ├── assetlinks.json                   ← Android App Links verification
    └── apple-app-site-association        ← iOS Universal Links verification (no .json extension!)
```

---

## Setup instructions (GitHub Pages)

### 1. Get the signing fingerprints

**Production SHA-256** (from Google Play Console):
1. Go to Play Console → your app → **Setup → App integrity**
2. Copy the SHA-256 from "App signing key certificate"

**Debug SHA-256** (optional, for testing):
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```
Copy the `SHA256:` line (without the `SHA256:` prefix).

**iOS Team ID**:
1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Click **Membership details**
3. Copy the Team ID (10 chars, letters + numbers)

### 2. Fill in the placeholders

Edit `.well-known/assetlinks.json` and replace:
- `REPLACE_WITH_YOUR_SHA256_RELEASE_FINGERPRINT` → production SHA-256
- `REPLACE_WITH_YOUR_SHA256_DEBUG_FINGERPRINT` → debug SHA-256 (or remove this line if not needed)

Edit `.well-known/apple-app-site-association` and replace:
- `REPLACE_WITH_TEAM_ID` → your Apple Team ID

### 3. Create GitHub Pages repo

```bash
# Create a new repo (public) on GitHub called "vozhaomuz-landing"
# Clone it locally
git clone https://github.com/YOUR_USERNAME/vozhaomuz-landing.git
cd vozhaomuz-landing

# Copy these files in
cp -r /path/to/vozha/deeplink-landing/. .

# Commit and push
git add .
git commit -m "Initial landing page + deep link verification"
git push
```

### 4. Enable GitHub Pages

1. Repo → **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: `main`, folder: `/` (root)
4. Save

After ~30 seconds, your landing page will be live at:
```
https://YOUR_USERNAME.github.io/vozhaomuz-landing/
```

### 5. Verify the files are served correctly

```bash
# Landing page
curl -i https://YOUR_USERNAME.github.io/vozhaomuz-landing/?room_id=123456

# Android verification file
curl -i https://YOUR_USERNAME.github.io/vozhaomuz-landing/.well-known/assetlinks.json

# iOS verification file (note: no .json extension!)
curl -i https://YOUR_USERNAME.github.io/vozhaomuz-landing/.well-known/apple-app-site-association
```

Both `.well-known/` files should return:
- `HTTP/2 200`
- `content-type: application/json; charset=utf-8` (or similar)

If you see `404`, GitHub Pages may need a `.nojekyll` file to serve `.well-known` — add it:
```bash
touch .nojekyll
git add .nojekyll && git commit -m "Allow .well-known" && git push
```

### 6. Test on a real device

**Android**:
1. Install the app on an Android phone
2. Share this URL with yourself (any messenger): `https://YOUR_USERNAME.github.io/vozhaomuz-landing/?room_id=123456`
3. Tap the link
4. Either Android opens the app directly (if App Links verified), OR the landing page loads and auto-redirects via `vozhaomuz://` custom scheme

**iOS**:
Same process, same expected result.

### 7. Update the app's share link (see next section)

Once the URL is live and working, update the app's share logic to use the new URL. See `app-update.md` below.

---

## Updating the app's share link

In `lib/feature/battle/presentation/screens/waiting_opponent_page.dart`, the `_shareRoomCode` method currently uses:

```dart
final deeplink =
    '${ApiConstants.baseUrl}${ApiConstants.apiVersion}/deeplink?page=battle&room_id=$roomId';
```

Change it to your GitHub Pages URL:

```dart
final deeplink =
    'https://YOUR_USERNAME.github.io/vozhaomuz-landing/?page=battle&room_id=$roomId';
```

Then update `AndroidManifest.xml` — the existing intent-filter points to `api.vozhaomuz.com`. Either add a second intent-filter for `YOUR_USERNAME.github.io` or replace the host:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data
        android:scheme="https"
        android:host="YOUR_USERNAME.github.io"
        android:pathPrefix="/vozhaomuz-landing"/>
</intent-filter>
```

And `ios/Runner/Runner.entitlements` — update `associated-domains`:

```xml
<array>
    <string>applinks:YOUR_USERNAME.github.io</string>
</array>
```

Rebuild the APK and test.

---

## Verification

**Google Digital Asset Links checker**:
```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://YOUR_USERNAME.github.io&relation=delegate_permission/common.handle_all_urls
```

**Apple Universal Link checker** (real device only; simulator doesn't work):
1. Send yourself the URL in Notes or Messages
2. Long-press the link
3. If you see "Open in VozhaOmuz" at the top of the menu → ✅ verified
4. If you only see "Open in Safari" → verification failed, check Team ID + AASA file

---

## Why this setup works

- `assetlinks.json` tells Android: "This URL belongs to `com.vozhaomuz` app, you can open it directly."
- `apple-app-site-association` tells iOS: same for `TEAM_ID.com.vozhaomuz`.
- `index.html` is a fallback: if the app isn't installed OR if the user opens the link from a browser that doesn't honor universal links (e.g. Telegram's in-app browser), the page renders and tries the custom scheme `vozhaomuz://`, then falls back to the app store.

All three layers are needed for a robust deep link experience across Android, iOS, and every messenger.
