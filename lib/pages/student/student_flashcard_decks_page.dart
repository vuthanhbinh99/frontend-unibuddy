import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/student_course_models.dart';
import '../../models/student_flashcard_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentFlashcardDecksPage extends StatefulWidget {
  const StudentFlashcardDecksPage({
    super.key,
    required this.studentApi,
    this.courses = const [],
    this.onViewAllNotifications,
  });

  final StudentApiService studentApi;
  final List<StudentCourseItem> courses;
  final VoidCallback? onViewAllNotifications;

  @override
  State<StudentFlashcardDecksPage> createState() =>
      _StudentFlashcardDecksPageState();
}

class _StudentFlashcardDecksPageState extends State<StudentFlashcardDecksPage> {
  final List<Color> _deckColors = const [
    Color(0xFF89CEFF),
    Color(0xFFFFAFD3),
    Color(0xFF00A2E6),
    Color(0xFFFFAFDB),
  ];

  bool _loading = true;
  String? _errorMessage;
  String? _selectedCourseId;
  List<StudentFlashcardDeck> _decks = [];
  List<StudentCourseItem> _courses = [];
  StudentFlashcardStatistics? _statistics;

  @override
  void initState() {
    super.initState();
    _courses = widget.courses;
    _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        widget.studentApi.listFlashcardDecks(courseId: _selectedCourseId),
        widget.studentApi.getFlashcardStatistics(),
        if (_courses.isEmpty) widget.studentApi.listCourses(),
      ]);

      final deckData = results[0] as StudentFlashcardDeckData;
      final statsData = results[1] as StudentFlashcardStatisticsData;
      final courses = results.length > 2
          ? (results[2] as StudentCourseData).items
          : _courses;

      if (!mounted) {
        return;
      }

      setState(() {
        _decks = deckData.items;
        _statistics = statsData.statistics;
        _courses = courses;
        _loading = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'Không thể tải bộ Flashcard lúc này.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadData(silent: true),
          color: colors.primary,
          backgroundColor: colors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                Text(
                  'CHẾ ĐỘ HỌC TẬP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bộ thẻ của bạn',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 14),
                _buildStatisticsStrip(),
                const SizedBox(height: 20),
                _buildFilters(),
                const SizedBox(height: 24),
                _buildDeckGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(
                backgroundColor: colors.surface,
                shape: const CircleBorder(),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Bộ flashcard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
          ],
        ),
        StudentNotificationBell(
          studentApi: widget.studentApi,
          onViewAll: widget.onViewAllNotifications,
          iconColor: colors.text,
          backgroundColor: colors.surface,
          dotColor: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildStatisticsStrip() {
    final colors = StudentThemeScope.colorsOf(context);
    final stats = _statistics;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _DeckStatTile(
            label: 'Bộ',
            value: '${stats?.totalDecks ?? _decks.length}',
            color: colors.primaryStrong,
          ),
          _DeckStatTile(
            label: 'Thẻ',
            value:
                '${stats?.totalCards ?? _decks.fold<int>(0, (v, d) => v + d.cardCount)}',
            color: colors.info,
          ),
          _DeckStatTile(
            label: 'Cần ôn',
            value:
                '${stats?.dueToday ?? _decks.fold<int>(0, (v, d) => v + d.dueCount)}',
            color: const Color(0xFFFFD166),
          ),
          _DeckStatTile(
            label: 'Thuộc',
            value: '${(stats?.masteryRate ?? _averageProgress()).round()}%',
            color: const Color(0xFF4ADE80),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final colors = StudentThemeScope.colorsOf(context);
    final filters = <_DeckFilter>[
      const _DeckFilter(label: 'Tất cả'),
      ..._courses.map(
        (course) => _DeckFilter(
          label: course.code == null || course.code!.trim().isEmpty
              ? course.name
              : course.code!.trim(),
          courseId: course.id,
        ),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedCourseId == filter.courseId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCourseId = filter.courseId);
                _loadData();
              },
              selectedColor: colors.primaryStrong,
              labelStyle: TextStyle(
                color: isSelected ? colors.onPrimary : colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeckGrid() {
    final colors = StudentThemeScope.colorsOf(context);
    if (_loading) {
      return SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _DeckErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    if (_decks.isEmpty) {
      return _DeckEmptyState(onCreate: _openCreateDeckSheet);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemCount: _decks.length,
      itemBuilder: (context, index) {
        final deck = _decks[index];
        final color =
            _deckColors[stableDeckColorIndex(deck, index) % _deckColors.length];
        return GestureDetector(
          onTap: () => _openStudy(deck, color),
          child: _AsymmetricDeckCard(deck: deck, index: index, color: color),
        );
      },
    );
  }

  Future<void> _openStudy(StudentFlashcardDeck deck, Color color) async {
    await Navigator.push<void>(
      context,
      studentThemedRoute(
        context: context,
        builder: (_) => StudentFlashcardStudyPage(
          studentApi: widget.studentApi,
          deck: deck,
          accentColor: color,
          onDeckChanged: () => _loadData(silent: true),
        ),
      ),
    );
    if (mounted) {
      _loadData(silent: true);
    }
  }

  Future<void> _openCreateDeckSheet() async {
    final colors = StudentThemeScope.colorsOf(context);
    final draft = await showModalBottomSheet<_DeckDraft>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CreateDeckSheet(courses: _courses),
    );

    if (draft == null) {
      return;
    }

    try {
      await widget.studentApi.createFlashcardDeck(
        title: draft.title,
        courseId: draft.courseId,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Đã tạo bộ Flashcard.');
      await _loadData(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  double _averageProgress() {
    if (_decks.isEmpty) {
      return 0;
    }
    final total = _decks.fold<double>(
      0,
      (value, deck) => value + deck.progressPercent,
    );
    return (total / _decks.length) * 100;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class StudentFlashcardStudyPage extends StatefulWidget {
  const StudentFlashcardStudyPage({
    super.key,
    required this.studentApi,
    required this.deck,
    required this.accentColor,
    this.onDeckChanged,
  });

  final StudentApiService studentApi;
  final StudentFlashcardDeck deck;
  final Color accentColor;
  final Future<void> Function()? onDeckChanged;

  @override
  State<StudentFlashcardStudyPage> createState() =>
      _StudentFlashcardStudyPageState();
}

class _StudentFlashcardStudyPageState extends State<StudentFlashcardStudyPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  List<StudentFlashcardCard> _cards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _loading = true;
  bool _savingProgress = false;
  String? _errorMessage;
  int _totalStudied = 0;
  int _forgotCount = 0;
  int _reviewCount = 0;
  int _masteredCount = 0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadReview();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  StudentFlashcardCard? get _currentCard {
    if (_currentIndex < 0 || _currentIndex >= _cards.length) {
      return null;
    }
    return _cards[_currentIndex];
  }

  double get _progressPercent {
    if (_cards.isEmpty) {
      return 0;
    }
    return (_currentIndex / _cards.length).clamp(0, 1).toDouble();
  }

  Future<void> _loadReview({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await widget.studentApi.startFlashcardReview(widget.deck.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = data.items;
        _currentIndex = 0;
        _isFlipped = false;
        _loading = false;
        _errorMessage = null;
      });
      _flipController.reset();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'Không thể tải phiên ôn tập lúc này.';
      });
    }
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _handleAction(StudentFlashcardMemoryLevel level) async {
    final card = _currentCard;
    if (card == null || _savingProgress) {
      return;
    }

    setState(() => _savingProgress = true);
    try {
      await widget.studentApi.updateFlashcardProgress(
        cardId: card.id,
        memoryLevel: level,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _totalStudied++;
        switch (level) {
          case StudentFlashcardMemoryLevel.forgot:
            _forgotCount++;
            break;
          case StudentFlashcardMemoryLevel.review:
            _reviewCount++;
            break;
          case StudentFlashcardMemoryLevel.mastered:
            _masteredCount++;
            break;
        }
        _savingProgress = false;
      });

      _nextCard();
      await widget.onDeckChanged?.call();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _savingProgress = false);
        _showSnack(error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _currentCard;
    final colors = StudentThemeScope.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildImportPanel(),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progressPercent,
                  backgroundColor: colors.surfaceAlt,
                  color: colors.primaryStrong,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildCardArea(card)),
              const SizedBox(height: 24),
              if (card != null) _buildControls() else const SizedBox.shrink(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(backgroundColor: colors.surfaceAlt),
        ),
        Text(
          'Thẻ Flashcard ôn tập',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          onPressed: _showStatsDialog,
          style: IconButton.styleFrom(backgroundColor: colors.surfaceAlt),
        ),
      ],
    );
  }

  Widget _buildImportPanel() {
    final colors = StudentThemeScope.colorsOf(context);
    return GestureDetector(
      onTap: _importCards,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryStrong.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.file_upload_outlined,
                color: colors.primaryStrong,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BỘ BÀI: ${widget.deck.title.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryStrong,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nhấn để tải CSV/XLSX...',
                    style: TextStyle(fontSize: 14, color: colors.text),
                  ),
                ],
              ),
            ),
            Text(
              'Thẻ ${_cards.isEmpty ? 0 : (_currentIndex < _cards.length ? _currentIndex + 1 : _cards.length)} / ${_cards.length}',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardArea(StudentFlashcardCard? card) {
    final colors = StudentThemeScope.colorsOf(context);
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
        ),
      );
    }

    if (_errorMessage != null) {
      return _DeckErrorState(message: _errorMessage!, onRetry: _loadReview);
    }

    if (card == null) {
      return _buildCompletedState();
    }

    return Center(
      child: GestureDetector(
        onTap: _toggleFlip,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * math.pi;
            final isBack = angle > math.pi / 2;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: isBack
                  ? Transform(
                      transform: Matrix4.identity()..rotateY(math.pi),
                      alignment: Alignment.center,
                      child: _buildCardSide(
                        title: 'Định nghĩa',
                        content: card.back,
                        isBackSide: true,
                      ),
                    )
                  : _buildCardSide(
                      title: 'Câu hỏi / Khái niệm',
                      content: card.front,
                      isBackSide: false,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardSide({
    required String title,
    required String content,
    required bool isBackSide,
  }) {
    final colors = StudentThemeScope.colorsOf(context);
    final frontSurface = colors.surfaceAlt.withValues(alpha: 0.9);
    final backSurface = colors.primaryStrong;
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: isBackSide ? backSurface : frontSurface,
        borderRadius: isBackSide
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(32),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(12),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(24),
              ),
        border: Border.all(
          color: isBackSide ? colors.inverseOverlay(0.3) : colors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                isBackSide
                    ? Icons.check_circle_outline
                    : Icons.psychology_outlined,
                color: isBackSide ? colors.onPrimary : colors.primaryStrong,
              ),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: isBackSide ? colors.onPrimary : colors.textMuted,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: isBackSide ? colors.onPrimary : colors.text,
                  ),
                ),
              ),
            ),
          ),
          Text(
            isBackSide ? 'Nhấn để quay lại' : 'Nhấn để lật xem định nghĩa',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              color: isBackSide
                  ? colors.onPrimary.withValues(alpha: 0.7)
                  : colors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: colors.primaryStrong, size: 56),
          const SizedBox(height: 16),
          Text(
            'Hoàn Thành Bộ Bài!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn đã ôn tập xong tất cả các thẻ đang cần học trong bộ bài này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _restartDeck,
            icon: const Icon(Icons.replay),
            label: const Text('Học lại bộ bài'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryStrong,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Quên',
            icon: Icons.close,
            color: const Color(0xFFFFB4AB),
            bgColor: const Color(0xFF93000A).withValues(alpha: 0.2),
            onTap: () => _handleAction(StudentFlashcardMemoryLevel.forgot),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Ôn tập',
            icon: Icons.rotate_left,
            color: Colors.amber,
            bgColor: Colors.amber.withValues(alpha: 0.15),
            onTap: () => _handleAction(StudentFlashcardMemoryLevel.review),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Đã thuộc',
            icon: Icons.check,
            color: const Color(0xFF4ADE80),
            bgColor: const Color(0xFF4ADE80).withValues(alpha: 0.15),
            onTap: () => _handleAction(StudentFlashcardMemoryLevel.mastered),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _savingProgress ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            if (_savingProgress)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCards() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Không thể đọc nội dung file đã chọn.');
      return;
    }

    try {
      final imported = await widget.studentApi.importFlashcards(
        deckId: widget.deck.id,
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) {
        return;
      }
      _showSnack(
        imported.message.isEmpty
            ? 'Đã import ${imported.importedCount} thẻ.'
            : imported.message,
      );
      await _loadReview(silent: true);
      await widget.onDeckChanged?.call();
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  void _nextCard() {
    if (_isFlipped) {
      _flipController.reverse();
      _isFlipped = false;
    }

    setState(() {
      _currentIndex++;
    });

    if (_currentIndex >= _cards.length) {
      _showSnack('Chúc mừng! Bạn đã hoàn thành lượt học bộ thẻ này.');
    }
  }

  void _restartDeck() {
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
    });
    _flipController.reset();
  }

  void _showStatsDialog() {
    final colors = StudentThemeScope.colorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thống kê học tập',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StudyStatItem(
                    'Tổng số',
                    _totalStudied,
                    colors.primaryStrong,
                  ),
                  _StudyStatItem('Quên', _forgotCount, Colors.redAccent),
                  _StudyStatItem('Ôn tập', _reviewCount, Colors.amber),
                  _StudyStatItem(
                    'Đã thuộc',
                    _masteredCount,
                    const Color(0xFF4ADE80),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceAlt,
                  foregroundColor: colors.text,
                ),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _AsymmetricDeckCard extends StatelessWidget {
  const _AsymmetricDeckCard({
    required this.deck,
    required this.index,
    required this.color,
  });

  final StudentFlashcardDeck deck;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final borderRadius = switch (index % 4) {
      0 => const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(8),
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(24),
      ),
      1 => const BorderRadius.only(
        topLeft: Radius.circular(8),
        topRight: Radius.circular(32),
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(32),
      ),
      2 => const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(32),
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(32),
      ),
      _ => const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(24),
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(8),
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: borderRadius,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  deck.codeLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(_iconForDeck(deck), color: colors.textSubtle, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deck.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${deck.cardCount} Thẻ • ${deck.dueCount} cần ôn',
                style: TextStyle(fontSize: 11, color: colors.textSubtle),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: deck.progressPercent.clamp(0, 1),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForDeck(StudentFlashcardDeck deck) {
    final code = deck.codeLabel;
    if (code.startsWith('CS') || code.startsWith('IT')) {
      return Icons.terminal;
    }
    if (code.startsWith('BIO')) {
      return Icons.science;
    }
    if (code.startsWith('MATH')) {
      return Icons.functions;
    }
    return Icons.menu_book_outlined;
  }
}

class _DeckFilter {
  const _DeckFilter({required this.label, this.courseId});

  final String label;
  final String? courseId;
}

class _DeckStatTile extends StatelessWidget {
  const _DeckStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: colors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StudyStatItem extends StatelessWidget {
  const _StudyStatItem(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: colors.textMuted)),
      ],
    );
  }
}

