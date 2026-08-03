import 'package:flutter/material.dart';

import '../../models/student_flashcard_models.dart';
import 'student_theme.dart';

/// Dữ liệu người dùng nhập cho một thẻ tự luận (nhập tay thủ công).
class StudentFlashcardEssayDraft {
  const StudentFlashcardEssayDraft({required this.front, required this.back});

  final String front;
  final String back;
}

/// Mở bảng chọn loại thẻ (tự luận / trắc nghiệm) trước khi soạn thẻ mới.
Future<StudentFlashcardCardType?> pickStudentFlashcardCardType(
  BuildContext context,
) {
  final colors = StudentThemeScope.colorsOf(context);
  return showModalBottomSheet<StudentFlashcardCardType>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.notes_outlined, color: colors.primaryStrong),
              title: Text('Thẻ tự luận', style: TextStyle(color: colors.text)),
              subtitle: Text(
                'Mặt trước là câu hỏi, mặt sau là câu trả lời.',
                style: TextStyle(color: colors.textMuted),
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                StudentFlashcardCardType.essay,
              ),
            ),
            ListTile(
              leading: Icon(Icons.quiz_outlined, color: colors.primaryStrong),
              title: Text(
                'Thẻ trắc nghiệm',
                style: TextStyle(color: colors.text),
              ),
              subtitle: Text(
                'Câu hỏi kèm các lựa chọn và đáp án đúng.',
                style: TextStyle(color: colors.textMuted),
              ),
              onTap: () => Navigator.pop(
                sheetContext,
                StudentFlashcardCardType.quiz,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

/// Mở form nhập tay thẻ tự luận. Truyền [card] để sửa thẻ có sẵn.
Future<StudentFlashcardEssayDraft?> showStudentFlashcardEssayEditor(
  BuildContext context, {
  StudentFlashcardCard? card,
}) {
  return showModalBottomSheet<StudentFlashcardEssayDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: StudentThemeScope.colorsOf(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _EssayEditorSheet(card: card),
  );
}

/// Mở form nhập tay thẻ trắc nghiệm. Truyền [card] để sửa thẻ có sẵn.
Future<StudentFlashcardQuizDraft?> showStudentFlashcardQuizEditor(
  BuildContext context, {
  StudentFlashcardCard? card,
}) {
  return showModalBottomSheet<StudentFlashcardQuizDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: StudentThemeScope.colorsOf(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _QuizEditorSheet(card: card),
  );
}

class _EssayEditorSheet extends StatefulWidget {
  const _EssayEditorSheet({this.card});

  final StudentFlashcardCard? card;

  @override
  State<_EssayEditorSheet> createState() => _EssayEditorSheetState();
}

class _EssayEditorSheetState extends State<_EssayEditorSheet> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card?.front ?? '');
    _backController = TextEditingController(text: widget.card?.back ?? '');
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  void _submit() {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    if (front.isEmpty || back.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập cả mặt trước và mặt sau.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      StudentFlashcardEssayDraft(front: front, back: back),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final isEditing = widget.card != null;
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
          const SizedBox(height: 16),
          Text(
            isEditing ? 'Sửa thẻ tự luận' : 'Thêm thẻ tự luận',
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _frontController,
            maxLines: 3,
            style: TextStyle(color: colors.text),
            decoration: const InputDecoration(
              labelText: 'Mặt trước (câu hỏi)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _backController,
            maxLines: 5,
            style: TextStyle(color: colors.text),
            decoration: const InputDecoration(
              labelText: 'Mặt sau (câu trả lời)',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: Text(isEditing ? 'Lưu thay đổi' : 'Thêm thẻ'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizOptionField {
  _QuizOptionField({required this.id, required String content})
      : controller = TextEditingController(text: content);

  final String id;
  final TextEditingController controller;
}

class _QuizEditorSheet extends StatefulWidget {
  const _QuizEditorSheet({this.card});

  final StudentFlashcardCard? card;

  @override
  State<_QuizEditorSheet> createState() => _QuizEditorSheetState();
}

class _QuizEditorSheetState extends State<_QuizEditorSheet> {
  static const _optionLabels = ['A', 'B', 'C', 'D', 'E', 'F'];
  static const _minOptions = 2;
  static const _maxOptions = 6;

  late final TextEditingController _questionController;
  late final TextEditingController _explanationController;
  final List<_QuizOptionField> _options = [];
  String? _correctAnswer;

  @override
  void initState() {
    super.initState();
    final quiz = widget.card?.quizContent;
    _questionController = TextEditingController(text: quiz?.question ?? '');
    _explanationController =
        TextEditingController(text: quiz?.explanation ?? '');
    if (quiz != null && quiz.options.isNotEmpty) {
      for (var i = 0; i < quiz.options.length && i < _maxOptions; i++) {
        _options.add(
          _QuizOptionField(
            id: _optionLabels[i],
            content: quiz.options[i].content,
          ),
        );
      }
      _correctAnswer = _optionLabels.contains(quiz.correctAnswer)
          ? quiz.correctAnswer
          : _options.first.id;
    } else {
      _options.add(_QuizOptionField(id: 'A', content: ''));
      _options.add(_QuizOptionField(id: 'B', content: ''));
      _correctAnswer = 'A';
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final option in _options) {
      option.controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= _maxOptions) {
      return;
    }
    setState(() {
      _options.add(
        _QuizOptionField(id: _optionLabels[_options.length], content: ''),
      );
    });
  }

  void _removeOption(int index) {
    if (_options.length <= _minOptions) {
      return;
    }
    setState(() {
      final removed = _options.removeAt(index);
      removed.controller.dispose();
      // Gán lại nhãn A/B/C… theo thứ tự để mã lựa chọn luôn liên tục.
      final rebuilt = <_QuizOptionField>[];
      for (var i = 0; i < _options.length; i++) {
        rebuilt.add(
          _QuizOptionField(
            id: _optionLabels[i],
            content: _options[i].controller.text,
          ),
        );
        _options[i].controller.dispose();
      }
      _options
        ..clear()
        ..addAll(rebuilt);
      if (_correctAnswer == null ||
          !_options.any((option) => option.id == _correctAnswer)) {
        _correctAnswer = _options.first.id;
      }
    });
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _warn('Vui lòng nhập câu hỏi.');
      return;
    }
    final options = _options
        .map(
          (option) => StudentFlashcardQuizOption(
            id: option.id,
            content: option.controller.text.trim(),
          ),
        )
        .toList();
    if (options.any((option) => option.content.isEmpty)) {
      _warn('Vui lòng nhập nội dung cho tất cả lựa chọn.');
      return;
    }
    final correct = _correctAnswer;
    if (correct == null || !options.any((option) => option.id == correct)) {
      _warn('Vui lòng chọn đáp án đúng.');
      return;
    }
    Navigator.pop(
      context,
      StudentFlashcardQuizDraft(
        question: question,
        options: options,
        correctAnswer: correct,
        explanation: _explanationController.text.trim(),
      ),
    );
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final isEditing = widget.card != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Sửa thẻ trắc nghiệm' : 'Thêm thẻ trắc nghiệm',
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _questionController,
              maxLines: 3,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Câu hỏi'),
            ),
            const SizedBox(height: 16),
            Text(
              'Các lựa chọn (chọn đáp án đúng)',
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _correctAnswer,
              onChanged: (value) {
                setState(() => _correctAnswer = value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Radio<String>(value: _options[i].id),
                          Expanded(
                            child: TextField(
                              controller: _options[i].controller,
                              style: TextStyle(color: colors.text),
                              decoration: InputDecoration(
                                labelText: 'Lựa chọn ${_options[i].id}',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: _options.length > _minOptions
                                  ? Colors.red
                                  : colors.textSubtle,
                            ),
                            onPressed: _options.length > _minOptions
                                ? () => _removeOption(i)
                                : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_options.length < _maxOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm lựa chọn'),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _explanationController,
              maxLines: 3,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(
                labelText: 'Giải thích (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: Text(isEditing ? 'Lưu thay đổi' : 'Thêm thẻ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
