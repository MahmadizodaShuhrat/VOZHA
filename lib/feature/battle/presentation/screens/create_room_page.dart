import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vozhaomuz/core/utils/app_locale_utils.dart';
import 'package:vozhaomuz/core/database/category_db_helper.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';
import 'package:vozhaomuz/feature/battle/providers/battle_provider.dart';
import 'package:vozhaomuz/feature/home/data/categories_repository.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/core/utils/category_resource_service.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';
import 'package:vozhaomuz/shared/widgets/energy_paywall_dialog.dart';
import 'package:vozhaomuz/feature/battle/presentation/widgets/battle_download_dialog.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/my_subscription_page.dart';

/// Форма создания комнаты — категория, подкатегория, кол-во слов, тип комнаты.
class CreateRoomPage extends ConsumerStatefulWidget {
  const CreateRoomPage({super.key});

  @override
  ConsumerState<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends ConsumerState<CreateRoomPage> {
  int _selectedCategoryId = 0;
  int _selectedSubCategoryId = 0; // 0 = "Все"
  int _wordsCount = 4;
  int _selectedCoins = 6;
  bool _isPublic = true;
  bool _isCreating = false;

  // Категории из бэкенда
  List<CategoryFlutterDto> _categories = [];
  bool _isCategoriesLoading = true;
  List<Subcategory> _subcategories = [];
  bool _isSubcategoriesLoading = false;
  int _loadedSubcategoriesCategoryId = 0;
  String _loadedSubcategoriesLangCode = '';

  // GlobalKeys for popup positioning
  final _wordsKey = GlobalKey();
  final _roomTypeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = CategoriesRepository();
    final categories = await repo.getCategories();
    if (!mounted) return;
    // Sort by ID for consistent ordering
    categories.sort((a, b) => a.id.compareTo(b.id));

    final locale = ref.read(localeProvider);
    final langCode = normalizeCategoryLanguageCode(locale.languageCode);

    // Filter by user's organization (mirrors category_setting.dart)
    final profileAsync = ref.read(getProfileInfoProvider);
    final userOrgId = profileAsync.value?.organizationId ?? 0;
    final visibleCategories = categories.where((cat) {
      final orgs = cat.parsedInfo?.organizations ?? [];
      if (orgs.isEmpty) return true; // visible to all
      return orgs.contains(userOrgId); // org-restricted
    }).toList();

    final selectedCategoryId = visibleCategories.any(
          (cat) => cat.id == _selectedCategoryId,
        )
        ? _selectedCategoryId
        : (visibleCategories.isNotEmpty ? visibleCategories.first.id : 0);

    setState(() {
      _categories = visibleCategories;
      _isCategoriesLoading = false;
      _selectedCategoryId = selectedCategoryId;
      if (selectedCategoryId == 0) {
        _selectedSubCategoryId = 0;
        _subcategories = [];
        _loadedSubcategoriesCategoryId = 0;
        _loadedSubcategoriesLangCode = '';
      }
    });

    if (selectedCategoryId != 0) {
      await _loadSubcategoriesForCategory(
        selectedCategoryId,
        langCode: langCode,
        preserveSelection: true,
      );
    }
  }

  CategoryFlutterDto? _selectedCategory() {
    return _categories.cast<CategoryFlutterDto?>().firstWhere(
      (cat) => cat?.id == _selectedCategoryId,
      orElse: () => null,
    );
  }

  String _selectedCategoryName(String langCode) {
    if (_isCategoriesLoading) return 'battle_loading'.tr();
    return _selectedCategory()?.getLocalizedName(langCode) ??
        'battle_loading'.tr();
  }

  String _selectedSubCategoryName() {
    if (_selectedSubCategoryId == 0) return 'battle_all'.tr();
    return _subcategories.cast<Subcategory?>().firstWhere(
          (sub) => sub?.id == _selectedSubCategoryId,
          orElse: () => null,
        )?.name ??
        'battle_all'.tr();
  }