class _DeckEmptyState extends StatelessWidget {
  const _DeckEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.style_outlined, color: colors.primaryStrong, size: 44),
          const SizedBox(height: 12),
          Text(
            'Chưa có bộ Flashcard',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo bộ đầu tiên rồi import CSV/XLSX để bắt đầu ôn tập.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Tạo bộ Flashcard'),
          ),
        ],
      ),
    );
  }
}

class _DeckErrorState extends StatelessWidget {
  const _DeckErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: colors.danger, size: 34),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateDeckSheet extends StatefulWidget {
  const _CreateDeckSheet({required this.courses});

  final List<StudentCourseItem> courses;

  @override
  State<_CreateDeckSheet> createState() => _CreateDeckSheetState();
}

class _CreateDeckSheetState extends State<_CreateDeckSheet> {
  final TextEditingController _titleController = TextEditingController();
  String? _selectedCourseId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Tạo bộ Flashcard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            style: TextStyle(color: colors.text),
            decoration: const InputDecoration(labelText: 'Tên bộ'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _selectedCourseId,
            dropdownColor: colors.surface,
            style: TextStyle(color: colors.text),
            decoration: const InputDecoration(labelText: 'Học phần'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Không gắn học phần'),
              ),
              ...widget.courses.map(
                (course) => DropdownMenuItem<String?>(
                  value: course.id,
                  child: Text(
                    course.code == null || course.code!.trim().isEmpty
                        ? course.name
                        : '${course.code} - ${course.name}',
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedCourseId = value),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Tạo bộ'),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên bộ Flashcard không được để trống.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _DeckDraft(title: title, courseId: _selectedCourseId),
    );
  }
}

class _DeckDraft {
  const _DeckDraft({required this.title, required this.courseId});

  final String title;
  final String? courseId;
}
