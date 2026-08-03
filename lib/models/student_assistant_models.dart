/// Một lượt tin nhắn trong hội thoại với trợ lý học tập.
///
/// `role` khớp enum backend: `user` (sinh viên) hoặc `assistant` (trợ lý).
class AssistantChatMessage {
  const AssistantChatMessage({required this.role, required this.content});

  const AssistantChatMessage.user(this.content) : role = 'user';
  const AssistantChatMessage.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;

  bool get isUser => role == 'user';
}

/// Kết quả trả về từ `POST /assistant/chat`.
class AssistantChatReply {
  const AssistantChatReply({
    required this.message,
    required this.module,
    required this.confidence,
    required this.refused,
  });

  final String message;
  final String module;
  final double confidence;
  final bool refused;

  factory AssistantChatReply.fromJson(Map<String, dynamic> json) {
    return AssistantChatReply(
      message: json['message'] as String? ?? '',
      module: json['module'] as String? ?? 'khac',
      confidence: (json['doTinCay'] as num?)?.toDouble() ?? 0,
      refused: json['tuChoi'] as bool? ?? false,
    );
  }
}
