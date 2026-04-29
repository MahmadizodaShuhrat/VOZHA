import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/profile/business/premium_repository.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/premium_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/payment_choice_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

class PayPremiumPage extends HookConsumerWidget {
  const PayPremiumPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlan = useState<int?>(null);
    final promoController = useTextEditingController();
    final tariffsAsync = ref.watch(tariffsProvider);
    final lc = context.locale.languageCode;
    final langCode = lc == 'tg' ? 'tj' : lc;
    final isApplyingPromo = useState(false);
    final promoDiscount = useState<PromoResult?>(null);
    final promoCachedCode = useState<String>('');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  center: const Alignment(0, -0.6),
                  startAngle: 0,
                  endAngle: 3.14 * 2,
                  colors: List.generate(
                    12,
                    (i) => i.isEven ? Colors.amber.shade50 : Colors.white,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, size: 30),
                    ),
                  ),
                  const Gap(24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: const CircleAvatar(
                          radius: 48,
                          backgroundImage: AssetImage(
                            'assets/images/Frame_vozha.png',
                          ),
                        ),
                      ),
                      const Gap(12),
                      const Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffF9A628),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Text(
                    'premium_choose_plan'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const Gap(24),

                  // Tariffs from server
                  tariffsAsync.when(
                    data: (tariffs) {
                      if (tariffs.isEmpty) {
                        return Center(child: Text('tariffs_not_found'.tr()));
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < tariffs.length; i++) ...[
                            _PlanCard(
                              title: tariffs[i].getLocalizedName(langCode),
                              subtitle:
                                  promoDiscount.value != null &&
                                      selectedPlan.value == i
                                  ? '${promoDiscount.value!.amount} ${'currency_somoni'.tr()}'
                                  : '${tariffs[i].price} ${'currency_somoni'.tr()}',
                              selected: selectedPlan.value == i,
                              onTap: () => selectedPlan.value = i,
                            ),
                            const Gap(12),
                          ],
                        ],
                      );
                    },
                    loading: () => Column(
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey.shade300,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    error: (error, _) => Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const Gap(8),
                        Text('${'loading_error'.tr()}: $error'),
                        const Gap(8),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(tariffsProvider),
                          child: Text('retry'.tr()),
                        ),
                      ],
                    ),
                  ),

                  const Gap(24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'promo_code'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(15),
                              bottomLeft: Radius.circular(15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: promoController,
                            decoration: InputDecoration(
                              fillColor: Colors.white,
                              filled: true,
                              hintText: 'enter_promo_code'.tr(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  bottomLeft: Radius.circular(15),
                                ),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      MyButton(
                        height: 52,
                        width: 80,
                        padding: EdgeInsets.zero,
                        borderRadius: 5,
                        backButtonColor: Colors.white,
                        buttonColor: Colors.blue.shade600,
                        onPressed: isApplyingPromo.value
                            ? () {}
                            : () async {
                                HapticFeedback.lightImpact();
                                final code = promoController.text.trim();
                                if (code.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('enter_promo_code'.tr()),
                                    ),
                                  );
                                  return;
                                }

                                final tariffs = tariffsAsync.value ?? [];
                                if (selectedPlan.value == null ||
                                    tariffs.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('select_tariff_first'.tr()),
                                    ),
                                  );
                                  return;
                                }

                                final tariffId =
                                    tariffs[selectedPlan.value!].id;
                                isApplyingPromo.value = true;

                                final repo = ref.read(
                                  premiumRepositoryProvider,
                                );
                                final result = await repo.applyPromoCode(
                                  code,
                                  tariffId,
                                );

                                isApplyingPromo.value = false;

                                if (result != null &&
                                    result.discountPercent > 0) {
                                  promoDiscount.value = result;
                                  promoCachedCode.value = code;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'promo_discount_applied'.tr(
                                            args: [
                                              result.discountPercent.toString(),
                                            ],
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  promoDiscount.value = null;
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('promo_not_found'.tr()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isApplyingPromo.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'apply'.tr(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const Gap(40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: MyButton(
            height: 50,
            borderRadius: 12,
            backButtonColor: Colors.green.shade600,
            buttonColor: Colors.greenAccent.shade400,
            onPressed: () {
              HapticFeedback.lightImpact();
              if (selectedPlan.value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('please_select_tariff'.tr())),
                );
                return;
              }

              final tariffs = tariffsAsync.value ?? [];
              if (tariffs.isEmpty) return;

              final tariffId = tariffs[selectedPlan.value!].id;
              final promoCode = promoCachedCode.value;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => PaymentChoiceDialog(
                  tariffId: tariffId,
                  promoCode: promoCode,
                ),
              );
            },
            child: Text(
              'next'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка тарифа с радиокружком и анимацией
class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: 100,
      margin: const EdgeInsets.only(bottom: 10),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: selected ? Colors.amber.shade700 : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: selected ? 8 : 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Colors.amber.shade700
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      )
                    : null,
              ),
              const Gap(16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
