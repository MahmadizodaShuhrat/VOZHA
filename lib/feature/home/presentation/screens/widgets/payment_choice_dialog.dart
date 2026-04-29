// payment_choice_dialog.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vozhaomuz/feature/profile/business/premium_repository.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Публичная функция-обёртка для показа диалога
void showPaymentChoiceDialog(
  BuildContext context, {
  required int tariffId,
  required String promoCode,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        PaymentChoiceDialog(tariffId: tariffId, promoCode: promoCode),
  );
}

/// Публичный класс диалога
class PaymentChoiceDialog extends ConsumerStatefulWidget {
  final int tariffId;
  final String promoCode;

  const PaymentChoiceDialog({
    Key? key,
    required this.tariffId,
    required this.promoCode,
  }) : super(key: key);

  @override
  ConsumerState<PaymentChoiceDialog> createState() =>
      _PaymentChoiceDialogState();
}

class _PaymentChoiceDialogState extends ConsumerState<PaymentChoiceDialog> {
  int? _selected = 0;
  bool _isProcessing = false;
  late final _methods = ['payment_local_cards'.tr(), 'MasterCard', 'VisaCard'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5FAFF),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка закрыть
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 28),
              ),
            ),
            const Gap(4),
            // Заголовок
            Text(
              'payment_choose_method'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Gap(16),

            // Список методов
            ..._methods.asMap().entries.map((e) {
              final i = e.key;
              final label = e.value;
              final sel = _selected == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? Colors.amber.shade700 : Colors.grey.shade300,
                    width: sel ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: sel ? 8 : 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selected = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        // Текст метода
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Радиомаркер
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: sel
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const Gap(4),
            // Нижняя кнопка
            MyButton(
              width: double.infinity,
              height: 48,
              borderRadius: 12,
              backButtonColor: Colors.green.shade600,
              buttonColor: Colors.greenAccent.shade400,
              onPressed: _isProcessing
                  ? () {}
                  : () async {
                      HapticFeedback.lightImpact();
                      if (_selected == null) return;

                      setState(() => _isProcessing = true);

                      final repo = ref.read(premiumRepositoryProvider);
                      final url = await repo.getPaymentUrl(
                        widget.tariffId,
                        widget.promoCode,
                        _selected!,
                      );

                      setState(() => _isProcessing = false);

                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }

                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'payment_next'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}

/// Coin payment dialog — same UI but calls getCoinPaymentUrl
void showCoinPaymentDialog(BuildContext context, {required int coinId}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => CoinPaymentDialog(coinId: coinId),
  );
}

class CoinPaymentDialog extends ConsumerStatefulWidget {
  final int coinId;

  const CoinPaymentDialog({Key? key, required this.coinId}) : super(key: key);

  @override
  ConsumerState<CoinPaymentDialog> createState() => _CoinPaymentDialogState();
}

class _CoinPaymentDialogState extends ConsumerState<CoinPaymentDialog> {
  int? _selected = 0;
  bool _isProcessing = false;
  late final _methods = ['payment_local_cards'.tr(), 'MasterCard', 'VisaCard'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF5FAFF),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 28),
              ),
            ),
            const Gap(4),
            Text(
              'payment_choose_method'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Gap(16),
            ..._methods.asMap().entries.map((e) {
              final i = e.key;
              final label = e.value;
              final sel = _selected == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? Colors.amber.shade700 : Colors.grey.shade300,
                    width: sel ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: sel ? 8 : 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selected = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: sel
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const Gap(4),
            MyButton(
              width: double.infinity,
              height: 48,
              borderRadius: 12,
              backButtonColor: Colors.green.shade600,
              buttonColor: Colors.greenAccent.shade400,
              onPressed: _isProcessing
                  ? () {}
                  : () async {
                      HapticFeedback.lightImpact();
                      if (_selected == null) return;

                      setState(() => _isProcessing = true);

                      final repo = ref.read(premiumRepositoryProvider);
                      final url = await repo.getCoinPaymentUrl(
                        widget.coinId,
                        _selected!,
                      );

                      setState(() => _isProcessing = false);

                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }

                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'payment_next'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}
