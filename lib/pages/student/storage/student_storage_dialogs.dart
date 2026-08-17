part of 'student_storage_page.dart';

class _DocumentVisibilityDialog extends StatefulWidget {
  const _DocumentVisibilityDialog({required this.currentVisibility});

  final StudentStorageVisibility currentVisibility;

  @override
  State<_DocumentVisibilityDialog> createState() =>
      _DocumentVisibilityDialogState();
}

class _DocumentVisibilityDialogState extends State<_DocumentVisibilityDialog> {
  late StudentStorageVisibility _selectedVisibility;

  @override
  void initState() {
    super.initState();
    _selectedVisibility = widget.currentVisibility;
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Chế độ hiển thị',
        style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: StudentStorageVisibility.values.map((visibility) {
          return RadioListTile<StudentStorageVisibility>(
            value: visibility,
            groupValue: _selectedVisibility,
            activeColor: colors.primaryStrong,
            contentPadding: EdgeInsets.zero,
            title: Text(
              visibility.label,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _visibilityDescription(visibility),
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedVisibility = value);
              }
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedVisibility),
          child: const Text('Lưu'),
        ),
      ],
    );
  }

  String _visibilityDescription(StudentStorageVisibility visibility) {
    return switch (visibility) {
      StudentStorageVisibility.public =>
        'Sinh viên cùng học phần có thể nhìn thấy.',
      StudentStorageVisibility.private =>
        'Chỉ bạn nhìn thấy trong kho lưu trữ.',
      StudentStorageVisibility.group =>
        'Chia sẻ theo nhóm học tập khi tài liệu gắn với nhóm.',
    };
  }
}

class _ReportDocumentDialog extends StatefulWidget {
  const _ReportDocumentDialog({required this.fileName});

  final String fileName;

  @override
  State<_ReportDocumentDialog> createState() => _ReportDocumentDialogState();
}

class _ReportDocumentDialogState extends State<_ReportDocumentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close([String? reason]) async {
    if (_closing) {
      return;
    }

    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pop(reason);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await _close(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Báo cáo tài liệu', style: TextStyle(color: colors.text)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mô tả lý do báo cáo "${widget.fileName}" để quản trị viên xem xét.',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _controller,
                maxLines: 4,
                maxLength: 1000,
                autofocus: true,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText:
                      'Ví dụ: Tài liệu vi phạm bản quyền, nội dung sai...',
                  hintStyle: TextStyle(color: colors.textMuted),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 10) {
                    return 'Vui lòng nhập lý do (tối thiểu 10 ký tự).';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => _close(), child: const Text('Hủy')),
          ElevatedButton(onPressed: _submit, child: const Text('Gửi báo cáo')),
        ],
      ),
    );
  }
}

class _UploadDocumentSheet extends StatefulWidget {
  const _UploadDocumentSheet({
    required this.fileName,
    required this.sizeBytes,
    required this.courses,
  });

  final String fileName;
  final int sizeBytes;
  final List<StudentCourseItem> courses;

  @override
  State<_UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<_UploadDocumentSheet> {
  late final TextEditingController _titleController;
  late String _courseId;
  StudentStorageVisibility _visibility = StudentStorageVisibility.public;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.fileName);
    _courseId = widget.courses.first.id;
  }

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
            const SizedBox(height: 18),
            Text(
              'Tải Lên Tệp',
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.fileName} • ${formatStudentStorageBytes(widget.sizeBytes)}',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              StudentInlineMessage(message: _errorMessage!),
            ],
            const SizedBox(height: 18),
            _StorageTextField(
              controller: _titleController,
              label: 'Tên tài liệu',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _courseId,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.text),
              decoration: _sheetInputDecoration(context, 'Học phần'),
              items: widget.courses
                  .map(
                    (course) => DropdownMenuItem(
                      value: course.id,
                      child: Text(
                        course.code == null || course.code!.isEmpty
                            ? course.name
                            : '${course.code} - ${course.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _courseId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<StudentStorageVisibility>(
              initialValue: _visibility,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.text),
              decoration: _sheetInputDecoration(context, 'Chế độ hiển thị'),
              items: StudentStorageVisibility.values
                  .map(
                    (visibility) => DropdownMenuItem(
                      value: visibility,
                      child: Text(visibility.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _visibility = value);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryStrong,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Lưu tài liệu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Nhập tên tài liệu hợp lệ.';
      });
      return;
    }

    Navigator.pop(
      context,
      _StorageUploadDraft(
        title: title,
        courseId: _courseId,
        visibility: _visibility,
      ),
    );
  }
}

class _StorageUploadDraft {
  const _StorageUploadDraft({
    required this.title,
    required this.courseId,
    required this.visibility,
  });

  final String title;
  final String courseId;
  final StudentStorageVisibility visibility;
}