  void _ensureLocalizedSubcategories(String langCode) {
    final needsReload =
        _selectedCategoryId != 0 &&
        !_isCategoriesLoading &&
        !_isSubcategoriesLoading &&
        (_loadedSubcategoriesCategoryId != _selectedCategoryId ||
            _loadedSubcategoriesLangCode != langCode);

    if (!needsReload) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSubcategoriesLoading) return;
      _loadSubcategoriesForCategory(
        _selectedCategoryId,
        langCode: langCode,
        preserveSelection: true,
      );
    });
  }

  Future<void> _loadSubcategoriesForCategory(
    int categoryId, {
    required String langCode,
    bool preserveSelection = false,
  }) async {
    if (categoryId == 0) return;

    setState(() {
      _isSubcategoriesLoading = true;
    });

    final subcategories = await CategoryDbHelper.getSubcategories(
      categoryId,
      langCode: langCode,
    );
    if (!mounted) return;

    final hasSelectedSubcategory = preserveSelection &&
        subcategories.any((sub) => sub.id == _selectedSubCategoryId);

    setState(() {
      _subcategories = subcategories;
      _isSubcategoriesLoading = false;
      _loadedSubcategoriesCategoryId = categoryId;
      _loadedSubcategoriesLangCode = langCode;
      if (!hasSelectedSubcategory) {
        _selectedSubCategoryId = 0;
      }
    });
  }

  /// Show popup menu below a widget using its GlobalKey
  void _showPopupBelow(GlobalKey key, List<PopupMenuEntry<dynamic>> items) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final langCode = normalizeCategoryLanguageCode(locale.languageCode);
    _ensureLocalizedSubcategories(langCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Scrollable content ──
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Категория и Подкатегория уроков (Row) ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _sectionTitle('battle_category_lessons'.tr()),
                          const SizedBox(height: 6),
                          _buildSelector(
                            text: _selectedCategoryName(langCode),
                            onTap: () => _showCategorySheet(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _sectionTitle('battle_subcategory_lessons'.tr()),
                          const SizedBox(height: 6),
                          _buildSelector(
                            text: _selectedSubCategoryName(),
                            onTap: () => _showSubCategorySheet(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Количество слов и Тип комнаты (Row) — popup menus ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('battle_words_count_label'.tr()),
                          const SizedBox(height: 6),
                          _buildSelector(
                            key: _wordsKey,
                            text: '$_wordsCount',
                            onTap: () {
                              _showPopupBelow(_wordsKey, [
                                for (final w in [4, 8])
                                  PopupMenuItem(
                                    onTap: () => setState(() => _wordsCount = w),
                                    child: Text(
                                      '$w',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: _wordsCount == w
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: _wordsCount == w
                                            ? const Color(0xFF2E90FA)
                                            : const Color(0xFF344054),
                                      ),
                                    ),
                                  ),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('battle_room_type'.tr()),
                          const SizedBox(height: 6),
                          _buildSelector(
                            key: _roomTypeKey,
                            text: _isPublic
                                ? 'battle_room_public'.tr()
                                : 'battle_room_private'.tr(),
                            onTap: () {
                              _showPopupBelow(_roomTypeKey, [
                                PopupMenuItem(
                                  onTap: () => setState(() => _isPublic = true),
                                  child: Text(
                                    'battle_room_public'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: _isPublic
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: _isPublic
                                          ? const Color(0xFF2E90FA)
                                          : const Color(0xFF344054),
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  onTap: () => setState(() => _isPublic = false),
                                  child: Text(
                                    'battle_room_private'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: !_isPublic
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: !_isPublic
                                          ? const Color(0xFF2E90FA)
                                          : const Color(0xFF344054),
                                    ),
                                  ),
                                ),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 35),

                // ── Количество монет ──
                _buildCoinSection(),
              ],
            ),
          ),
        ),

        // ── Кнопка создать (fixed at bottom) ──
        const SizedBox(height: 12),
        MyButton(
          onPressed: _isCreating ? null : _handleCreate,
          width: double.infinity,
          buttonColor: const Color(0xFF2E90FA),
          backButtonColor: const Color(0xFF1570EF),
          borderRadius: 14,
          child: _isCreating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'battle_create_room'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1D2939),
      ),
    );
  }

  Widget _buildSelector({
    required String text,
    required VoidCallback onTap,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF344054),
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF98A2B3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Open bottom sheet for category selection
  void _showCategorySheet(BuildContext context) {
    final locale = ref.read(localeProvider);
    final langCode = normalizeCategoryLanguageCode(locale.languageCode);

    // Split: general vs English 24 (org-restricted)
    final generalCats = <CategoryFlutterDto>[];
    final english24Cats = <CategoryFlutterDto>[];
    for (final cat in _categories) {
      final orgs = cat.parsedInfo?.organizations ?? [];
      if (orgs.isNotEmpty) {
        english24Cats.add(cat);
      } else {
        generalCats.add(cat);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        // 70 % of screen height clamped to [420, 640]. Unclamped, on
        // short Android phones or split-screen / tablet multi-window the
        // 70 % value can drop below the space required for the header
        // row + one visible tile, causing a RenderFlex overflow. Clamp
        // also prevents the sheet from taking too much screen on very
        // tall phones.
        final sheetHeight = (MediaQuery.of(context).size.height * 0.7)
            .clamp(420.0, 640.0);
        return Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'battle_select_category'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D2939),
                          height: 1.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isCategoriesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _categories.isEmpty
                    ? Center(
                        child: Text(
                          'battle_no_categories'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        children: [
                          for (final cat in generalCats)
                            _buildCategoryItem(cat, langCode),
                          if (english24Cats.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E90FA)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'English 24',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2E90FA),
                                  ),
                                ),
                              ),
                            ),
                            for (final cat in english24Cats)
                              _buildCategoryItem(cat, langCode),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Single category item for the bottom sheet
  Widget _buildCategoryItem(CategoryFlutterDto cat, String langCode) {
    final name = cat.getLocalizedName(langCode);
    final isSelected = cat.id == _selectedCategoryId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () async {
          setState(() {
            _selectedCategoryId = cat.id;
            _selectedSubCategoryId = 0;
            _subcategories = [];
            _isSubcategoriesLoading = true;
            _loadedSubcategoriesCategoryId = 0;
            _loadedSubcategoriesLangCode = '';
          });
          Navigator.pop(context);
          await _loadSubcategoriesForCategory(
            cat.id,
            langCode: langCode,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF5FF) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: const Color(0xFF2E90FA), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              _buildCatIcon(cat),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2E90FA)
                        : const Color(0xFF344054),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E90FA),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Иконка категории (из сети или placeholder)
  Widget _buildCatIcon(CategoryFlutterDto cat) {
    if (cat.icon.isNotEmpty &&
        (cat.icon.startsWith('http://') || cat.icon.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: cat.icon,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildPlaceholderCatIcon(),
        ),
      );
    }
    return _buildPlaceholderCatIcon();
  }

  Widget _buildPlaceholderCatIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFD1E9FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.category_rounded,
        size: 22,
        color: Color(0xFF2E90FA),
      ),
    );
  }

  /// Открыть bottom sheet выбора подкатегории
  void _showSubCategorySheet(BuildContext context) {
    final locale = ref.read(localeProvider);
    final langCode = normalizeCategoryLanguageCode(locale.languageCode);
    if (_selectedCategoryId == 0) return; // категория не выбрана

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        // 70 % of screen height clamped to [420, 640]. Unclamped, on
        // short Android phones or split-screen / tablet multi-window the
        // 70 % value can drop below the space required for the header
        // row + one visible tile, causing a RenderFlex overflow. Clamp
        // also prevents the sheet from taking too much screen on very
        // tall phones.
        final sheetHeight = (MediaQuery.of(context).size.height * 0.7)
            .clamp(420.0, 640.0);
        return Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F4FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Заголовок + крестик ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'battle_select_subcategory'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D2939),
                          height: 1.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Список подкатегорий ──
              Expanded(
                child: FutureBuilder<List<Subcategory>>(
                  future: CategoryDbHelper.getSubcategories(
                    _selectedCategoryId,
                    langCode: langCode,
                  ),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final subs = snapshot.data ?? [];

                    // Опция "Все" + загруженные подкатегории
                    final allOption = Subcategory(
                      id: 0,
                      name: 'battle_all'.tr(),
                      categoryId: _selectedCategoryId,
                    );
                    final items = [allOption, ...subs];

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: items.length,
                      itemBuilder: (ctx2, index) {
                        final sub = items[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSubCategoryId = sub.id;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sub.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF344054),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Форматирование монет: 25000 → 25k, 1500 → 1.5k
  String _formatCoins(int coins) {
    if (coins >= 1000) {
      final k = coins / 1000;
      final formatted = k.toStringAsFixed(1);
      // Убираем трейлинг ".0" → 25.0 → 25
      final clean = formatted.endsWith('.0')
          ? formatted.substring(0, formatted.length - 2)
          : formatted;
      return '${clean}k';
    }
    return '$coins';
  }

  /// Секция «Количество монет» с балансом пользователя
  Widget _buildCoinSection() {
    final profileAsync = ref.watch(getProfileInfoProvider);
    final userCoins = profileAsync.value?.money ?? 0;
    final coinOptions = [6, 12, 18, 24];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F7FF), Color(0xFFF8FAFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1E9FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E90FA).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('battle_coins_amount'.tr()),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E90FA).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/battle/coinfull.png', height: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatCoins(userCoins),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E90FA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: coinOptions.asMap().entries.map((entry) {
              final i = entry.key;
              final coins = entry.value;
              final isSelected = _selectedCoins == coins;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCoins = coins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: i < coinOptions.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : const Color(0xFFE4E7EC),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: const Color(
                              0xFF2E90FA,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$coins',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF344054),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Image.asset(
                          'assets/images/battle/coinfull.png',
                          height: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreate() async {
    // ── Premium check ──
    final profileAsync = ref.read(getProfileInfoProvider);
    final isPremium = profileAsync.value?.userType == 'pre';
    if (!isPremium) {
      _showPremiumDialog();
      return;
    }

    // Energy gate — block battle entry if the user has drained their balance.
    // Premium users pass through since canPlay() returns true for them.
    final canPlay = ref.read(energyProvider.notifier).canPlay();
    if (!canPlay) {
      if (context.mounted) {
        await showEnergyPaywallDialog(context);
      }
      return;
    }

    setState(() => _isCreating = true);

    // Проверить, скачан ли курс выбранной категории
    final hasRes = await CategoryResourceService.hasResources(
      _selectedCategoryId,
    );
    if (!hasRes) {
      // Найти CategoryFlutterDto
      final catDto = _categories.cast<CategoryFlutterDto?>().firstWhere(
        (c) => c!.id == _selectedCategoryId,
        orElse: () => null,
      );

      if (catDto != null && mounted) {
        // Показать диалог скачивания
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => BattleDownloadDialog(category: catDto),
        );

        // Проверить ещё раз после скачивания
        final downloaded = await CategoryResourceService.hasResources(
          _selectedCategoryId,
        );
        if (!downloaded) {
          if (mounted) setState(() => _isCreating = false);
          return; // Скачивание отменено
        }
      } else {
        if (mounted) setState(() => _isCreating = false);
        return;
      }
    }

    // Загрузить случайные ID слов из категории (как в Unity GetRandomWordFromCategory)
    // Эти ID отправляются на сервер и broadcast-ятся всем игрокам при start_game
    final randomWordIds = await CategoryDbHelper.getRandomWordIds(
      _selectedCategoryId,
      _wordsCount,
    );

    if (randomWordIds.isEmpty) {
      debugPrint(
        '⚠️ Не удалось загрузить слова для категории $_selectedCategoryId',
      );
      if (mounted) setState(() => _isCreating = false);
      return;
    }

    final vm = ref.read(battleProvider.notifier);
    await vm.createRoom(
      questionsQuantity: _wordsCount,
      questionsCategoryId: _selectedCategoryId,
      questionsId: randomWordIds,
      moneyCount: _selectedCoins,
      gameDirectionMode: 'English',
      isPublic: _isPublic,
    );

    if (mounted) setState(() => _isCreating = false);
  }

  // ── Диалог для обычных пользователей ──
  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Frame.png', width: 120, height: 120),
              const SizedBox(height: 20),
              Text(
                'battle_premium_only'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MySubscriptionPage(),
                    ),
                  );
                },
                width: double.infinity,
                buttonColor: const Color(0xFFFDB022),
                backButtonColor: const Color(0xFFF79009),
                borderRadius: 14,
                child: Text(
                  'battle_buy_premium'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              MyButton(
                onPressed: () => Navigator.of(context).pop(),
                width: double.infinity,
                buttonColor: Colors.white,
                backButtonColor: const Color(0xFFD0D5DD),
                borderRadius: 14,
                border: 1.5,
                borderColor: const Color(0xFFD0D5DD),
                child: Text(
                  'battle_got_it'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
