import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'package:vozhaomuz/feature/battle/data/member_dto.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/shield_place_animation.dart';
import 'package:vozhaomuz/core/services/review_service.dart';

/// Экран результатов — дизайн Unity 3D:
/// Трофей + подиум + таблица лидеров + кнопка выхода.
class BattleFinishedPage extends ConsumerWidget {
  const BattleFinishedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In-App Review after battle results
    ReviewService.instance.trackAndRequestReview();

    final st = ref.watch(battleProvider);
    final vm = ref.read(battleProvider.notifier);

    // Клиент-сайд сорт. Сервер `place`-ро бо формулае ҳисоб мекунад, ки
    // тезиро дар `score` бонус мегузорад — натиҷа: корбарони
    // нодуруст-вале-зуд ба ҷойҳои баланд мерасанд. Дар клиент бевосита
    // аз `correctAnswers` сорт мекунем, бо tie-break-и `finishTime`.
    //
    // Ботҳо ҳамчун real player рақобат мекунанд (онҳо қоидаҳои якхела
    // бозӣ мекунанд). Танҳо `hasLeft`-ҳо (тарк-кардаҳо) ба охир мераванд.
    final sorted = List<MemberDto>.from(st.members);
    sorted.sort((a, b) {
      // hasLeft → охир (онҳо бозиро тамом накардаанд)
      if (a.hasLeft != b.hasLeft) return a.hasLeft ? 1 : -1;

      // Аз ҳама муҳим: ҷавобҳои дуруст
      final byCorrect = b.correctAnswers.compareTo(a.correctAnswers);
      if (byCorrect != 0) return byCorrect;

      // Tie: тезтар тамом кардан ғолиб
      final aFinish = a.finishTime ??
          DateTime.fromMillisecondsSinceEpoch(0x7fffffffffff, isUtc: true);
      final bFinish = b.finishTime ??
          DateTime.fromMillisecondsSinceEpoch(0x7fffffffffff, isUtc: true);
      final byTime = aFinish.compareTo(bFinish);
      if (byTime != 0) return byTime;

      // Tie-tie: score-и server
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      // Стабилӣ
      return a.id.compareTo(b.id);
    });

    // Ҷой = тартиб дар sorted (cap=4 барои ShieldPlaceAnimation asset).
    // Юзер метавонад дар ҳама ҷой бошад — агар аз бот-ҳо хатоҳо кам
    // диҳад, метавонад #1 шавад; агар на, дар поён ҷой гирад. Ин
    // ҳаминтавр аз ҳама некъ-фаҳмии-юзерӣ — table ва shield ҳамоҳанг.
    final myId = StorageService.instance.getUserId();
    final myName = StorageService.instance.getUserName() ?? '';
    int myPlace = sorted.length;
    for (int i = 0; i < sorted.length; i++) {
      final m = sorted[i];
      final isMe =
          (myId != null && m.id == myId) ||
          (myId == null && myName.isNotEmpty && m.name == myName) ||
          (myId == null && myName.isEmpty && m.id > 0);
      if (!isMe) continue;
      myPlace = (i >= 3) ? 4 : i + 1;
      break;
    }
    debugPrint(
      '[BattleResult] myId=$myId myName=$myName myPlace=$myPlace members=${sorted.map((m) => '${m.id}:${m.name}:${m.score}').toList()}',
    );

    // Track battle win
    if (myPlace == 1) {
      StorageService.instance.incrementBattleWins();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A4B8C),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scroll area — ҳама ба ғайр аз тугма ──
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── Заголовок ──
                    Text(
                      'battle_results_title'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 80.h),
                    ShieldPlaceAnimation(place: myPlace, size: 130),
                    // ── Подиум ──
                    if (sorted.isNotEmpty) _buildPodium(sorted),
                    SizedBox(height: 20.h),

