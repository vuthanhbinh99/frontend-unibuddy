import 'package:flutter/material.dart';
import '../../../models/student_flashcard_models.dart';
import '../../../services/api/core/api_exception.dart';
import '../../../services/api/modules/student/student_api_service.dart';
import 'student_flashcard_editors.dart';
import '../theme/student_theme.dart';

/// Màn hình quản lý thẻ trong một bộ flashcard: xem danh sách, thêm, sửa, xóa
/// từng thẻ (hỗ trợ cả thẻ tự luận và trắc nghiệm).
class StudentFlashcardManagePage extends StatefulWidget {
  const StudentFlashcardManagePage({
    super.key,
    required this.studentApi,
    required this.deck,
    required this.accentColor,
  });

  final StudentApiService studentApi;
  final StudentFlashcardDeck deck;
  final Color accentColor;

  @override
  State<StudentFlashcardManagePage> createState() =>
      _StudentFlashcardManagePageState();
}

class _StudentFlashcardManagePageState
    extends State<StudentFlashcardManagePage> {
  List<StudentFlashcardCard> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  /// Tải hoặc lấy dữ liệu load cards để cập nhật UI.
  Future<void> _loadCards({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final data = await widget.studentApi.listAllFlashcards(widget.deck.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _cards = data.items;
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
        _errorMessage = 'Không thể tải danh sách thẻ lúc này.';
      });
    }
  }

  /// Hiển thị hoặc mở phần giao diện show snack cho người dùng.
  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Xử lý thao tác add card và đồng bộ kết quả với UI.
  Future<void> _addCard() async {
    final type = await pickStudentFlashcardCardType(context);
    if (type == null || !mounted) {
      return;
    }
    if (type == StudentFlashcardCardType.essay) {
      final draft = await showStudentFlashcardEssayEditor(context);
      if (draft == null) {
        return;
      }
      await _runMutation(() async {
        await widget.studentApi.createFlashcard(
          deckId: widget.deck.id,
          front: draft.front,
          back: draft.back,
        );
      }, 'Đã thêm thẻ tự luận.');
    } else {
      final draft = await showStudentFlashcardQuizEditor(context);
      if (draft == null) {
        return;
      }
      await _runMutation(() async {
        await widget.studentApi.createQuizFlashcard(
          deckId: widget.deck.id,
          quiz: draft,
        );
      }, 'Đã thêm thẻ trắc nghiệm.');
    }
  }

  /// Xử lý thao tác edit card và đồng bộ kết quả với UI.
  Future<void> _editCard(StudentFlashcardCard card) async {
    if (card.isQuiz) {
      final draft = await showStudentFlashcardQuizEditor(context, card: card);
      if (draft == null) {
        return;
      }
      await _runMutation(() async {
        await widget.studentApi.updateQuizFlashcard(
          cardId: card.id,
          quiz: draft,
        );
      }, 'Đã cập nhật thẻ trắc nghiệm.');
    } else {
      final draft = await showStudentFlashcardEssayEditor(context, card: card);
      if (draft == null) {
        return;
      }
      await _runMutation(() async {
        await widget.studentApi.updateFlashcard(
          cardId: card.id,
          front: draft.front,
          back: draft.back,
        );
      }, 'Đã cập nhật thẻ.');
    }
  }

  /// Xử lý thao tác delete card và đồng bộ kết quả với UI.
  Future<void> _deleteCard(StudentFlashcardCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = StudentThemeScope.colorsOf(dialogContext);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Xóa thẻ này?', style: TextStyle(color: colors.text)),
          content: Text(
            'Thẻ đã xóa không thể khôi phục.',
            style: TextStyle(color: colors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runMutation(() async {
      await widget.studentApi.deleteFlashcard(card.id);
    }, 'Đã xóa thẻ.');
  }

  /// Thực hiện tác vụ bất đồng bộ run mutation cho màn hình hiện tại.
  Future<void> _runMutation(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      await _loadCards(silent: true);
      _showSnack(successMessage);
    } on ApiException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Thao tác thất bại, vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.text,
        title: Text(
          'Quản lý thẻ',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addCard,
        backgroundColor: colors.primaryStrong,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Thêm thẻ'),
      ),
      body: SafeArea(child: _buildBody(colors)),
    );
  }

  /// Dựng phần giao diện build body cho màn hình hiện tại.
  Widget _buildBody(StudentThemeColors colors) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.textMuted, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _loadCards, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    if (_cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined, color: colors.textMuted, size: 44),
            const SizedBox(height: 12),
            Text(
              'Bộ này chưa có thẻ nào.',
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Nhấn "Thêm thẻ" để bắt đầu.',
              style: TextStyle(color: colors.textSubtle, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCards,
      color: colors.primaryStrong,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _buildCardTile(colors, _cards[index], index);
        },
      ),
    );
  }

  /// Dựng phần giao diện build card tile cho màn hình hiện tại.
  Widget _buildCardTile(
    StudentThemeColors colors,
    StudentFlashcardCard card,
    int index,
  ) {
    final isQuiz = card.isQuiz;
    final title = card.front.trim().isEmpty
        ? '(Chưa có nội dung)'
        : card.front.trim();
    final subtitle = isQuiz
        ? '${card.quizContent?.options.length ?? 0} lựa chọn · Đáp án ${card.quizContent?.correctAnswer ?? '-'}'
        : (card.back.trim().isEmpty ? '(Chưa có mặt sau)' : card.back.trim());

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isQuiz ? Colors.orange : colors.primaryStrong).withValues(
                alpha: 0.16,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isQuiz ? 'TN' : 'TL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isQuiz ? Colors.orange.shade800 : colors.primaryStrong,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. $title',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            icon: Icon(Icons.more_vert, color: colors.textMuted),
            onSelected: (value) {
              if (value == 'edit') {
                _editCard(card);
              } else if (value == 'delete') {
                _deleteCard(card);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Sửa')),
              PopupMenuItem(value: 'delete', child: Text('Xóa')),
            ],
          ),
        ],
      ),
    );
  }
}
