part of 'student_flashcard_decks_page.dart';

extension _StudentFlashcardStudyActions on _StudentFlashcardStudyPageState {
  /// Xử lý thao tác import cards và đồng bộ kết quả với UI.
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

  /// Hiển thị hoặc mở phần giao diện show ai overlay cho người dùng.
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

  /// Hàm hỗ trợ close ai overlay cho màn hình trong file này.
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

  /// Xử lý thao tác import cards with ai và đồng bộ kết quả với UI.
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

  /// Hiển thị hoặc mở phần giao diện show import type sheet cho người dùng.
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

  /// Dựng phần giao diện build import type option cho màn hình hiện tại.
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

  /// Xử lý thao tác add card manually và đồng bộ kết quả với UI.
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

  /// Hàm hỗ trợ requeue card cho màn hình trong file này.
  void _requeueCard(StudentFlashcardCard card) {
    // Trong phiên học, thẻ chưa thuộc quay lại cuối hàng đợi để ôn ngay,
    // còn lịch ôn dài hạn vẫn do SM-2 phía backend quyết định.
    _sessionQueue.add(card);
  }

  /// Xử lý thao tác record session result và đồng bộ kết quả với UI.
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

  /// Hàm hỗ trợ next card cho màn hình trong file này.
  void _nextCard() {
    if (_isFlipped) {
      _flipController.reset();
      _isFlipped = false;
    }

    final currentCard = _currentCard;
    if (currentCard == null) {
      return;
    }
    final shouldRequeue =
        _sessionQueue.length > 1 && identical(_sessionQueue.last, currentCard);

    _updateStudyState(() {
      _sessionQueue.removeAt(0);
      if (!shouldRequeue) {
        _completedUniqueCardCount++;
      }
      _resetCardState();
    });

    if (_sessionQueue.isEmpty) {
      _showSnack('Chúc mừng! Bạn đã hoàn thành lượt học bộ thẻ này.');
      _recordSessionResult();
    }
  }

  /// Thực hiện tác vụ bất đồng bộ restart deck cho màn hình hiện tại.
  Future<void> _restartDeck() async {
    // Tải lại toàn bộ thẻ của bộ (kể cả khi 0 thẻ tới hạn) rồi học lại từ đầu.
    await _loadReview(hocLai: true);
  }

  /// Hiển thị hoặc mở phần giao diện show stats dialog cho người dùng.
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
                    'Lượt học',
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

  /// Hiển thị hoặc mở phần giao diện show snack cho người dùng.
  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
