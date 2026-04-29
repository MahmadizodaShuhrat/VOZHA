import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/providers/bottom_nav_provider.dart';
import 'package:vozhaomuz/feature/battle/data/battle_phase.dart';
import 'package:vozhaomuz/feature/battle/presentation/screens/battle_page.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/courses/presentation/screens/courses_tab_page.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/home_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/my_words/presentation/screens/my_words_page.dart';
import 'package:vozhaomuz/feature/rating/presentation/screens/ratings_screen.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

final bottomNavProvider = NotifierProvider<BottomNavNotifier, int>(
  BottomNavNotifier.new,
);

class NavigationPage extends ConsumerStatefulWidget {
  final int initialIndex;
  const NavigationPage({super.key, this.initialIndex = 0});

  @override
  ConsumerState<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends ConsumerState<NavigationPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    Future.microtask(() {
      ref.read(bottomNavProvider.notifier).setIndex(widget.initialIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Exit confirmation dialog — matching Unity 3D UIExitBattle design.
  void _showBattleExitDialog() {
    final st = ref.read(battleProvider);
    final vm = ref.read(battleProvider.notifier);
    final penalty = st.moneyCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coin icon
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/coin.png',
                    width: 44,
                    height: 44,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.monetization_on_rounded,
                      size: 44,
                      color: Color(0xFFF79009),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Penalty amount
              Text(
                '-$penalty монет',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF79009),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'Вы уверены что\nхотите выйти с игры?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                'Если вы выйдете то потеряете $penalty монет',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),
              // Continue button (MyButton with border)
              MyButton(
                onPressed: () => Navigator.of(context).pop(),
                width: double.infinity,
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                border: 1.5,
                borderColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Продолжить играть',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Exit button (MyButton red)
              MyButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  vm.disconnectAll();
                  ref.read(getProfileInfoProvider.notifier).getProfile();
                },
                width: double.infinity,
                buttonColor: const Color(0xFFEF4444),
                backButtonColor: const Color(0xFFB91C1C),
                borderRadius: 14,
                depth: 4,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Выйти с игры',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(bottomNavProvider);
    final battleState = ref.watch(battleProvider);

    // Sync PageView when tab changes via provider
    ref.listen<int>(bottomNavProvider, (prev, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.jumpToPage(next);
      }
    });

    // Check if battle is actively in progress.
    // Battle tab moved from index 2 → 3 after the Courses tab was inserted.
    final isBattleActive =
        currentIndex == 3 &&
        (battleState.phase == BattlePhase.waitingRoom ||
            battleState.phase == BattlePhase.countdown ||
            battleState.phase == BattlePhase.playing ||
            battleState.phase == BattlePhase.waitingResults ||
            battleState.phase == BattlePhase.finished);

    return PopScope(
      canPop: !isBattleActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isBattleActive) {
          _showBattleExitDialog();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: isBattleActive
              ? const NeverScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            ref.read(bottomNavProvider.notifier).setIndex(index);
          },
          children: const [
            HomePage(),
            MyWordsPage(),
            CoursesTabPage(),
            BattlePage(),
            RatingScreen(),
          ],
        ),
        bottomNavigationBar: isBattleActive
            ? null // Hide bottom nav during active battle (like Unity)
            : BottomNavigationBar(
                  currentIndex: currentIndex,
                  backgroundColor: Colors.white,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Color(0xFF2E90FA),
                  unselectedItemColor: Color(0xFF9AA4B2),
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  iconSize: 32,
                  onTap: (index) {
                    ref.read(bottomNavProvider.notifier).setIndex(index);
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/Home.png',
                          width: 32,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                      activeIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/HomeSelected.png',
                          width: 34,
                        ),
                      ),
                      label: "home".tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/MyLessons.png',
                          width: 32,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                      activeIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/MyLessonsSelected.png',
                          width: 34,
                        ),
                      ),
                      label: "my_words".tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Icon(
                          Icons.school_rounded,
                          size: 30,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                      activeIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Icon(
                          Icons.school_rounded,
                          size: 32,
                          color: Color(0xFF2E90FA),
                        ),
                      ),
                      label: "courses_tab".tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/Battle.png',
                          width: 32,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                      activeIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/battle/BattleSelected.png',
                          width: 34,
                        ),
                      ),
                      label: "Баттл",
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/Statistics.png',
                          width: 32,
                          color: Color(0xFF9AA4B2),
                        ),
                      ),
                      activeIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Image.asset(
                          'assets/images/UIHome/StatisticsSelected.png',
                          width: 34,
                        ),
                      ),
                      label: "rating".tr(),
                    ),
                  ],
                ),
      ),
    );
  }
}
