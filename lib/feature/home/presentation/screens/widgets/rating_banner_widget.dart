import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';
import 'package:vozhaomuz/feature/home/data/models/banner_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_3_users_day_provider.dart';

/// Special banner type — `type='rating'` from the backend renders as
/// the top-3 leaderboard slide (cloud + trophy art) instead of a plain
/// image. Title comes from `banner.localization` so admin can rename
/// per locale; the click target lives on the parent's tap handler.
class RatingBannerWidget extends ConsumerWidget {
  final BannerDto banner;
  const RatingBannerWidget({super.key, required this.banner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = context.locale.languageCode;
    final title = banner.resolvedTitle(locale);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/banner_bg.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: -8,
                right: -65,
                child: Image.asset(
                  'assets/images/Ellipse 1199.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 1,
                child: Image.asset(
                  'assets/images/banner_cloud.png',
                  fit: BoxFit.cover,
                  height: 200,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title.isNotEmpty ? title : 'rating'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _Top3UsersList(),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/banner (3).png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Top3UsersList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topUsersAsync = ref.watch(top3UsersDayProvider);
    return topUsersAsync.when(
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return Column(
          children: users.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final avatarUrl = user.avatarUrl;
            final isUserPremium = user.userType == 'pre';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isUserPremium
                                ? const Color(0xFFF9A628)
                                : Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                          image: DecorationImage(
                            image:
                                (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? CachedNetworkImageProvider(
                                    buildAvatarUrl(avatarUrl),
                                  )
                                : const AssetImage(
                                        'assets/images/UIHome/usercircle.png',
                                      )
                                      as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (isUserPremium)
                        Positioned(
                          top: -15,
                          right: 0,
                          left: -5,
                          child: Center(
                            child: Image.asset(
                              'assets/images/group_2.png',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'n_words'.tr(args: ['${user.count ?? 0}']),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
