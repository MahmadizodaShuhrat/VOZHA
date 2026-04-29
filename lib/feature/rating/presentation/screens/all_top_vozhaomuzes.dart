import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_30_users_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/vozhaomuzes_information.dart';

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryRatingNotifier, String>(
      SelectedCategoryRatingNotifier.new,
    );

class SelectedCategoryRatingNotifier extends Notifier<String> {
  @override
  String build() => 'day';
  void set(String value) => state = value;
}

final isLoadingProvider = NotifierProvider<IsLoadingNotifier, bool>(
  IsLoadingNotifier.new,
);

class IsLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class AllTop30Vozhaomuz extends HookConsumerWidget {
  const AllTop30Vozhaomuz({super.key});

  /// Period keys and their translation keys
  static const _periods = [
    {'period': 'day', 'label': 'period_day'},
    {'period': 'week', 'label': 'period_week'},
    {'period': 'month', 'label': 'period_month'},
    {'period': 'year', 'label': 'period_year'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) => ref.read(top30UsersProvider.notifier).fetchUsers('day'),
      );
    }, []);

    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final usersAsync = ref.watch(top30UsersProvider);
    final selectedList = usersAsync.when(
      data: (users) => users,
      loading: () => [],
      error: (_, __) => [],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      appBar: AppBar(
        surfaceTintColor: const Color(0xFFF5FAFF),
        centerTitle: true,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: const Icon(Icons.keyboard_arrow_left_rounded, size: 50),
        ),
        title: Text("rating".tr(), style: const TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(left: 15),
              alignment: Alignment.centerLeft,
              child: Text(
                'top_30_title'.tr(),
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                ),
              ),
            ),
            const Gap(20),
            Wrap(
              spacing: 15,
              runSpacing: 8,
              children: _periods.map((entry) {
                final period = entry['period']!;
                final labelKey = entry['label']!;
                final isSelected = selectedCategory == period;

                return GestureDetector(
                  onTap: () async {
                    ref.read(isLoadingProvider.notifier).set(true);
                    ref.read(selectedCategoryProvider.notifier).set(period);
                    await ref
                        .read(top30UsersProvider.notifier)
                        .fetchUsers(period);
                    ref.read(isLoadingProvider.notifier).set(false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2E90FA)
                          : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      labelKey.tr(),
                      style: AppTextStyles.whiteTextStyle.copyWith(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Gap(20),
            isLoading || usersAsync.isLoading
                ? Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      child: ListView.separated(
                        itemCount: 8,
                        separatorBuilder: (_, __) => const Divider(height: 30),
                        itemBuilder: (_, __) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 90,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                        top: 10,
                        left: 15,
                        right: 15,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final item = VozhaomuzesInformation(
                            user: selectedList[index],
                            index: index,
                          );

                          return index == 0
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: item,
                                )
                              : item;
                        },

                        separatorBuilder: (context, index) {
                          return const Divider(height: 30);
                        },
                        itemCount: selectedList.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
