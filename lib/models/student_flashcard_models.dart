import 'dart:math' as math;

enum StudentFlashcardMemoryLevel {
  forgot('KHO_QUEN'),
  review('TRUNG_BINH'),
  mastered('DE');

  const StudentFlashcardMemoryLevel(this.value);

  final String value;
}

enum StudentFlashcardResult {
  correct('DUNG'),
  wrong('SAI');

  const StudentFlashcardResult(this.value);

  final String value;
}

enum StudentFlashcardCardType {
  essay('TU_LUAN'),
  quiz('TRAC_NGHIEM');

  const StudentFlashcardCardType(this.value);

  final String value;

  static StudentFlashcardCardType fromValue(Object? raw) {
    final normalized = (raw as String?)?.trim().toUpperCase();
    return StudentFlashcardCardType.values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => StudentFlashcardCardType.essay,
    );
  }
}

class StudentFlashcardQuizOption {
  const StudentFlashcardQuizOption({required this.id, required this.content});

  final String id;
  final String content;

  factory StudentFlashcardQuizOption.fromJson(Map<String, dynamic> json) {
    return StudentFlashcardQuizOption(
      id: (json['id'] as String? ?? '').trim(),
      content: json['noiDung'] as String? ?? '',
    );
  }
}

class StudentFlashcardQuizContent {
  const StudentFlashcardQuizContent({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  final String question;
  final List<StudentFlashcardQuizOption> options;
  final String correctAnswer;
  final String explanation;

  factory StudentFlashcardQuizContent.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['cacLuaChon'] as List<dynamic>? ?? const [];
    return StudentFlashcardQuizContent(
      question: json['cauHoi'] as String? ?? '',
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(StudentFlashcardQuizOption.fromJson)
          .toList(),
      correctAnswer: (json['dapAnDung'] as String? ?? '').trim().toUpperCase(),
      explanation: json['giaiThich'] as String? ?? '',
    );
  }
}

/// Dữ liệu người dùng nhập để tạo/sửa một thẻ trắc nghiệm thủ công.
class StudentFlashcardQuizDraft {
  const StudentFlashcardQuizDraft({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  final String question;
  final List<StudentFlashcardQuizOption> options;
  final String correctAnswer;
  final String explanation;

  Map<String, Object?> toJson() {
    return {
      'cauHoi': question.trim(),
      'cacLuaChon': options
          .map((option) => {
                'id': option.id.trim().toUpperCase(),
                'noiDung': option.content.trim(),
              })
          .toList(),
      'dapAnDung': correctAnswer.trim().toUpperCase(),
      'giaiThich': explanation.trim(),
    };
  }
}

class StudentFlashcardDeckData {
  const StudentFlashcardDeckData({required this.message, required this.items});

  final String message;
  final List<StudentFlashcardDeck> items;

  factory StudentFlashcardDeckData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>? ?? const {};
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return StudentFlashcardDeckData(
      message: map['message'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(StudentFlashcardDeck.fromJson)
          .toList(),
    );
  }
}

class StudentFlashcardDeck {
  const StudentFlashcardDeck({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.title,
    required this.cardCount,
    required this.dueCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? courseId;
  final String? courseCode;
  final String? courseName;
  final String title;
  final int cardCount;
  final int dueCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudentFlashcardDeck.fromJson(Map<String, dynamic> json) {
    return StudentFlashcardDeck(
      id: json['maBo'] as String? ?? '',
      userId: json['maNguoiDung'] as String? ?? '',
      courseId: json['maMonHoc'] as String?,
      courseCode: json['maMon'] as String?,
      courseName: json['tenMon'] as String?,
      title: json['tenBo'] as String? ?? 'Bộ Flashcard',
      cardCount: _asInt(json['soThe']),
      dueCount: _asInt(json['soTheCanOn']),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }

  double get progressPercent {
    if (cardCount <= 0) {
      return 0;
    }
    final reviewed = (cardCount - dueCount).clamp(0, cardCount);
    return reviewed / cardCount;
  }

  int get progressRounded => (progressPercent * 100).round();

  String get codeLabel {
    final code = courseCode?.trim();
    if (code != null && code.isNotEmpty) {
      return code.toUpperCase();
    }
    return 'FLASH';
  }

  String get courseLabel {
    final code = courseCode?.trim();
    final name = courseName?.trim();
    if (code != null && code.isNotEmpty && name != null && name.isNotEmpty) {
      return '$code - $name';
    }
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Bộ tự do';
  }
}

class StudentFlashcardReviewData {
  const StudentFlashcardReviewData({
    required this.message,
    required this.items,
  });

  final String message;
  final List<StudentFlashcardCard> items;

  factory StudentFlashcardReviewData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>? ?? const {};
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return StudentFlashcardReviewData(
      message: map['message'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(StudentFlashcardCard.fromJson)
          .toList(),
    );
  }
}

class StudentFlashcardMutationData {
  const StudentFlashcardMutationData({
    required this.message,
    required this.deck,
    required this.card,
    required this.cards,
    required this.importedCount,
  });

  final String message;
  final StudentFlashcardDeck? deck;
  final StudentFlashcardCard? card;
  final List<StudentFlashcardCard> cards;
  final int importedCount;

  factory StudentFlashcardMutationData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>? ?? const {};
    final rawDeck = map['boFlashcard'];
    final rawCard = map['flashcard'];
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return StudentFlashcardMutationData(
      message: map['message'] as String? ?? '',
      deck: rawDeck is Map<String, dynamic>
          ? StudentFlashcardDeck.fromJson(rawDeck)
          : null,
      card: rawCard is Map<String, dynamic>
          ? StudentFlashcardCard.fromJson(rawCard)
          : null,
      cards: rawItems
          .whereType<Map<String, dynamic>>()
          .map(StudentFlashcardCard.fromJson)
          .toList(),
      importedCount: _asInt(map['importedCount']),
    );
  }
}

class StudentFlashcardCard {
  const StudentFlashcardCard({
    required this.id,
    required this.deckId,
    required this.userId,
    required this.cardType,
    required this.front,
    required this.back,
    required this.quizContent,
    required this.reviewCount,
    required this.memoryScore,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String deckId;
  final String userId;
  final StudentFlashcardCardType cardType;
  final String front;
  final String back;
  final StudentFlashcardQuizContent? quizContent;
  final int reviewCount;
  final double memoryScore;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isQuiz =>
      cardType == StudentFlashcardCardType.quiz && quizContent != null;

  factory StudentFlashcardCard.fromJson(Map<String, dynamic> json) {
    final rawBack = json['matSau'];
    final quizContent = rawBack is Map<String, dynamic>
        ? StudentFlashcardQuizContent.fromJson(rawBack)
        : null;
    return StudentFlashcardCard(
      id: json['maFlashcard'] as String? ?? '',
      deckId: json['maBo'] as String? ?? '',
      userId: json['maNguoiDung'] as String? ?? '',
      cardType: StudentFlashcardCardType.fromValue(json['loaiThe']),
      front: json['matTruoc'] as String? ?? '',
      back: rawBack is String ? rawBack : (quizContent?.explanation ?? ''),
      quizContent: quizContent,
      reviewCount: _asInt(json['soLanOn']),
      memoryScore: _asDouble(json['diemGhiNho']),
      lastReviewedAt: _asDate(json['thoiGianLanOnCuoi']),
      nextReviewAt: _asDate(json['thoiGianLanOnTiepTheo']),
      createdAt: _asDate(json['createdAt']),
      updatedAt: _asDate(json['updatedAt']),
    );
  }
}

class StudentFlashcardStatisticsData {
  const StudentFlashcardStatisticsData({
    required this.message,
    required this.statistics,
  });

  final String message;
  final StudentFlashcardStatistics statistics;

  factory StudentFlashcardStatisticsData.fromJson(Object? data) {
    final map = data as Map<String, dynamic>? ?? const {};
    final rawStats = map['thongKe'] as Map<String, dynamic>? ?? const {};
    return StudentFlashcardStatisticsData(
      message: map['message'] as String? ?? '',
      statistics: StudentFlashcardStatistics.fromJson(rawStats),
    );
  }
}

class StudentFlashcardStatistics {
  const StudentFlashcardStatistics({
    required this.totalDecks,
    required this.totalCards,
    required this.dueToday,
    required this.notReviewed,
    required this.mastered,
    required this.masteryRate,
  });

  final int totalDecks;
  final int totalCards;
  final int dueToday;
  final int notReviewed;
  final int mastered;
  final double masteryRate;

  factory StudentFlashcardStatistics.fromJson(Map<String, dynamic> json) {
    return StudentFlashcardStatistics(
      totalDecks: _asInt(json['tongSoBo']),
      totalCards: _asInt(json['tongSoThe']),
      dueToday: _asInt(json['soTheCanOnHomNay']),
      notReviewed: _asInt(json['soTheChuaOn']),
      mastered: _asInt(json['soTheDaThuoc']),
      masteryRate: _asDouble(json['tyLeThuocBai']),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime? _asDate(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int stableDeckColorIndex(StudentFlashcardDeck deck, int fallbackIndex) {
  final code = deck.codeLabel;
  if (code == 'FLASH') {
    return fallbackIndex;
  }
  return code.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
      math.max(1, 4);
}
