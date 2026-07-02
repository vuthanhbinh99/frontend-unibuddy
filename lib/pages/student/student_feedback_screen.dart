import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';

class StudentFeedbackScreen extends StatefulWidget {
  const StudentFeedbackScreen({
    super.key,
    required this.studentApi,
    required this.currentLanguageCode,
  });

  final StudentApiService studentApi;
  final String currentLanguageCode;

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'bug';
  PlatformFile? _attachment;
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  static const _imageMimeByExtension = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
  };

  static const _categories = [
    _FeedbackCategory(
      id: 'bug',
      vi: 'Lỗi ứng dụng',
      en: 'App Bug / Error',
      icon: Icons.bug_report_outlined,
    ),
    _FeedbackCategory(
      id: 'feature',
      vi: 'Góp ý tính năng',
      en: 'Feature Suggestion',
      icon: Icons.auto_awesome_outlined,
    ),
    _FeedbackCategory(
      id: 'ui',
      vi: 'Giao diện (UI/UX)',
      en: 'User Interface',
      icon: Icons.palette_outlined,
    ),
    _FeedbackCategory(
      id: 'other',
      vi: 'Khác',
      en: 'Other',
      icon: Icons.help_outline_outlined,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _text(String vi, String en) {
    return widget.currentLanguageCode == 'vi' ? vi : en;
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (!mounted) {
      return;
    }
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final extension = (file.extension ?? '').toLowerCase();
    if (!_imageMimeByExtension.containsKey(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Chỉ hỗ trợ ảnh PNG, JPG hoặc WebP.',
              'Only PNG, JPG, or WebP images are supported.',
            ),
          ),
        ),
      );
      return;
    }

    if (file.bytes == null || file.bytes!.isEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Không thể đọc ảnh đã chọn.',
              'Could not read the selected image.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _attachment = file);
  }

  Future<void> _submitFeedback() async {
    final message = _messageController.text.trim();
    if (message.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Vui lòng mô tả chi tiết hơn.',
              'Please provide a more detailed description.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.studentApi.submitFeedback(
        category: _selectedCategory,
        message: message,
        attachmentBytes: _attachment?.bytes,
        attachmentFileName: _attachment?.name,
        attachmentMimeType: _attachment == null
            ? null
            : _mimeTypeForAttachment(_attachment!),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Không thể gửi phản hồi lúc này.',
              'Could not submit feedback right now.',
            ),
          ),
        ),
      );
    }
  }

  String _mimeTypeForAttachment(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    return _imageMimeByExtension[extension] ?? 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(
          _text('Gửi phản hồi', 'Submit feedback'),
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _isSubmitted
            ? _buildSuccess(colors)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        'Chúng tôi luôn lắng nghe ý kiến của bạn để UniBuddy tốt hơn.',
                        'We always listen to your feedback to improve UniBuddy.',
                      ),
                      style: TextStyle(
                        color: colors.textSubtle,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _text('Danh mục phản hồi', 'Feedback category'),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((category) {
                        final selected = _selectedCategory == category.id;
                        return ChoiceChip(
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedCategory = category.id);
                          },
                          avatar: Icon(
                            category.icon,
                            size: 18,
                            color: selected
                                ? colors.onPrimary
                                : colors.primaryStrong,
                          ),
                          label: Text(
                            _text(category.vi, category.en),
                            style: TextStyle(
                              color: selected ? colors.onPrimary : colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selectedColor: colors.primaryStrong,
                          backgroundColor: colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: colors.border),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _text('Chi tiết phản hồi', 'Detailed description'),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 6,
                        style: TextStyle(color: colors.text),
                        decoration: InputDecoration(
                          hintText: _text(
                            'Nhập vấn đề, góp ý hoặc mô tả lỗi bạn gặp phải...',
                            'Describe the issue, suggestion, or bug you found...',
                          ),
                          hintStyle: TextStyle(color: colors.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _text(
                        'Ảnh đính kèm (tùy chọn)',
                        'Image attachment (optional)',
                      ),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _attachment == null
                        ? InkWell(
                            onTap: _pickAttachment,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 26,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 34,
                                    color: colors.primaryStrong,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _text('Chọn ảnh', 'Choose image'),
                                    style: TextStyle(
                                      color: colors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'PNG, JPG, WEBP',
                                    style: TextStyle(
                                      color: colors.textSubtle,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.primarySoft,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.attach_file,
                                    color: colors.primaryStrong,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _attachment!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(_attachment!.size / 1024).toStringAsFixed(1)} KB',
                                        style: TextStyle(
                                          color: colors.textSubtle,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _attachment = null),
                                  child: Text(_text('Xóa', 'Remove')),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primaryStrong,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    colors.onPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                _text('Gửi ngay', 'Submit now'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccess(StudentThemeColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: colors.primaryStrong, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              _text('Cảm ơn bạn!', 'Thank you!'),
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _text(
                'Phản hồi của bạn đã được gửi thành công. Đội ngũ UniBuddy sẽ kiểm tra sớm nhất.',
                'Your feedback has been submitted successfully. The UniBuddy team will review it soon.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSubtle,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.text,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_text('Đóng', 'Close')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCategory {
  const _FeedbackCategory({
    required this.id,
    required this.vi,
    required this.en,
    required this.icon,
  });

  final String id;
  final String vi;
  final String en;
  final IconData icon;
}
