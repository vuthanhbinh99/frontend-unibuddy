import 'package:flutter/material.dart';

import '../../../models/student_assistant_models.dart';
import '../../../services/api/api_exception.dart';
import '../../../services/api/modules/student_api_service.dart';
import '../student_theme.dart';

/// Bottom sheet hội thoại nhiều lượt với trợ lý học tập UniBuddy.
///
/// Giữ toàn bộ lịch sử trong state để gửi kèm mỗi lượt (backend dùng
/// `lichSu` để giữ ngữ cảnh). Có thể truyền [starterMessage] để mở sẵn
/// một câu hỏi gợi ý theo bối cảnh màn hình đang đứng.
class StudentAssistantChatSheet extends StatefulWidget {
  const StudentAssistantChatSheet({
    super.key,
    required this.studentApi,
    this.starterMessage,
  });

  final StudentApiService studentApi;
  final String? starterMessage;

  /// Mở sheet dạng modal chiếm phần lớn màn hình.
  static Future<void> show(
    BuildContext context, {
    required StudentApiService studentApi,
    String? starterMessage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentAssistantChatSheet(
        studentApi: studentApi,
        starterMessage: starterMessage,
      ),
    );
  }

  @override
  State<StudentAssistantChatSheet> createState() =>
      _StudentAssistantChatSheetState();
}

class _StudentAssistantChatSheetState extends State<StudentAssistantChatSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AssistantChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final starter = widget.starterMessage?.trim();
    if (starter != null && starter.isNotEmpty) {
      _inputController.text = starter;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    // Lịch sử gửi lên backend KHÔNG gồm câu hỏi mới (câu hỏi đi ở `message`).
    final history = List<AssistantChatMessage>.from(_messages);

    setState(() {
      _messages.add(AssistantChatMessage.user(text));
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await widget.studentApi.chatWithAssistant(
        message: text,
        history: history,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(AssistantChatMessage.assistant(reply.message));
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          AssistantChatMessage.assistant(
            'Xin lỗi, mình chưa trả lời được lúc này: ${error.message}',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(colors),
                Expanded(
                  child: _messages.isEmpty
                      ? _AssistantEmptyState(
                          onSuggestionTap: (value) {
                            _inputController.text = value;
                            _send();
                          },
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _messages.length) {
                              return const _TypingBubble();
                            }
                            return _ChatBubble(message: _messages[index]);
                          },
                        ),
                ),
                _buildComposer(colors),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(StudentThemeColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.tint(colors.primaryStrong, lightAlpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: colors.primaryStrong,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý học tập',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                Text(
                  'Hỏi về điểm số, lịch học, deadline...',
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(StudentThemeColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceAlt.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText: 'Nhập câu hỏi của bạn...',
                  hintStyle: TextStyle(color: colors.textSubtle, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isSending ? colors.surfaceMuted : colors.primaryStrong,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isSending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: colors.onPrimary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AssistantChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colors.primaryStrong
              : colors.surfaceAlt.withValues(alpha: 0.9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: colors.border),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? colors.onPrimary : colors.text,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primaryStrong,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Đang soạn câu trả lời...',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  static const _suggestions = <String>[
    'Học kỳ này mình nên tập trung gỡ điểm môn nào?',
    'Tuần này mình có deadline nào sắp tới không?',
    'Cần bao nhiêu điểm cuối kỳ để đạt GPA mục tiêu?',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.auto_awesome_outlined,
            size: 40,
            color: colors.primaryStrong,
          ),
          const SizedBox(height: 12),
          Text(
            'Mình có thể giúp gì cho việc học của bạn?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chọn nhanh một gợi ý hoặc tự nhập câu hỏi bên dưới.',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          ..._suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSuggestionTap(suggestion),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: colors.primaryStrong,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: TextStyle(fontSize: 13, color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
