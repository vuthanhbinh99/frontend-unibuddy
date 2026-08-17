import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import '../../../models/student_course_models.dart';
import '../../../models/student_note_models.dart';
import '../../../services/api/api_exception.dart';
import '../../../services/api/modules/student_api_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_inline_message.dart';
import '../widgets/student_notification_dropdown.dart';
part 'student_note_editor_page.dart';
part 'student_notes_dialogs.dart';

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
