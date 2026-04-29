// import 'package:flutter/material.dart';

// Widget _buildMatchTile({
//     required String text,
//     required int pairIndex,
//     required bool isEnglish,
//   }) {
//     final bgColor     = _backgroundColor(pairIndex, isEnglish);
//     final borderColor = _borderColor(pairIndex, isEnglish);

//     return GestureDetector(
//       onTap: () => _onTileTap(pairIndex, isEnglish),
//       child: Container(
//         height: 80,
//         decoration: BoxDecoration(
//           color: bgColor,
//           borderRadius: BorderRadius.circular(12),
//           border: Border(
//             bottom: BorderSide(color: borderColor, width: 6),
//             right:  BorderSide(color: borderColor, width: 2),
//             left:   BorderSide(color: borderColor, width: 2),
//             top:    BorderSide(color: borderColor, width: 2),
//           ),
//         ),
//         alignment: Alignment.center,
//         child: Text(
//           text,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w400,
//             color: Color(0xFF202939),
//           ),
//         ),
//       ),
//     );
//   }
// }
