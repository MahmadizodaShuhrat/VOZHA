import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/feature/auth/data/referral_sourse_model.dart';

final selectedIndexProvider = NotifierProvider<ReferralIndexNotifier, int?>(ReferralIndexNotifier.new);
class ReferralIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? value) => state = value;
}

class ReferralSourseWidget extends ConsumerStatefulWidget {
  final ReferralSourseModel model;
  final int index;
  const ReferralSourseWidget({
    super.key,
    required this.model,
    required this.index,
  });

  @override
  ConsumerState<ReferralSourseWidget> createState() =>
      _ReferralSourseWidgetState();
}

class _ReferralSourseWidgetState extends ConsumerState<ReferralSourseWidget> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final isChecked = selectedIndex == widget.index;
    return GestureDetector(
      onTap: () {
        ref.read(selectedIndexProvider.notifier).set(widget.index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              isChecked
                  ? Border.all(color: Colors.blue, width: 1.5)
                  : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image(
                  image: AssetImage(widget.model.image),
                  width: 35,
                  height: 35,
                ),
                Gap(10),
                Text(
                  widget.model.name,
                  style: TextStyle(fontWeight: FontWeight.w400, fontSize: 17),
                ),
              ],
            ),
            Checkbox(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: const BorderSide(color: Colors.grey),
              checkColor: Colors.white,
              activeColor: Colors.blue,
              value: isChecked,
              onChanged: (value) {
                ref.read(selectedIndexProvider.notifier).set(
                    value! ? widget.index : null);
              },
            ),
          ],
        ),
      ),
    );
  }
}
