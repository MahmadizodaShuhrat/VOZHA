import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vozhaomuz/feature/rating/data/models/progress_model.dart';

class ProgressWidget extends StatelessWidget {
  final ProgressModel item;

  const ProgressWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(9),
      width: MediaQuery.of(context).size.width * 0.24,
      height: 100,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 4),
        ),
        color: item.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          item.image,
          // Shrink-to-fit so large counts like "44942" and OS font
          // scale >1.0 still render inside the 24 % screen-width tile
          // instead of overflowing or getting ellipsized.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.count,
              maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            item.titleKey.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
