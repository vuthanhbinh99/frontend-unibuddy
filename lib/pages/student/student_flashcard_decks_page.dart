import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/student_course_models.dart';
import '../../models/student_flashcard_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_flashcard_editors.dart';
import 'student_flashcard_manage_page.dart';
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
        widget.studentApi.listCourses(tatCa: true),
      ]);

      final deckData = results[0] as StudentFlashcardDeckData;
      final statsData = results[1] as StudentFlashcardStatisticsData;
      final courses = (results[2] as StudentCourseData).items;

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
          child: _AsymmetricDeckCard(
            deck: deck,
            index: index,
            color: color,
            onDelete: () => _confirmDeleteDeck(deck),
          ),
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

  Future<void> _confirmDeleteDeck(StudentFlashcardDeck deck) async {
    final colors = StudentThemeScope.colorsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Xóa bộ Flashcard', style: TextStyle(color: colors.text)),
        content: Text(
          'Bạn có chắc muốn xóa bộ "${deck.title}"? '
          'Toàn bộ ${deck.cardCount} thẻ và tiến độ ôn tập sẽ bị xóa vĩnh viễn.',
          style: TextStyle(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.studentApi.deleteFlashcardDeck(deck.id);
      if (!mounted) {
        return;
      }
      _showSnack('Đã xóa bộ "${deck.title}".');
      await _loadData(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Không thể xóa bộ Flashcard lúc này.');
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
  DateTime? _cardShownAt;
  String? _selectedQuizOption;
  bool _quizAnswered = false;
  final Map<String, int> _soLanLamLai = {};
  bool _sessionResultSent = false;
  bool _aiOverlayOpen = false;

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

  Future<void> _loadReview({bool silent = false, bool hocLai = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await widget.studentApi.startFlashcardReview(
        widget.deck.id,
        hocLai: hocLai,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = data.items;
        _currentIndex = 0;
        _isFlipped = false;
        _loading = false;
        _errorMessage = null;
        _soLanLamLai.clear();
        _sessionResultSent = false;
        _totalStudied = 0;
        _forgotCount = 0;
        _reviewCount = 0;
        _masteredCount = 0;
        _resetCardState();
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

  void _resetCardState() {
    _cardShownAt = DateTime.now();
    _selectedQuizOption = null;
    _quizAnswered = false;
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
            _requeueCard(card);
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
              if (card != null && !card.isQuiz)
                _buildControls()
              else
                const SizedBox.shrink(),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note_outlined),
              tooltip: 'Quản lý thẻ',
              onPressed: _openManageCards,
              style: IconButton.styleFrom(backgroundColor: colors.surfaceAlt),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              onPressed: _showStatsDialog,
              style: IconButton.styleFrom(backgroundColor: colors.surfaceAlt),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openManageCards() async {
    await Navigator.push<void>(
      context,
      studentThemedRoute(
        context: context,
        builder: (_) => StudentFlashcardManagePage(
          studentApi: widget.studentApi,
          deck: widget.deck,
          accentColor: widget.accentColor,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadReview(silent: true);
    await widget.onDeckChanged?.call();
  }

  Widget _buildImportPanel() {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      children: [
        GestureDetector(
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
                        'Nhấn để tải CSV/XLSX hoặc tạo nhanh với AI',
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
        ),
        _buildAiGenerateButton(),
      ],
    );
  }

  Widget _buildAiGenerateButton() {
    final colors = StudentThemeScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _addCardManually,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Nhập thủ công'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primaryStrong,
                side: BorderSide(
                  color: colors.primaryStrong.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _importCardsWithAi,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Import PDF/DOCX'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primaryStrong,
                side: BorderSide(
                  color: colors.primaryStrong.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
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

    if (card.isQuiz) {
      return _buildQuizFlipArea(card);
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

  Future<void> _handleQuizAnswer(
    StudentFlashcardCard card,
    String optionId,
  ) async {
    if (_quizAnswered || _savingProgress) {
      return;
    }
    final quiz = card.quizContent;
    if (quiz == null) {
      return;
    }

    final isCorrect = optionId == quiz.correctAnswer;
    final responseMs = _cardShownAt == null
        ? 0
        : DateTime.now().difference(_cardShownAt!).inMilliseconds;

    setState(() {
      _selectedQuizOption = optionId;
      _quizAnswered = true;
      _savingProgress = true;
    });

    try {
      await widget.studentApi.submitFlashcardResult(
        cardId: card.id,
        result: isCorrect
            ? StudentFlashcardResult.correct
            : StudentFlashcardResult.wrong,
        responseMs: responseMs,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _totalStudied++;
        if (isCorrect) {
          _masteredCount++;
        } else {
          _forgotCount++;
          _requeueCard(card);
        }
        _savingProgress = false;
      });
      // Lộ đáp án: tự động lật sang mặt sau sau khi đã chấm.
      if (!_isFlipped) {
        _flipController.forward();
        setState(() => _isFlipped = true);
      }
      await widget.onDeckChanged?.call();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _savingProgress = false);
        _showSnack(error.message);
      }
    }
  }

  Widget _buildQuizFlipArea(StudentFlashcardCard card) {
    return GestureDetector(
      // Chỉ cho phép lật thủ công sau khi đã trả lời (tránh xem trước đáp án).
      onTap: _quizAnswered ? _toggleFlip : null,
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
                    child: _buildQuizBack(card),
                  )
                : _buildQuizFront(card),
          );
        },
      ),
    );
  }

  Widget _buildQuizFront(StudentFlashcardCard card) {
    final colors = StudentThemeScope.colorsOf(context);
    final quiz = card.quizContent!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surfaceAlt.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: colors.primaryStrong),
                    const SizedBox(width: 8),
                    Text(
                      'TRẮC NGHIỆM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  quiz.question,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...quiz.options.map((option) => _buildQuizOption(card, quiz, option)),
          if (_quizAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nhấn vào thẻ để xem đáp án & giải thích',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: colors.textSubtle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizBack(StudentFlashcardCard card) {
    final quiz = card.quizContent!;
    return SingleChildScrollView(child: _buildQuizExplanation(quiz));
  }

  Widget _buildQuizOption(
    StudentFlashcardCard card,
    StudentFlashcardQuizContent quiz,
    StudentFlashcardQuizOption option,
  ) {
    final colors = StudentThemeScope.colorsOf(context);
    const correctColor = Color(0xFF4ADE80);
    const wrongColor = Color(0xFFFF6B6B);

    final isCorrectOption = option.id == quiz.correctAnswer;
    final isSelected = option.id == _selectedQuizOption;

    Color background = colors.surface;
    Color borderColor = colors.border;
    Color textColor = colors.text;
    IconData? trailingIcon;
    Color? iconColor;

    if (_quizAnswered) {
      if (isCorrectOption) {
        background = correctColor.withValues(alpha: 0.18);
        borderColor = correctColor;
        trailingIcon = Icons.check_circle;
        iconColor = correctColor;
      } else if (isSelected) {
        background = wrongColor.withValues(alpha: 0.16);
        borderColor = wrongColor;
        trailingIcon = Icons.cancel;
        iconColor = wrongColor;
      } else {
        textColor = colors.textMuted;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _quizAnswered || _savingProgress
            ? null
            : () => _handleQuizAnswer(card, option.id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  option.id,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: borderColor == colors.border
                        ? colors.textMuted
                        : borderColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: iconColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizExplanation(StudentFlashcardQuizContent quiz) {
    final colors = StudentThemeScope.colorsOf(context);
    final isCorrect = _selectedQuizOption == quiz.correctAnswer;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryStrong.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primaryStrong.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.emoji_events_outlined : Icons.lightbulb_outline,
                color: colors.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Chính xác!' : 'Đáp án đúng: ${quiz.correctAnswer}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.primaryStrong,
                ),
              ),
            ],
          ),
          if (quiz.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              quiz.explanation,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colors.text,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingProgress ? null : _nextCard,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                _currentIndex + 1 >= _cards.length
                    ? 'Hoàn thành'
                    : 'Câu tiếp theo',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryStrong,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
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
    final coHocThe = _totalStudied > 0;
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
            coHocThe
                ? 'Bạn đã ôn tập xong lượt học này. Kết quả của bạn:'
                : 'Bạn đã ôn tập xong tất cả các thẻ đang cần học trong bộ bài này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
          if (coHocThe) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StudyStatItem('Đúng', _masteredCount, const Color(0xFF4ADE80)),
                _StudyStatItem('Sai', _forgotCount, const Color(0xFFFF6B6B)),
                _StudyStatItem('Tổng', _totalStudied, colors.primaryStrong),
              ],
            ),
            if (_forgotCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryStrong.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primaryStrong.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: colors.primaryStrong,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Các thẻ làm sai đã được đưa lại để bạn ôn; '
                        'xem chi tiết ở chuông thông báo.',
                        style: TextStyle(color: colors.text, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

  void _showAiOverlay(String message) {
    if (_aiOverlayOpen) {
      return;
    }
    _aiOverlayOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colors = StudentThemeScope.colorsOf(context);
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.primaryStrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _closeAiOverlay() {
    if (!_aiOverlayOpen) {
      return;
    }
    _aiOverlayOpen = false;
    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _importCardsWithAi() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt', 'md'],
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

    if (!mounted) {
      return;
    }
    final loaiThe = await _showImportTypeSheet();
    if (loaiThe == null) {
      return;
    }
    final laTuLuan = loaiThe == StudentFlashcardCardType.essay;

    _showAiOverlay('AI đang phân tích tài liệu, vui lòng đợi…');

    try {
      final imported = laTuLuan
          ? await widget.studentApi.aiImportEssayFlashcards(
              deckId: widget.deck.id,
              bytes: bytes,
              fileName: file.name,
            )
          : await widget.studentApi.aiImportFlashcards(
              deckId: widget.deck.id,
              bytes: bytes,
              fileName: file.name,
            );
      _closeAiOverlay();
      if (!mounted) {
        return;
      }
      final total = imported.cards.isNotEmpty
          ? imported.cards.length
          : imported.importedCount;
      _showSnack(
        imported.message.isEmpty
            ? (laTuLuan
                  ? 'AI đã tạo $total thẻ tự luận.'
                  : 'AI đã tạo $total thẻ trắc nghiệm.')
            : imported.message,
      );
      await _loadReview(silent: true);
      await widget.onDeckChanged?.call();
    } on ApiException catch (error) {
      _closeAiOverlay();
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      _closeAiOverlay();
      if (mounted) {
        _showSnack('Không thể phân tích tài liệu lúc này.');
      }
    }
  }

  Future<StudentFlashcardCardType?> _showImportTypeSheet() {
    final colors = StudentThemeScope.colorsOf(context);
    return showModalBottomSheet<StudentFlashcardCardType>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
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
                  'Tạo thẻ dạng nào?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Chọn định dạng phù hợp với nội dung tài liệu bạn vừa tải lên.',
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                ),
                const SizedBox(height: 16),
                _buildImportTypeOption(
                  sheetContext: sheetContext,
                  colors: colors,
                  icon: Icons.quiz_outlined,
                  title: 'Trắc nghiệm',
                  subtitle: 'Câu hỏi nhiều lựa chọn có đáp án đúng',
                  value: StudentFlashcardCardType.quiz,
                ),
                const SizedBox(height: 10),
                _buildImportTypeOption(
                  sheetContext: sheetContext,
                  colors: colors,
                  icon: Icons.notes_outlined,
                  title: 'Tự luận',
                  subtitle: 'Thẻ hỏi - đáp dạng ghi nhớ nội dung',
                  value: StudentFlashcardCardType.essay,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportTypeOption({
    required BuildContext sheetContext,
    required StudentThemeColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required StudentFlashcardCardType value,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(sheetContext).pop(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
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
              child: Icon(icon, color: colors.primaryStrong),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _addCardManually() async {
    final type = await pickStudentFlashcardCardType(context);
    if (type == null || !mounted) {
      return;
    }

    try {
      if (type == StudentFlashcardCardType.essay) {
        final draft = await showStudentFlashcardEssayEditor(context);
        if (draft == null) {
          return;
        }
        await widget.studentApi.createFlashcard(
          deckId: widget.deck.id,
          front: draft.front,
          back: draft.back,
        );
      } else {
        final draft = await showStudentFlashcardQuizEditor(context);
        if (draft == null) {
          return;
        }
        await widget.studentApi.createQuizFlashcard(
          deckId: widget.deck.id,
          quiz: draft,
        );
      }

      if (!mounted) {
        return;
      }
      _showSnack('Đã thêm thẻ mới.');
      await _loadReview(silent: true);
      await widget.onDeckChanged?.call();
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Không thể thêm thẻ lúc này.');
      }
    }
  }

  void _requeueCard(StudentFlashcardCard card) {
    // Đưa thẻ làm sai quay lại cuối phiên; giới hạn mỗi thẻ tối đa 1 lần
    // để tránh phiên học kéo dài vô hạn khi liên tục trả lời sai.
    final soLan = _soLanLamLai[card.id] ?? 0;
    if (soLan >= 1) {
      return;
    }
    _soLanLamLai[card.id] = soLan + 1;
    _cards.add(card);
  }

  Future<void> _recordSessionResult() async {
    if (_sessionResultSent) {
      return;
    }
    // Không có gì để ghi khi chưa học thẻ nào.
    if (_masteredCount == 0 && _forgotCount == 0) {
      return;
    }
    _sessionResultSent = true;
    try {
      await widget.studentApi.recordFlashcardSessionResult(
        deckId: widget.deck.id,
        correct: _masteredCount,
        wrong: _forgotCount,
      );
      await widget.onDeckChanged?.call();
    } catch (_) {
      // Ghi kết quả phiên là best-effort; không chặn trải nghiệm học.
      _sessionResultSent = false;
    }
  }

  void _nextCard() {
    if (_isFlipped) {
      _flipController.reset();
      _isFlipped = false;
    }

    setState(() {
      _currentIndex++;
      _resetCardState();
    });

    if (_currentIndex >= _cards.length) {
      _showSnack('Chúc mừng! Bạn đã hoàn thành lượt học bộ thẻ này.');
      _recordSessionResult();
    }
  }

  Future<void> _restartDeck() async {
    // Tải lại toàn bộ thẻ của bộ (kể cả khi 0 thẻ tới hạn) rồi học lại từ đầu.
    await _loadReview(hocLai: true);
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
    this.onDelete,
  });

  final StudentFlashcardDeck deck;
  final int index;
  final Color color;
  final VoidCallback? onDelete;

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
              if (onDelete != null)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Tùy chọn',
                    color: colors.surface,
                    icon: Icon(
                      _iconForDeck(deck),
                      color: colors.textSubtle,
                      size: 18,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: colors.danger,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Xóa bộ',
                              style: TextStyle(color: colors.danger),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
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
