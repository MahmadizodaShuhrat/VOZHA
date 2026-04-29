import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_3_users_day_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/all_top_vozhaomuzes.dart';
import 'package:vozhaomuz/feature/rating/presentation/widgets/vozhaomuzes_information.dart';

class TopVozhaomuz extends HookConsumerWidget {
  const TopVozhaomuz({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topUsersState = ref.watch(top3UsersDayProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
      // Hard-coded 350 pt was pushing content off-screen on iPhone SE
      // (667 pt tall, minus safe areas and stat row), and felt cramped
      // on tablets. Using min-constraint with content-driven height
      // lets the card grow for Cyrillic names (which wrap under big
      // OS font scale) without blowing out the layout.
      constraints: const BoxConstraints(minHeight: 350),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 4),
        ),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Топ 30 - ВожаОмуз',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTop30Vozhaomuz(),
                    ),
                  );
                },
                child: Text(
                  'all'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.lightBlue,
                  ),
                ),
              ),
            ],
          ),
          topUsersState.when(
            data: (users) {
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'Маълумот нест',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                );
              }
              return Column(
                children: users.asMap().entries.map((entry) {
                  final index = entry.key;
                  final user = entry.value;
                  return Column(
                    children: [
                      VozhaomuzesInformation(user: user, index: index),
                      if (index < users.length - 1) const Gap(20),
                    ],
                  );
                }).toList(),
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Shimmer.fromColors(
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
            ),
            error: (err, _) => const Center(child: Text('Ошибка загрузки')),
          ),
        ],
      ),
    );
  }
}
