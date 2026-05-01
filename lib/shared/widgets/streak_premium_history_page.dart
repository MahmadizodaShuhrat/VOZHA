import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/rating/data/models/streak_premium_history_dto.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/streak_premium_history_provider.dart';

/// Premium-bonus history page (TZ §3). Lists every streak-bonus
/// grant the user has ever earned, with totals at the top.
///
/// Open from the streak dialog when the user taps the "earned via
/// bonus: N days" tile.
class StreakPremiumHistoryPage extends ConsumerWidget {
  const StreakPremiumHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(streakPremiumHistoryProvider(50));
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7ED),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1D2939), size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          'streak_bonus_history_title'.tr(),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '$e',
              style: GoogleFonts.inter(color: const Color(0xFF667085)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) {
          final history = data ?? StreakPremiumHistoryDto.empty;
          if (history.history.isEmpty) {
            return _EmptyState();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeaderCard(history: history),
              const SizedBox(height: 14),
              for (final grant in history.history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GrantCard(grant: grant),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final StreakPremiumHistoryDto history;
  const _HeaderCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final localeTag = context.locale.toLanguageTag();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDB022).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDB022), Color(0xFFE48B0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('👑', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'streak_total_bonus_earned'.tr(
                        namedArgs: {
                          'days': '${history.totalDaysGranted}',
                        },
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (history.bonusActiveUntil != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'streak_bonus_history_active_until'.tr(
                          namedArgs: {
                            'date': _formatLocalDate(
                              history.bonusActiveUntil!,
                              localeTag,
                            ),
                          },
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrantCard extends StatelessWidget {
  final StreakPremiumGrantDto grant;
  const _GrantCard({required this.grant});

  @override
  Widget build(BuildContext context) {
    final localeTag = context.locale.toLanguageTag();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFEF6E7)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF6E7),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '+${grant.premiumDaysAdded}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'streak_bonus_history_row'.tr(
                    namedArgs: {
                      'run': '${grant.streakRunId}',
                      'days': '${grant.milestoneStreak}',
                      'added': '${grant.premiumDaysAdded}',
                    },
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                if (grant.grantedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatLocalDate(grant.grantedAt!, localeTag),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF98A2B3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'streak_bonus_history_empty'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF667085),
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLocalDate(DateTime utc, String localeTag) {
  // easy_localization re-exports `DateFormat` from intl. Try a
  // localized "long" format; fall back to ISO if the locale isn't
  // bundled with intl's data tables.
  try {
    return DateFormat.yMMMMd(localeTag).format(utc.toLocal());
  } catch (_) {
    final d = utc.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
