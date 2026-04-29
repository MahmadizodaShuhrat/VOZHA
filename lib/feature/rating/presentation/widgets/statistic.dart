import 'package:flutter/material.dart';

class Statistic extends StatelessWidget {
  const Statistic({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(top: 10, bottom: 15),
      child: Text(
        'Статистика',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 27,
        ),
      ),
    );
  }
}