                    // ── Таблица лидеров ──
                    Container(
                      height: 260.h,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                          bottom: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Заголовок таблицы
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    '№',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF98A2B3),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'battle_table_player'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF98A2B3),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    'battle_table_correct'.tr(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF98A2B3),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    'battle_table_score'.tr(),
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF98A2B3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: const Color(
                              0xFFE4E7EC,
                            ).withValues(alpha: 0.6),
                          ),

                          // Список
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: sorted.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, i) =>
                                  _buildResultRow(i + 1, sorted[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),

            // ── Тугмаи "Выйти" — ДАР ПОЁН ФИКС ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: MyButton(
                onPressed: () => vm.disconnectAll(),
                buttonColor: const Color(0xFFF79009),
                backButtonColor: const Color(0xFFDC6803),
                width: double.infinity,
                height: 52.h,
                borderRadius: 14,
                child: Text(
                  'battle_exit_btn'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(List<MemberDto> sorted) {
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) Expanded(child: _buildPodiumItem(second, 2, 75)),
          if (first != null) Expanded(child: _buildPodiumItem(first, 1, 105)),
          if (third != null) Expanded(child: _buildPodiumItem(third, 3, 55)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(MemberDto member, int place, double height) {
    final podiumColors = {
      1: const Color(0xFFFDB022), // Золотой
      2: const Color(0xFF98A2B3), // Серебряный
      3: const Color(0xFFDC6803), // Бронзовый
    };
    final avatarBgs = {
      1: const Color(0xFF7B61FF), // Фиолетовый для 1-го места
      2: const Color(0xFFEFF8FF),
      3: const Color(0xFFFEF0C7),
    };
    final color = podiumColors[place] ?? const Color(0xFF98A2B3);
    final avatarBg = avatarBgs[place] ?? const Color(0xFFEFF8FF);

    return Column(
      children: [
        // Корона для 1-го места
        SizedBox(height: 10),
        if (place == 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text('👑', style: TextStyle(fontSize: 20)),
          ),

        // Аватар
        Container(
          width: place == 1 ? 56 : 44,
          height: place == 1 ? 56 : 44,
          decoration: BoxDecoration(
            color: avatarBg,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          alignment: Alignment.center,
          child: member.isBot
              ? Icon(
                  Icons.smart_toy_rounded,
                  color: color,
                  size: place == 1 ? 24 : 18,
                )
              : Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: place == 1 ? 20 : 16,
                    fontWeight: FontWeight.w700,
                    color: place == 1 ? Colors.white : color,
                  ),
                ),
        ),
        const SizedBox(height: 6),

        // Имя + монеты (ё баромад)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            member.hasLeft
                ? '${member.name} ❌'
                : '${member.name} ${'battle_coins_won'.tr(args: ['${member.wonCoins}'])}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: member.hasLeft ? Colors.white54 : Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Счёт
        Text(
          'battle_score_label'.tr(args: ['${member.score}']),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  Строка результатов
  // ═══════════════════════════════════════════════════════

  Widget _buildResultRow(int place, MemberDto member) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: place <= 3 ? const Color(0xFFFFFBF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: place <= 3
              ? const Color(0xFFFDB022).withValues(alpha: 0.2)
              : const Color(0xFFE4E7EC).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Место
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: place <= 3
                  ? const Color(0xFFFEF0C7)
                  : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$place',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: place <= 3
                    ? const Color(0xFFF79009)
                    : const Color(0xFF667085),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Аватар
          CircleAvatar(
            radius: 15,
            backgroundColor: member.isBot
                ? const Color(0xFFFEF0C7)
                : const Color(0xFFEFF8FF),
            child: member.isBot
                ? const Icon(
                    Icons.smart_toy_rounded,
                    size: 14,
                    color: Color(0xFFF79009),
                  )
                : Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E90FA),
                    ),
                  ),
          ),
          const SizedBox(width: 8),

          // Имя
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: member.hasLeft
                          ? const Color(0xFF98A2B3)
                          : const Color(0xFF344054),
                      decoration: member.hasLeft
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (member.hasLeft) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.exit_to_app,
                    size: 14,
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ],
            ),
          ),

          // Верных ответов
          SizedBox(
            width: 50,
            child: Text(
              '${member.correctAnswers}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF12B76A),
              ),
            ),
          ),

          // Счёт
          SizedBox(
            width: 50,
            child: Text(
              '${member.score}',
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2939),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
