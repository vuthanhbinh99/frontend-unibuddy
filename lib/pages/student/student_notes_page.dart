import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';

import '../../models/student_course_models.dart';
import '../../models/student_note_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentNotesPage extends StatefulWidget {
  const StudentNotesPage({
    super.key,
    required this.studentApi,
    required this.courses,
    this.onViewAllNotifications,
  });

  final StudentApiService studentApi;
  final List<StudentCourseItem> courses;
  final VoidCallback? onViewAllNotifications;

  @override
  State<StudentNotesPage> createState() => _StudentNotesPageState();
}

class _StudentNotesPageState extends State<StudentNotesPage> {
  static const int _maxStorageBytes = 5 * 1024 * 1024 * 1024;

  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final List<StudentNote> _notes = [];

  _NoteFilter _selectedFilter = _NoteFilter.all;
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final notes = _filteredNotes;
    final usedBytes = _usedStorageBytes;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotes,
          color: colors.primary,
          backgroundColor: colors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                sliver: SliverList.list(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildWorkspaceHeader(),
                    const SizedBox(height: 24),
                    _buildStorageIndicator(usedBytes),
                    const SizedBox(height: 24),
                    _buildCreateCard(),
                    const SizedBox(height: 18),
                    _buildSearchBox(),
                    const SizedBox(height: 18),
                    _buildQuickFilters(),
                    const SizedBox(height: 20),
                    Text(
                      'DANH SÁCH GHI CHÚ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              if (_isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SpinKitThreeBounce(
                      color: colors.primaryStrong,
                      size: 26,
                    ),
                  ),
                )
              else if (notes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.1,
                        ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      return _buildAsymmetricNoteCard(notes[index], index);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        onPressed: _isSaving ? null : () => _openEditor(null),
        child: _isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).pop(),
        ),
        Text(
          'Ghi Chú',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        StudentNotificationBell(
          studentApi: widget.studentApi,
          onViewAll: widget.onViewAllNotifications,
          iconColor: colors.text,
          backgroundColor: colors.surfaceAlt.withValues(alpha: 0.8),
          borderColor: colors.border,
        ),
      ],
    );
  }

  Widget _buildWorkspaceHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Không Gian Ghi Chú UniBuddy',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lưu trữ ghi chú, liên kết tài liệu và môn học',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            ],
          ),
        ),
        _buildAvatarStack(),
      ],
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 80,
      height: 36,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          _AvatarBubble(right: 0, label: '+${_notes.length.clamp(0, 99)}'),
          const _AvatarBubble(right: 18, label: 'UB', color: Color(0xFF3B82F6)),
          const _AvatarBubble(right: 36, label: 'SV', color: Color(0xFFC0C1FF)),
        ],
      ),
    );
  }

  Widget _buildStorageIndicator(int usedBytes) {
    final colors = StudentThemeScope.colorsOf(context);
    final progress = (usedBytes / _maxStorageBytes).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DUNG LƯỢNG GHI CHÚ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.textMuted,
              ),
            ),
            Text(
              '${_formatBytes(usedBytes)} / 5 GB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.primaryStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MiniStat(label: 'Ghi chú', value: '${_notes.length}'),
            const SizedBox(width: 8),
            _MiniStat(label: 'Tệp', value: '$_attachmentCount'),
          ],
        ),
      ],
    );
  }

  Widget _buildCreateCard() {
    final colors = StudentThemeScope.colorsOf(context);
    return GestureDetector(
      onTap: _showCreateChoiceSheet,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.tint(colors.primaryStrong, lightAlpha: 0.09),
              colors.surface.withValues(alpha: 0),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.tint(colors.primaryStrong),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.edit_note_outlined,
                color: colors.primaryStrong,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nhấn để Tạo Ghi Chú',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'hoặc đính kèm metadata tài liệu bằng URL',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: colors.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm ghi chú...',
          hintStyle: TextStyle(color: colors.textSubtle),
          prefixIcon: Icon(Icons.search, color: colors.textSubtle, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    final colors = StudentThemeScope.colorsOf(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _NoteFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primaryStrong
                      : colors.surfaceAlt.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? colors.onPrimary : colors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAsymmetricNoteCard(StudentNote note, int index) {
    final colors = StudentThemeScope.colorsOf(context);
    final type = _noteType(note);
    var radius = BorderRadius.circular(16);
    if (index.isOdd) {
      radius = const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(32),
      );
    }

    return GestureDetector(
      onTap: () => _openEditor(note),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: type.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(type.icon, color: type.color, size: 18),
                ),
                PopupMenuButton<_NoteAction>(
                  color: colors.surface,
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: colors.textMuted,
                  ),
                  onSelected: (action) {
                    if (action == _NoteAction.edit) {
                      _openEditor(note);
                    } else {
                      _deleteNote(note);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _NoteAction.edit,
                      child: Text('Chỉnh sửa'),
                    ),
                    PopupMenuItem(
                      value: _NoteAction.delete,
                      child: Text('Xóa'),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.content.isEmpty ? 'Chưa có nội dung.' : note.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_dateFormat.format(note.updatedAt.toLocal())} • ${_formatBytes(_noteSize(note))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: colors.textSubtle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = StudentThemeScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: colors.textSubtle.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 10),
          Text(
            _message ?? 'Không có ghi chú phù hợp',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<StudentNote> get _filteredNotes {
    final query = _searchQuery.trim().toLowerCase();
    return _notes.where((note) {
      final matchesSearch =
          query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note
              .displayTags(widget.courses)
              .any((tag) => tag.toLowerCase().contains(query));

      if (!matchesSearch) {
        return false;
      }

      return switch (_selectedFilter) {
        _NoteFilter.all => true,
        _NoteFilter.notes => note.attachmentCount == 0,
        _NoteFilter.attachments => note.attachmentCount > 0,
        _NoteFilter.courses => note.courseId != null,
      };
    }).toList();
  }

  int get _attachmentCount {
    return _notes.fold<int>(
      0,
      (total, note) => total + note.attachmentCount + note.attachments.length,
    );
  }

  int get _usedStorageBytes {
    return _notes.fold<int>(0, (total, note) => total + _noteSize(note));
  }

  int _noteSize(StudentNote note) {
    final attachmentSize = note.attachments.fold<int>(
      0,
      (total, attachment) => total + (attachment.size ?? 0),
    );
    final contentSize = (note.title.length + note.content.length) * 2;
    final countedAttachmentPlaceholder =
        note.attachmentCount > 0 && attachmentSize == 0
        ? note.attachmentCount * 512 * 1024
        : 0;
    return attachmentSize + countedAttachmentPlaceholder + contentSize;
  }

  _NoteType _noteType(StudentNote note) {
    final firstAttachmentType = note.attachments.firstOrNull?.fileType ?? '';
    if (firstAttachmentType.startsWith('image/')) {
      return const _NoteType(
        icon: Icons.image_outlined,
        color: Color(0xFFC0C1FF),
      );
    }
    if (firstAttachmentType.contains('spreadsheet')) {
      return const _NoteType(
        icon: Icons.table_chart_outlined,
        color: Color(0xFF10B981),
      );
    }
    if (note.attachmentCount > 0 || note.attachments.isNotEmpty) {
      return const _NoteType(
        icon: Icons.description_outlined,
        color: Color(0xFF3B82F6),
      );
    }
    return const _NoteType(icon: Icons.edit_note, color: Color(0xFF8B5CF6));
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.studentApi.listNotes(limit: 100);
      if (!mounted) {
        return;
      }
      setState(() {
        _notes
          ..clear()
          ..addAll(data.items);
        _message = data.message;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Không thể tải ghi chú lúc này.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditor(StudentNote? note) async {
    StudentNote? detail = note;
    if (note != null) {
      try {
        detail = await widget.studentApi.getNoteDetail(note.id);
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }

    if (!mounted) {
      return;
    }

    final draft = await Navigator.push<_StudentNoteDraft>(
      context,
      studentThemedRoute(
        context: context,
        builder: (context) =>
            _StudentNoteEditorPage(note: detail, courses: widget.courses),
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    await _saveNote(detail, draft);
  }

  Future<void> _saveNote(StudentNote? note, _StudentNoteDraft draft) async {
    setState(() => _isSaving = true);
    try {
      if (note == null) {
        await widget.studentApi.createNote(
          title: draft.title,
          content: draft.content,
          courseId: draft.courseId,
          attachments: draft.newAttachments,
        );
      } else {
        await widget.studentApi.updateNote(
          noteId: note.id,
          title: draft.title,
          content: draft.content,
          courseId: draft.courseId,
          newAttachments: draft.newAttachments,
          deletedAttachmentIds: draft.deletedAttachmentIds,
        );
      }
      await _loadNotes();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(note == null ? 'Đã thêm ghi chú.' : 'Đã lưu ghi chú.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteNote(StudentNote note) async {
    final colors = StudentThemeScope.colorsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Xóa ghi chú?', style: TextStyle(color: colors.text)),
        content: Text(
          'Bạn muốn xóa "${note.title}" khỏi UniBuddy?',
          style: TextStyle(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Color(0xFFFFB4AB)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.studentApi.deleteNote(note.id);
      await _loadNotes();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa ghi chú.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showCreateChoiceSheet() async {
    final colors = StudentThemeScope.colorsOf(context);
    final choice = await showModalBottomSheet<_CreateChoice>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChoiceTile(
                  icon: Icons.edit_note_outlined,
                  title: 'Tạo ghi chú mới',
                  subtitle: 'Viết nội dung và gắn môn học',
                  onTap: () => Navigator.pop(context, _CreateChoice.note),
                ),
                const SizedBox(height: 10),
                _ChoiceTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Đính kèm tài liệu bằng URL',
                  subtitle: 'Backend hiện nhận metadata tệp qua URL http/https',
                  onTap: () => Navigator.pop(context, _CreateChoice.attachment),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == _CreateChoice.note) {
      await _openEditor(null);
    } else if (choice == _CreateChoice.attachment) {
      await _createAttachmentNote();
    }
  }

  Future<void> _createAttachmentNote() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'txt'],
      withData: false,
    );

    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final attachment = await showDialog<_AttachmentNoteDraft>(
      context: context,
      builder: (context) => _AttachmentMetadataDialog(file: file),
    );

    if (attachment == null || !mounted) {
      return;
    }

    await _saveNote(
      null,
      _StudentNoteDraft(
        title: attachment.title,
        content: attachment.content,
        courseId: null,
        newAttachments: [attachment.attachment],
        deletedAttachmentIds: const [],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
    _sizeController = TextEditingController(text: '1024');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

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

  void _submit() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final size = int.tryParse(_sizeController.text.trim()) ?? 0;
    final uri = Uri.tryParse(url);

    if (name.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        size <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập tên file, URL http/https và dung lượng.',
          ),
        ),
      );
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.file.name);
    _urlController = TextEditingController();
    _contentController = TextEditingController(
      text: 'Tài liệu đính kèm: ${widget.file.name}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

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

  void _submit() {
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);
    if (title.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề và URL http/https.'),
        ),
      );
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
