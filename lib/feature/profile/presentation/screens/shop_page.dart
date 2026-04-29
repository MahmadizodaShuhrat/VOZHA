import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/shop_detail_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/shop_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

List images = ["assets/images/banner.png"];

class ShopPage extends HookConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedShopCategoryProvider);
    final filteredItemsAsync = ref.watch(filteredShopItemsProvider);
    final allItemsAsync = ref.watch(shopItemsProvider);
    final currentIndex = useState(0);
    final lc = context.locale.languageCode;
    final langCode = lc == 'tg' ? 'tj' : lc;

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/vozhaomuz_background.png'),
                fit: BoxFit.cover,
              ),
              color: Colors.blue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade700, width: 4),
              ),
              gradient: LinearGradient(
                colors: [
                  const Color.fromARGB(255, 17, 85, 152),
                  const Color.fromARGB(255, 33, 89, 243),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(width: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/vozha_shop.png',
                        height: 45,
                        width: 40,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Vozha-Shop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Banner carousel
          CarouselSlider.builder(
            itemCount: images.length,
            itemBuilder: (context, index, realIndex) {
              return Container(
                padding: EdgeInsets.only(top: 30),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Image.asset(images[index], fit: BoxFit.cover),
              );
            },
            options: CarouselOptions(
              height: 160,
              viewportFraction: 0.99,
              enlargeCenterPage: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 30),
              onPageChanged: (index, reason) {
                currentIndex.value = index;
              },
            ),
          ),

          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              return Padding(
                padding: const EdgeInsets.all(3.0),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: i == currentIndex.value
                      ? Colors.blue
                      : const Color.fromARGB(255, 178, 218, 245),
                ),
              );
            }),
          ),

          // Categories - built from server data
          allItemsAsync.when(
            data: (allItems) {
              // Extract unique categories
              final categoriesMap = <String, String>{'all': 'Все'};
              for (final item in allItems) {
                categoriesMap[item.category.id] = item.category
                    .getLocalizedName(langCode);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: categoriesMap.entries.map((entry) {
                    final key = entry.key;
                    final label = entry.value;
                    final isSelected = selectedCategory == key;

                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(selectedShopCategoryProvider.notifier)
                            .set(key);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 70,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Items grid
          Expanded(
            child: filteredItemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Нет товаров'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.60,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final imageUrl = item.getFirstPhotoUrl(
                      ApiConstants.baseUrl,
                      ApiConstants.storeFiles,
                    );

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 15,
                            ),
                            alignment: Alignment.center,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.grey.shade200,
                            ),
                            child: Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/coin.png',
                                width: 15,
                                height: 15,
                              ),
                              const Gap(5),
                              Text(
                                '${item.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item.getLocalizedName(langCode),
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MyButton(
                            padding: EdgeInsets.zero,
                            buttonColor: Colors.blue,
                            backButtonColor: Colors.blue.shade600,
                            width: double.infinity,
                            height: 23,
                            borderRadius: 5,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(selectedShopItemProvider.notifier)
                                  .set(item);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ShopDetailPage(),
                                ),
                              );
                            },
                            child: Text(
                              'In_detail'.tr(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.60,
                ),
                itemBuilder: (_, __) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 120,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text('Ошибка загрузки: $error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(shopItemsProvider),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
