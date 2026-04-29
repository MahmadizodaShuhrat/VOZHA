import 'package:flutter/material.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/podgorovka_alert_page.dart';

void showCReklamaDialog(BuildContext context) {
  Widget container(Color color, String title, Color colorText, Border border) {
    return GestureDetector(
      onTap: () {
        showPodgotovkaDialog(context);
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: colorText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          backgroundColor: const Color(0xFFF5FAFF),
          title: Center(
            child: Text(
              "Реклама...",
              style: TextStyle(
                color: Color(0xFF202939),
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ),
          content: SizedBox(
            // `double.infinity` lets AlertDialog's own constraints drive
            // the width (defaults to ~80 % of screen). The old `358` was
            // wider than iPhone SE's 375 pt and broke on Honor / Redmi
            // once OS font scale pushed the inner text to 2+ lines.
            // Height is now driven by the column instead of hardcoded.
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  "Смотрите 2 рекламы в день. Вы можете отключить показ рекламы, купив премиум.",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF627484),
                  ),
                ),
                SizedBox(height: 20),
                container(
                  Colors.blue,
                  "Продолжить за рекламу",
                  Colors.white,
                  Border(
                    bottom: BorderSide(color: Colors.blue.shade800, width: 4),
                  ),
                ),
                SizedBox(height: 10),
                container(
                  Colors.orange.shade300,
                  "Купить премиум",
                  Colors.white,
                  Border(bottom: BorderSide(color: Colors.orange, width: 4)),
                ),
                SizedBox(height: 10),
                container(
                  Colors.grey.shade200,
                  "Понятно",
                  Colors.grey,
                  Border(bottom: BorderSide(color: Colors.grey, width: 4)),
                ),
              ],
            ),
          ),
        ),
  );
}
