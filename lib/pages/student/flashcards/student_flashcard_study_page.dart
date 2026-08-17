part of 'student_flashcard_decks_page.dart';

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
  final List<StudentFlashcardCard> _sessionQueue = [];
  int _initialSessionCardCount = 0;
  int _completedUniqueCardCount = 0;
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
  final Set<String> _cardsPenalizedThisSession = {};
  bool _sessionResultSent = false;
  bool _aiOverlayOpen = false;

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
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

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  /// Xử lý thao tác update study state và đồng bộ kết quả với UI.
  void _updateStudyState(VoidCallback fn) {
    setState(fn);
  }

  StudentFlashcardCard? get _currentCard {
    if (_sessionQueue.isEmpty) {
      return null;
    }
    return _sessionQueue.first;
  }

  double get _progressPercent {
    if (_initialSessionCardCount == 0) {
      return 0;
    }
    return (_completedUniqueCardCount / _initialSessionCardCount)
        .clamp(0, 1)
        .toDouble();
  }

  /// Tải hoặc lấy dữ liệu load review để cập nhật UI.
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
        _sessionQueue
          ..clear()
          ..addAll(data.items);
        _initialSessionCardCount = data.items.length;
        _completedUniqueCardCount = 0;
        _isFlipped = false;
        _loading = false;
        _errorMessage = null;
        _sessionResultSent = false;
        _totalStudied = 0;
        _forgotCount = 0;
        _reviewCount = 0;
        _masteredCount = 0;
        _cardsPenalizedThisSession.clear();
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

  /// Xử lý thao tác reset card state và đồng bộ kết quả với UI.
  void _resetCardState() {
    _cardShownAt = DateTime.now();
    _selectedQuizOption = null;
    _quizAnswered = false;
  }

  /// Xử lý sự kiện toggle flip từ người dùng hoặc hệ thống.
  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  /// Xử lý sự kiện handle action từ người dùng hoặc hệ thống.
  Future<void> _handleAction(StudentFlashcardMemoryLevel level) async {
    final card = _currentCard;
    if (card == null || _savingProgress) {
      return;
    }

    setState(() => _savingProgress = true);
    try {
      await _syncMemoryLevel(card, level);
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
            _requeueCard(card);
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

  /// Thực hiện tác vụ bất đồng bộ sync memory level cho màn hình hiện tại.
  Future<void> _syncMemoryLevel(
    StudentFlashcardCard card,
    StudentFlashcardMemoryLevel level,
  ) async {
    final isMastered = level == StudentFlashcardMemoryLevel.mastered;
    if (!isMastered && _cardsPenalizedThisSession.contains(card.id)) {
      return;
    }

    await widget.studentApi.updateFlashcardProgress(
      cardId: card.id,
      memoryLevel: level,
    );

    if (isMastered) {
      _cardsPenalizedThisSession.remove(card.id);
    } else {
      _cardsPenalizedThisSession.add(card.id);
    }
  }

  /// Thực hiện tác vụ bất đồng bộ sync quiz result cho màn hình hiện tại.
  Future<void> _syncQuizResult(
    StudentFlashcardCard card,
    bool isCorrect,
    int responseMs,
  ) async {
    if (!isCorrect && _cardsPenalizedThisSession.contains(card.id)) {
      return;
    }

    await widget.studentApi.submitFlashcardResult(
      cardId: card.id,
      result: isCorrect
          ? StudentFlashcardResult.correct
          : StudentFlashcardResult.wrong,
      responseMs: responseMs,
    );

    if (isCorrect) {
      _cardsPenalizedThisSession.remove(card.id);
    } else {
      _cardsPenalizedThisSession.add(card.id);
    }
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final card = _currentCard;
    final colors = StudentThemeScope.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadReview(silent: true),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
