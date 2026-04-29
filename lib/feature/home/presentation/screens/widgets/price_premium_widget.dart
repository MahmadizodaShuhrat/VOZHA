import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/feature/profile/data/model/price_premium_model.dart';

final selectedIndexProvider = NotifierProvider<PricePremiumIndexNotifier, int?>(PricePremiumIndexNotifier.new);
class PricePremiumIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? value) => state = value;
}

class PricePremiumWidget extends ConsumerStatefulWidget {
  final PricePremiumModel premium;
  final int index;
  const PricePremiumWidget({
    super.key,
    required this.premium,
    required this.index,
  });

  @override
  ConsumerState<PricePremiumWidget> createState() => _PricePremiumWidgetState();
}

class _PricePremiumWidgetState extends ConsumerState<PricePremiumWidget> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final isSelected = selectedIndex == widget.index;
    return GestureDetector(
      onTap: () {
        ref.read(selectedIndexProvider.notifier).set(widget.index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 80,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              spreadRadius: isSelected ? 5 : 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? Border.all(color: Colors.brown.shade300, width: 1.5)
                  : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.premium.price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                  ),
                ),
                Text(
                  widget.premium.time,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_sharp
                  : Icons.circle_outlined,
              color: isSelected ? Colors.blue : Colors.black,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }
}
