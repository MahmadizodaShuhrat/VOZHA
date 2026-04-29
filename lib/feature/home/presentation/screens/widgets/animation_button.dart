import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vozhaomuz/feature/games/presentation/providers/word_repetition_provider.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/match_words.dart';
import 'package:vozhaomuz/feature/games/presentation/screens/repeat_flow_page.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/categories_flutter_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/category_setting.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';

class HomeBattonsWidget extends ConsumerStatefulWidget {
  final String wordName;
  final String image;
  final Color buttonColor;
  final Color borderColor;
  const HomeBattonsWidget({
    super.key,
    required this.wordName,
    required this.image,
    required this.buttonColor,
    required this.borderColor,
  });

  @override
  ConsumerState<HomeBattonsWidget> createState() => _HomeBattonsWidgetState();
}

class _HomeBattonsWidgetState extends ConsumerState<HomeBattonsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool button2 = false;

  @override
  void initState() {
    super.initState();

    // Загружаем прогресс с бэкенда для обновления repeat count
    Future(() {
      ref.read(progressProvider.notifier).fetchProgressFromBackend();
    });

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _animation = Tween(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repeatState = ref.watch(repeatStateProvider);

    // Пока категории/прогресс загружаются — показываем shimmer,
    // чтобы кнопка не мигала между "Учить слова" и "Такрор"
    if (!repeatState.isReady) {
      return Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.only(bottom: 10),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      );
    }

    final isRepeat = repeatState.needsRepeat;

    // Динамические цвета и текст в зависимости от режима
    final btnColor = isRepeat ? const Color(0xFFFCD60D) : widget.buttonColor;
    final brdColor = isRepeat ? const Color(0xFFEAB308) : widget.borderColor;
    final repeatCount = repeatState.repeatCount;
    final label = isRepeat ? "${"Repeat".tr()} $repeatCount" : widget.wordName;

    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: EdgeInsets.only(bottom: 10),
        child: MyButton(
          height: 62,
          borderRadius: 22.0,
          padding: EdgeInsets.only(left: 25),
          backButtonColor: brdColor,
          buttonColor: btnColor,
          onPressed: () async {
            HapticFeedback.lightImpact();
            button2 = true;
            HapticFeedback.mediumImpact();

            // Energy gate — both "learn" and "repeat" start a game session.
            // Non-premium users with balance < 1 get the paywall instead.
            final canPlay = ref.read(energyProvider.notifier).canPlay();
            if (!canPlay) {
              if (context.mounted) {
                await showEnergyPaywallDialog(context);
              }
              return;
            }

            if (isRepeat) {
              // Навигация на страницу повторения
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RepeatFlowPage()),
              );
            } else {
              // Check if any valid category is selected
              final selectedIds = ref.read(progressProvider).selectedIds;
              final allCategories =
                  ref.read(categoriesFlutterProvider).value ?? [];
              final validCategoryIds = allCategories.map((c) => c.id).toSet();
              final hasValidSelection = selectedIds.any(
                (id) => validCategoryIds.contains(id),
              );
              if (!hasValidSelection) {
                // No selection or all selected IDs are invalid — open settings
                final user = ref.read(getProfileInfoProvider).value;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategorySetting(user: user),
                    ),
                  ).then((_) {
                    if (mounted) {
                      ref.invalidate(categoriesFlutterProvider);
                    }
                  });
                }
              } else {
                // Обычный поток — выбор категории
                showCategoryDialog(context);
              }
            }
            setState(() {});
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              isRepeat
                  ? Icon(Icons.replay, color: Colors.black87, size: 28)
                  : Image.asset(widget.image, width: 30),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: isRepeat ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              Gap(20),
            ],
          ),
        ),
      ),
    );
  }
}
