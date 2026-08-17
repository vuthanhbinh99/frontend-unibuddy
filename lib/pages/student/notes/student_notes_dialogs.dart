part of 'student_notes_page.dart';

class _AttachmentInputDialog extends StatefulWidget {
  const _AttachmentInputDialog();

  @override
  State<_AttachmentInputDialog> createState() => _AttachmentInputDialogState();
}

class _AttachmentInputDialogState extends State<_AttachmentInputDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _sizeController;
  String _fileType = 'application/pdf';
  String? _errorMessage;

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _sizeController = TextEditingController(text: '1024');
  }

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text('Tệp đính kèm', style: TextStyle(color: colors.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(controller: _nameController, label: 'Tên file'),
            const SizedBox(height: 10),
            _DialogField(
              controller: _urlController,
              label: 'Download URL',
              hintText: 'https://...',
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: _sizeController,
              label: 'Dung lượng bytes',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _fileType,
              dropdownColor: colors.surface,
              decoration: _dialogDecoration(context, 'Loại file'),
              items: const [
                DropdownMenuItem(value: 'application/pdf', child: Text('PDF')),
                DropdownMenuItem(
                  value:
                      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                  child: Text('DOCX'),
                ),
                DropdownMenuItem(value: 'image/png', child: Text('PNG')),
                DropdownMenuItem(value: 'image/jpeg', child: Text('JPEG')),
                DropdownMenuItem(value: 'text/plain', child: Text('TXT')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _fileType = value);
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              StudentInlineMessage(message: _errorMessage!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Thêm')),
      ],
    );
  }

  /// Xử lý thao tác submit và đồng bộ kết quả với UI.
  void _submit() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final size = int.tryParse(_sizeController.text.trim()) ?? 0;
    final uri = Uri.tryParse(url);

    if (name.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        size <= 0) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tên file, URL http/https và dung lượng.';
      });
      return;
    }

    Navigator.pop(
      context,
      StudentNoteAttachmentInput(
        downloadUrl: url,
        name: name,
        fileType: _fileType,
        size: size,
      ),
    );
  }
}

class _AttachmentMetadataDialog extends StatelessWidget {
  const _AttachmentMetadataDialog({required this.file});

  final PlatformFile file;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    return _AttachmentNoteDialogContent(file: file);
  }
}

class _AttachmentNoteDialogContent extends StatefulWidget {
  const _AttachmentNoteDialogContent({required this.file});

  final PlatformFile file;

  @override
  State<_AttachmentNoteDialogContent> createState() =>
      _AttachmentNoteDialogContentState();
}

class _AttachmentNoteDialogContentState
    extends State<_AttachmentNoteDialogContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _contentController;
  String? _errorMessage;

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.file.name);
    _urlController = TextEditingController();
    _contentController = TextEditingController(
      text: 'Tài liệu đính kèm: ${widget.file.name}',
    );
  }

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text('Tạo ghi chú tài liệu', style: TextStyle(color: colors.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(controller: _titleController, label: 'Tiêu đề'),
            const SizedBox(height: 10),
            _DialogField(
              controller: _urlController,
              label: 'Download URL',
              hintText: 'https://...',
            ),
            const SizedBox(height: 10),
            _DialogField(
              controller: _contentController,
              label: 'Nội dung',
              maxLines: 3,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              StudentInlineMessage(message: _errorMessage!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Tạo')),
      ],
    );
  }

  /// Xử lý thao tác submit và đồng bộ kết quả với UI.
  void _submit() {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);
    if (title.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tiêu đề và URL http/https.';
      });
      return;
    }

    Navigator.pop(
      context,
      _AttachmentNoteDraft(
        title: title,
        content: _contentController.text.trim(),
        attachment: StudentNoteAttachmentInput(
          downloadUrl: url,
          name: widget.file.name,
          fileType: _mimeTypeFromName(widget.file.name),
          size: widget.file.size <= 0 ? 1024 : widget.file.size,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 20, color: colors.text),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({required this.right, required this.label, this.color});

  final double right;
  final String label;
  final Color? color;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final resolvedColor = color ?? colors.surfaceAlt;
    return Positioned(
      right: right,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: resolvedColor,
          shape: BoxShape.circle,
          border: Border.all(color: colors.background, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colors.onColor(resolvedColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: colors.primaryStrong),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: colors.text),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textMuted),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: colors.surfaceAlt.withValues(alpha: 0.75),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.name,
    required this.subtitle,
    required this.onDelete,
  });

  final String name;
  final String subtitle;
  final VoidCallback onDelete;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Color(0xFF89CEFF), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, color: Color(0xFFFFB4AB), size: 18),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: colors.textSubtle,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  const _EditorTextField({
    required this.controller,
    required this.hintText,
    this.fontWeight = FontWeight.normal,
  });

  final TextEditingController controller;
  final String hintText;
  final FontWeight fontWeight;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return TextField(
      controller: controller,
      style: TextStyle(
        color: colors.text,
        fontWeight: fontWeight,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colors.textSubtle),
        filled: true,
        fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primaryStrong),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final int maxLines;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dialogDecoration(
        context,
        label,
      ).copyWith(hintText: hintText),
    );
  }
}

InputDecoration _dialogDecoration(BuildContext context, String label) {
  final colors = StudentThemeScope.colorsOf(context);
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colors.textMuted, fontSize: 12),
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

class _StudentNoteDraft {
  const _StudentNoteDraft({
    required this.title,
    required this.content,
    required this.courseId,
    required this.newAttachments,
    required this.deletedAttachmentIds,
  });

  final String title;
  final String content;
  final String? courseId;
  final List<StudentNoteAttachmentInput> newAttachments;
  final List<String> deletedAttachmentIds;
}

class _AttachmentNoteDraft {
  const _AttachmentNoteDraft({
    required this.title,
    required this.content,
    required this.attachment,
  });

  final String title;
  final String content;
  final StudentNoteAttachmentInput attachment;
}

class _NoteType {
  const _NoteType({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

enum _NoteFilter {
  all('Tất cả'),
  notes('Ghi chú'),
  attachments('Có tệp'),
  courses('Theo môn');

  const _NoteFilter(this.label);

  final String label;
}

enum _NoteAction { edit, delete }

enum _CreateChoice { note, attachment }

String _mimeTypeFromName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.txt')) {
    return 'text/plain';
  }
  if (lower.endsWith('.doc')) {
    return 'application/msword';
  }
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  return 'application/pdf';
}
