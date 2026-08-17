part of 'student_flashcard_decks_page.dart';

extension _StudentFlashcardStudyWidgets on _StudentFlashcardStudyPageState {
  /// Dựng phần giao diện build header cho màn hình hiện tại.
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

  /// Hiển thị hoặc mở phần giao diện open manage cards cho người dùng.
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

  /// Dựng phần giao diện build import panel cho màn hình hiện tại.
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
                  'Còn ${_sessionQueue.length} / $_initialSessionCardCount',
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

  /// Dựng phần giao diện build ai generate button cho màn hình hiện tại.
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

  /// Dựng phần giao diện build card area cho màn hình hiện tại.
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

  /// Xử lý sự kiện handle quiz answer từ người dùng hoặc hệ thống.
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

    _updateStudyState(() {
      _selectedQuizOption = optionId;
      _quizAnswered = true;
      _savingProgress = true;
    });

    try {
      await _syncQuizResult(card, isCorrect, responseMs);
      if (!mounted) {
        return;
      }
      _updateStudyState(() {
        _totalStudied++;
        if (isCorrect) {
          _masteredCount++;
        } else {
          _forgotCount++;
          _requeueCard(card);
        }
        _savingProgress = false;
      });
      await widget.onDeckChanged?.call();
    } on ApiException catch (error) {
      if (mounted) {
        _updateStudyState(() => _savingProgress = false);
        _showSnack(error.message);
      }
    }
  }

  /// Dựng phần giao diện build quiz flip area cho màn hình hiện tại.
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

  /// Dựng phần giao diện build quiz front cho màn hình hiện tại.
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

  /// Dựng phần giao diện build quiz back cho màn hình hiện tại.
  Widget _buildQuizBack(StudentFlashcardCard card) {
    final quiz = card.quizContent!;
    return SingleChildScrollView(child: _buildQuizExplanation(quiz));
  }

  /// Dựng phần giao diện build quiz option cho màn hình hiện tại.
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
                  style: TextStyle(fontSize: 15, color: textColor, height: 1.3),
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

  /// Dựng phần giao diện build quiz explanation cho màn hình hiện tại.
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
                isCorrect
                    ? Icons.emoji_events_outlined
                    : Icons.lightbulb_outline,
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
              style: TextStyle(fontSize: 14, height: 1.4, color: colors.text),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingProgress ? null : _nextCard,
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                _sessionQueue.length <= 1 ? 'Hoàn thành' : 'Câu tiếp theo',
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

  /// Dựng phần giao diện build card side cho màn hình hiện tại.
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

  /// Dựng phần giao diện build completed state cho màn hình hiện tại.
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
            Wrap(
              alignment: WrapAlignment.spaceAround,
              runSpacing: 14,
              spacing: 12,
              children: [
                _StudyStatItem('Quên', _forgotCount, const Color(0xFFFF6B6B)),
                _StudyStatItem('Ôn tập', _reviewCount, Colors.amber),
                _StudyStatItem(
                  'Đã thuộc',
                  _masteredCount,
                  const Color(0xFF4ADE80),
                ),
                _StudyStatItem('Lượt', _totalStudied, colors.primaryStrong),
              ],
            ),
            if (_forgotCount > 0 || _reviewCount > 0) ...[
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
                        'Các thẻ Quên hoặc Ôn tập đã được đưa lại cuối phiên. '
                        'Lịch ôn dài hạn sẽ được SM-2 tự động cập nhật.',
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

  /// Dựng phần giao diện build controls cho màn hình hiện tại.
  Widget _buildControls() {
    final colors = StudentThemeScope.colorsOf(context);

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Quên',
            icon: Icons.close,
            color: colors.danger,
            bgColor: colors.tint(
              colors.danger,
              lightAlpha: 0.12,
              darkAlpha: 0.18,
            ),
            onTap: () => _handleAction(StudentFlashcardMemoryLevel.forgot),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Ôn tập',
            icon: Icons.rotate_left,
            color: colors.warning,
            bgColor: colors.tint(
              colors.warning,
              lightAlpha: 0.14,
              darkAlpha: 0.18,
            ),
            onTap: () => _handleAction(StudentFlashcardMemoryLevel.review),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'Đã thuộc',
            icon: Icons.check,
            color: colors.success,
            bgColor: colors.tint(
              colors.success,
              lightAlpha: 0.12,
              darkAlpha: 0.18,
            ),
            onTap: () => _handleAction(StudentFlashcardMemoryLevel.mastered),
          ),
        ),
      ],
    );
  }

  /// Dựng phần giao diện build action button cho màn hình hiện tại.
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    final colors = StudentThemeScope.colorsOf(context);
    return InkWell(
      onTap: _savingProgress ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: colors.isLight ? 0.40 : 0.25),
            width: 1.2,
          ),
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
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
