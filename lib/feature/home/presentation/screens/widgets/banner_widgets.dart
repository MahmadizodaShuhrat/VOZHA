import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';

/// Renders a `type='image'` banner straight from the backend payload —
/// the artwork is whatever URL the admin uploaded into `file_name`,
/// the title comes from `banner.localization` (or the legacy `title`
/// field as fallback). No hardcoded keys, no bundled gradient designs:
/// the admin owns the visuals end-to-end (TZ §3 / §10.6).
///
/// Falls back to a neutral gradient placeholder if the URL is missing
/// or fails to load — keeps the carousel from showing a broken-image
/// icon when the CDN is briefly unavailable.
class BannerWidgetBuilder {
  BannerWidgetBuilder._();

  static Widget buildBanner(BannerDto banner) => _BannerCard(banner: banner);
}

class _BannerCard extends StatelessWidget {
  final BannerDto banner;
  const _BannerCard({required this.banner});

  /// Resolve the user-facing title: per-locale string from
  /// `banner.localization` if the admin set one, otherwise the legacy
  /// `title` field. Empty title is fine — we just hide the overlay.
  String _resolveTitle(BuildContext context) {
    final locale = context.locale.languageCode;
    final localized = banner.resolvedTitle(locale);
    // Treat the raw `title` (which is often a key like
    // `UIBannerPremium`) as a "no real title" signal — only show
    // overlay text when it's a meaningful localized string.
    if (localized.isEmpty || localized == banner.title) return '';
    return localized;
  }

  @override
  Widget build(BuildContext context) {
    final title = _resolveTitle(context);
    // Backend ships either a full URL or a relative path like
    // `files/banners/<name>.png`. `buildBannerUrl` normalizes both into
    // an absolute URL CachedNetworkImage can fetch.
    final imageUrl = buildBannerUrl(banner.fileName);
    debugPrint(
      '🖼️ Banner #${banner.id} render: '
      'fileName="${banner.fileName}" → url="$imageUrl"',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => const _Placeholder(),
                errorWidget: (_, url, error) {
                  debugPrint(
                    '❌ Banner #${banner.id} image load FAILED:\n'
                    '   url=$url\n'
                    '   error=$error',
                  );
                  return const _Placeholder();
                },
              )
            else
              const _Placeholder(),
            if (title.isNotEmpty) _TitleOverlay(title: title),
          ],
        ),
      ),
    );
  }
}

/// Light gradient shown while the network image loads or as a fallback
/// when the URL is missing/broken. Keeps the carousel from flashing a
/// broken-image glyph during cold starts on slow networks.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// Soft gradient at the bottom of the card so the title stays readable
/// over busy artwork. Only rendered when `banner.localization` actually
/// produced a usable per-locale title — for image-only banners we keep
/// the artwork clean.
class _TitleOverlay extends StatelessWidget {
  final String title;
  const _TitleOverlay({required this.title});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
          ),
        ),
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
