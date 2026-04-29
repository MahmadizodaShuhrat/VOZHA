import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/feature/profile/business/shop_repository.dart';
import 'package:vozhaomuz/feature/profile/data/model/shop_item.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/shop_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/learning_streak_provider.dart';

class ShopDetailPage extends ConsumerStatefulWidget {
  const ShopDetailPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends ConsumerState<ShopDetailPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShopItem? item = ref.watch(selectedShopItemProvider);
    final lc = context.locale.languageCode;
    final langCode = lc == 'tg' ? 'tj' : lc;

    final List<String> photoUrls =
        item?.getPhotoUrls(ApiConstants.baseUrl, ApiConstants.storeFiles) ?? [];

    // Server is the source of truth for the streak gate, but we mirror it
    // client-side so the button shows "need N-day streak" instead of
    // letting the user submit and read the rejection.
    final currentStreak =
        ref.watch(learningStreakProvider).asData?.value?.currentStreak ?? 0;
    final requiredStreak = item?.strikes ?? 0;
    final streakLocked =
        requiredStreak > 0 && currentStreak < requiredStreak;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'shop_details'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 200),
            child: Column(
              children: [
                SizedBox(
                  height: kToolbarHeight + MediaQuery.of(context).padding.top,
                ),

                // Photo carousel
                if (photoUrls.isNotEmpty)
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: photoUrls.length,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemBuilder: (_, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: photoUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                if (photoUrls.length > 1) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      photoUrls.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 12 : 8,
                        height: _currentPage == index ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.blue
                              : Colors.blue.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item?.getLocalizedName(langCode) ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Price
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/coin.png',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item?.price ?? 0}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((item?.strikes ?? 0) > 0) ...[
                        const SizedBox(width: 16),
                        const Text('🔥', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 4),
                        Text(
                          '${item!.strikes}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B00),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (streakLocked) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'shop_streak_required'.tr(
                        namedArgs: {
                          'need': '$requiredStreak',
                          'have': '$currentStreak',
                        },
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFF79009),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Description
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'shop_product_description'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item?.getLocalizedDescription(langCode) ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Phone number input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      fillColor: const Color(0xFFF5F5F5),
                      labelText: 'shop_phone_number'.tr(),
                      hintText: '+992 XXX XX XX XX',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Description input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      fillColor: const Color(0xFFF5F5F5),
                      labelText: 'shop_delivery_address'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom buy bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'shop_product_cost'.tr(),
                        style: const TextStyle(fontSize: 16),
                      ),
                      Image.asset(
                        'assets/images/coin.png',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item?.price ?? 0}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((item?.strikes ?? 0) > 0) ...[
                        const SizedBox(width: 12),
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '${item!.strikes}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B00),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_isOrdering || streakLocked)
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();

                              if (_phoneController.text.length < 9) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('shop_enter_phone'.tr()),
                                  ),
                                );
                                return;
                              }
                              if (_descriptionController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'shop_enter_description'.tr(),
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() => _isOrdering = true);

                              final repository = ref.read(
                                shopRepositoryProvider,
                              );
                              final result = await repository.orderItem(
                                itemId: int.tryParse(item?.id ?? '0') ?? 0,
                                phone: _phoneController.text,
                                description: _descriptionController.text,
                              );

                              if (!mounted) return;
                              setState(() => _isOrdering = false);

                              if (result.success) {
                                final msg = result.orderId != null
                                    ? 'shop_order_success_with_id'.tr(
                                        namedArgs: {
                                          'id': result.orderId.toString(),
                                        },
                                      )
                                    : 'shop_order_success'.tr();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              } else if (result.errorCode ==
                                  'streak_requirement_not_met') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'shop_streak_required'.tr(
                                        namedArgs: {
                                          'need':
                                              '${result.requiredStreak ?? requiredStreak}',
                                          'have':
                                              '${result.currentStreak ?? currentStreak}',
                                        },
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFF79009),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('shop_not_enough_coins'.tr()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: _isOrdering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              streakLocked
                                  ? 'shop_streak_button_locked'.tr(
                                      namedArgs: {
                                        'need': '$requiredStreak',
                                      },
                                    )
                                  : 'shop_buy_product'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