class _StorageTextField extends StatelessWidget {
  const _StorageTextField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return TextField(
      controller: controller,
      style: TextStyle(color: colors.text),
      decoration: _sheetInputDecoration(context, label),
    );
  }
}

InputDecoration _sheetInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
}) {
  final colors = StudentThemeScope.colorsOf(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: colors.primaryStrong),
    hintStyle: TextStyle(color: colors.textSubtle),
    filled: true,
    fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.primaryStrong),
    ),
  );
}

class _FileStyle {
  const _FileStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_FileStyle _fileStyle(BuildContext context, StudentStorageFile file) {
  final colors = StudentThemeScope.colorsOf(context);
  switch (file.category) {
    case StudentStorageCategory.document:
      return _FileStyle(icon: Icons.description_outlined, color: colors.info);
    case StudentStorageCategory.spreadsheet:
      return const _FileStyle(
        icon: Icons.table_chart_outlined,
        color: Color(0xFF4ADE80),
      );
    case StudentStorageCategory.image:
      return const _FileStyle(
        icon: Icons.image_outlined,
        color: Color(0xFFF472B6),
      );
    case StudentStorageCategory.video:
      return const _FileStyle(
        icon: Icons.play_circle_outline,
        color: Color(0xFFF59E0B),
      );
    case StudentStorageCategory.other:
    case StudentStorageCategory.all:
      return _FileStyle(icon: Icons.insert_drive_file, color: colors.textMuted);
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final normalized = label.trim();
    final text = compact
        ? label
        : normalized.isEmpty
        ? '?'
        : normalized.substring(0, 1).toUpperCase();
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceAlt,
        border: Border.all(color: colors.background, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: colors.primaryStrong,
        ),
      ),
    );
  }
}

class _AiSummaryAssistantSheet extends StatefulWidget {
  const _AiSummaryAssistantSheet({
    required this.studentApi,
    this.initialTitle,
    this.initialContent,
    this.initialObjective,
  });

  final StudentApiService studentApi;
  final String? initialTitle;
  final String? initialContent;
  final String? initialObjective;

  @override
  State<_AiSummaryAssistantSheet> createState() =>
      _AiSummaryAssistantSheetState();
}

class _AiSummaryAssistantSheetState extends State<_AiSummaryAssistantSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _objectiveController;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(
      text: widget.initialContent ?? '',
    );
    _objectiveController = TextEditingController(
      text: widget.initialObjective ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.84,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryStrong.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colors.primaryStrong,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI tóm tắt tài liệu',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Dán nội dung tài liệu, AI sẽ tóm tắt và gợi ý ôn tập.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _StorageTextField(controller: _titleController, label: 'Tiêu đề'),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                maxLines: 8,
                style: TextStyle(color: colors.text),
                decoration: _sheetInputDecoration(
                  context,
                  'Nội dung tài liệu',
                  hint: 'Dán nội dung văn bản cần tóm tắt...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _objectiveController,
                maxLines: 2,
                style: TextStyle(color: colors.text),
                decoration: _sheetInputDecoration(
                  context,
                  'Mục tiêu (tùy chọn)',
                  hint: 'Ví dụ: chuẩn bị thi cuối kỳ trong 3 ngày',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    _isLoading ? 'Đang tóm tắt...' : 'Tóm tắt bằng AI',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: colors.danger, fontSize: 12),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 14),
                _AiSummaryResultCard(result: _result!),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.length < 3) {
      setState(() => _error = 'Tiêu đề cần ít nhất 3 ký tự.');
      return;
    }
    if (content.length < 30) {
      setState(() => _error = 'Nội dung cần ít nhất 30 ký tự để AI tóm tắt.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.studentApi.summarizeDocumentWithAi(
        title: title,
        content: content,
        objective: _objectiveController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = response;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _AiSummaryResultCard extends StatelessWidget {
  const _AiSummaryResultCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final summary = result['tomTatNgan']?.toString() ?? 'Không có tóm tắt';
    final keyPoints = (result['yChinh'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final suggestions = (result['deXuatOnTap'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final usedLocalFallback = result['usedLocalFallback'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kết quả AI',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (usedLocalFallback) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.34),
                ),
              ),
              child: Text(
                'Dịch vụ AI đang bận, hệ thống đã tạo tóm tắt dự phòng từ nội dung bạn cung cấp.',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(summary, style: TextStyle(color: colors.text, height: 1.4)),
          if (keyPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ý chính',
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            ...keyPoints.take(6).map((item) => Text('- $item')),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Đề xuất ôn tập',
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            ...suggestions.take(6).map((item) => Text('- $item')),
          ],
        ],
      ),
    );
  }
}

class _StorageErrorState extends StatelessWidget {
  const _StorageErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: colors.danger, size: 34),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
