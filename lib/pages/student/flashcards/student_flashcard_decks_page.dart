import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../models/student_course_models.dart';
import '../../../models/student_flashcard_models.dart';
import '../../../services/api/core/api_exception.dart';
import '../../../services/api/modules/student/student_api_service.dart';
import 'student_flashcard_editors.dart';
import 'student_flashcard_manage_page.dart';
import '../theme/student_theme.dart';
import '../widgets/student_notification_dropdown.dart';
part 'student_flashcard_study_page.dart';
part 'student_flashcard_study_widgets.dart';
part 'student_flashcard_study_actions.dart';

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
