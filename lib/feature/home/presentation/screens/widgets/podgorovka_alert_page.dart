import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void showPodgotovkaDialog(BuildContext context) {
  showDialog(
    context: context,
    builder:
        (context) => AlertDialog(
          backgroundColor: const Color(0xFFF5FAFF),
          title: Center(
            child: Text(
              "Пожалуйста, подождите немного,\nмы подготавливаем ваши слова.",
              style: TextStyle(
                color: Color(0xFF202939),
                fontWeight: FontWeight.w500,
                fontSize: 20,
              ),
            ),
          ),
          content: SizedBox(
            // Same reason as reklama_alert_page: hardcoded 358 pt
            // overflows iPhone SE (375 pt) minus AlertDialog's own
            // insetPadding, and was visibly clipping on Honor with
            // Large font scale. `double.infinity` delegates sizing to
            // AlertDialog's responsive defaults.
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF5FAFF),
                  ),
                  child: Center(
                    child: SvgPicture.asset("assets/images/person1.svg"),
                  ),
                ),
                Text(
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  "Подготовка слов",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF627484),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "0%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF627484),
                      ),
                    ),
                    Text(
                      "из 100%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF627484),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                container(
                  Colors.orange.shade300,
                  "Подготовьте!",
                  Colors.white,
                  Border(bottom: BorderSide(color: Colors.orange, width: 4)),
                ),
                SizedBox(height: 10),
                container(
                  Colors.grey.shade200,
                  "Отменить",
                  Colors.grey,
                  Border(bottom: BorderSide(color: Colors.grey, width: 4)),
                ),
              ],
            ),
          ),
        ),
  );
}

Widget container(Color color, String title, Color colorText, Border border) {
  return Container(
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
  );
}
