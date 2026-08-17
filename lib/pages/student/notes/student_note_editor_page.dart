part of 'student_notes_page.dart';

class _StudentNoteEditorPage extends StatefulWidget {
  const _StudentNoteEditorPage({required this.courses, this.note});

  final StudentNote? note;
  final List<StudentCourseItem> courses;

  @override
  State<_StudentNoteEditorPage> createState() => _StudentNoteEditorPageState();
}

class _StudentNoteEditorPageState extends State<_StudentNoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _selectedCourseId;
  late final List<StudentNoteAttachment> _existingAttachments;
  final List<String> _deletedAttachmentIds = [];
  final List<StudentNoteAttachmentInput> _newAttachments = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _selectedCourseId = widget.note?.courseId;
    _existingAttachments = [...widget.note?.attachments ?? const []];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.note == null ? 'Ghi chú mới' : 'Chỉnh sửa ghi chú',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryStrong,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Lưu',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('TIÊU ĐỀ'),
            const SizedBox(height: 6),
            _EditorTextField(
              controller: _titleController,
              hintText: 'Nhập tiêu đề...',
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 16),
            _Label('MÔN HỌC'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surfaceAlt.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedCourseId,
                  isExpanded: true,
                  dropdownColor: colors.surface,
                  style: TextStyle(fontSize: 12, color: colors.text),
                  onChanged: (value) =>
                      setState(() => _selectedCourseId = value),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Không gắn môn'),
                    ),
                    ...widget.courses.map(
                      (course) => DropdownMenuItem<String?>(
                        value: course.id,
                        child: Text(
                          course.code == null
                              ? course.name
                              : '${course.code} - ${course.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Label('TỆP ĐÍNH KÈM'),
                TextButton.icon(
                  onPressed: _addAttachment,
                  icon: const Icon(Icons.add_link, size: 16),
                  label: const Text('Thêm URL'),
                ),
              ],
            ),
            _buildAttachmentList(),
            const SizedBox(height: 16),
            _Label('NỘI DUNG'),
            const SizedBox(height: 6),
            TextField(
              controller: _contentController,
              maxLines: 12,
              style: TextStyle(fontSize: 12, color: colors.text, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Bắt đầu viết ghi chú tại đây...',
                hintStyle: TextStyle(color: colors.textSubtle),
                filled: true,
                fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.primaryStrong),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentList() {
    final colors = StudentThemeScope.colorsOf(context);
    final hasAttachments =
        _existingAttachments.isNotEmpty || _newAttachments.isNotEmpty;
    if (!hasAttachments) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          'Chưa có tệp đính kèm.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        ..._existingAttachments.map(
          (attachment) => _AttachmentTile(
            name: attachment.name,
            subtitle: attachment.fileType ?? attachment.url,
            onDelete: () {
              setState(() {
                _existingAttachments.remove(attachment);
                if (attachment.id.isNotEmpty) {
                  _deletedAttachmentIds.add(attachment.id);
                }
              });
            },
          ),
        ),
        ..._newAttachments.map(
          (attachment) => _AttachmentTile(
            name: attachment.name,
            subtitle: attachment.fileType,
            onDelete: () => setState(() => _newAttachments.remove(attachment)),
          ),
        ),
      ],
    );
  }

  Future<void> _addAttachment() async {
    final attachment = await showDialog<StudentNoteAttachmentInput>(
      context: context,
      builder: (context) => const _AttachmentInputDialog(),
    );

    if (attachment == null) {
      return;
    }
    setState(() => _newAttachments.add(attachment));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiêu đề ghi chú không được để trống.')),
      );
      return;
    }

    Navigator.pop(
      context,
      _StudentNoteDraft(
        title: title,
        content: _contentController.text.trim(),
        courseId: _selectedCourseId,
        newAttachments: _newAttachments,
        deletedAttachmentIds: _deletedAttachmentIds,
      ),
    );
  }
}
