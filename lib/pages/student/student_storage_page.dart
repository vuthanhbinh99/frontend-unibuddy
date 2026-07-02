import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/student_course_models.dart';
import '../../models/student_storage_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentStoragePage extends StatefulWidget {
  const StudentStoragePage({
    super.key,
    required this.studentApi,
    this.initialCourses = const [],
    this.onViewAllNotifications,
  });

  final StudentApiService studentApi;
  final List<StudentCourseItem> initialCourses;
  final VoidCallback? onViewAllNotifications;

  @override
  State<StudentStoragePage> createState() => _StudentStoragePageState();
}

class _StudentStoragePageState extends State<StudentStoragePage> {
  final TextEditingController _searchController = TextEditingController();
  StudentStorageCategory _selectedCategory = StudentStorageCategory.all;
  String _searchQuery = '';
  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;
  StudentStorageData? _data;
  List<StudentCourseItem> _courses = [];

  static const Map<String, String> _mimeByExtension = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
  };

  static const int _documentMaxBytes = 20 * 1024 * 1024;
  static const int _videoMaxBytes = 100 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _courses = widget.initialCourses;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      final results = await Future.wait<Object>([
        widget.studentApi.listStorageDocuments(limit: 100),
        if (_courses.isEmpty) widget.studentApi.listCourses(),
      ]);
      final storage = results.first as StudentStorageData;
      final courses = results.length > 1
          ? (results[1] as StudentCourseData).items
          : _courses;

      if (!mounted) {
        return;
      }

      setState(() {
        _data = storage;
        _courses = courses;
        _loading = false;
        _refreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
        _errorMessage = 'Không thể tải kho lưu trữ lúc này.';
      });
    }
  }

  List<StudentStorageFile> get _filteredFiles {
    final query = _searchQuery.trim().toLowerCase();
    return (_data?.items ?? const []).where((file) {
      final matchesCategory =
          _selectedCategory == StudentStorageCategory.all ||
          file.category == _selectedCategory;
      final matchesSearch =
          query.isEmpty ||
          file.name.toLowerCase().contains(query) ||
          file.authorLabel.toLowerCase().contains(query) ||
          file.courseLabel.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final filteredFiles = _filteredFiles;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: _Glow(color: colors.primaryStrong.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: _Glow(color: colors.info.withValues(alpha: 0.08)),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _loadData(silent: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildTeamInfo(),
                    const SizedBox(height: 24),
                    _buildStorageProgress(),
                    const SizedBox(height: 20),
                    _buildUploadBox(),
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildCategories(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildBody(filteredFiles)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _showAiCoPilot,
              backgroundColor: colors.primaryStrong,
              foregroundColor: colors.onPrimary,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                'Hỏi AI Trợ Lý',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRoundIconButton(Icons.arrow_back, () => Navigator.pop(context)),
        Text(
          'Lưu Trữ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        StudentNotificationBell(
          studentApi: widget.studentApi,
          onViewAll: widget.onViewAllNotifications,
          icon: Icons.notifications_outlined,
          iconColor: colors.text,
          backgroundColor: colors.surfaceAlt.withValues(alpha: 0.75),
          borderColor: colors.border,
        ),
      ],
    );
  }

  Widget _buildTeamInfo() {
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
                'Không Gian Lưu Trữ UniBuddy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_data?.total ?? 0} tài liệu học tập đã đồng bộ',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildMemberAvatars(),
      ],
    );
  }

  Widget _buildStorageProgress() {
    final colors = StudentThemeScope.colorsOf(context);
    final used = _data?.totalBytes ?? 0;
    final max = _data?.storageMaxBytes ?? 5 * 1024 * 1024 * 1024;
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DUNG LƯỢNG LƯU TRỮ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${formatStudentStorageBytes(used)} / ${formatStudentStorageBytes(max)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    final colors = StudentThemeScope.colorsOf(context);
    return InkWell(
      onTap: _startUploadFlow,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.primaryStrong.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryStrong.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                color: colors.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn để Tải Lên Tệp',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Hỗ trợ Word, Excel, PNG, PDF, Video',
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = StudentThemeScope.colorsOf(context);
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        hintText: 'Tìm kiếm tài liệu...',
        hintStyle: TextStyle(color: colors.textSubtle, fontSize: 13),
        prefixIcon: Icon(Icons.search, color: colors.textSubtle, size: 18),
        filled: true,
        fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final colors = StudentThemeScope.colorsOf(context);
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: StudentStorageCategory.values.length,
        itemBuilder: (context, index) {
          final category = StudentStorageCategory.values[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? colors.onPrimary : colors.textMuted,
                ),
              ),
              selected: isSelected,
              selectedColor: colors.primaryStrong,
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              onSelected: (_) => setState(() => _selectedCategory = category),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<StudentStorageFile> filteredFiles) {
    final colors = StudentThemeScope.colorsOf(context);
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          valueColor: AlwaysStoppedAnimation<Color>(colors.primaryStrong),
        ),
      );
    }

    if (_errorMessage != null) {
      return _StorageErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    if (filteredFiles.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy tài liệu phù hợp.',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.only(bottom: 98),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: filteredFiles.length,
          itemBuilder: (context, index) {
            final file = filteredFiles[index];
            return _buildBentoCard(file, isFullWidth: index == 0);
          },
        ),
        if (_refreshing)
          const Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildRoundIconButton(IconData icon, VoidCallback onTap) {
    final colors = StudentThemeScope.colorsOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: 0.75),
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, color: colors.text, size: 20),
      ),
    );
  }

  Widget _buildMemberAvatars() {
    final authors = (_data?.items ?? const [])
        .map((file) => file.authorLabel)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .take(3)
        .toList();

    if (authors.isEmpty) {
      authors.addAll(['U', 'B']);
    }

    return SizedBox(
      height: 32,
      width: 32.0 + (authors.length - 1) * 24 + 18,
      child: Stack(
        children: [
          for (var i = 0; i < authors.length; i++)
            Positioned(
              left: i * 24,
              child: _AvatarInitial(label: authors[i]),
            ),
          if ((_data?.items.length ?? 0) > authors.length)
            Positioned(
              left: authors.length * 24,
              child: _AvatarInitial(
                label: '+${(_data?.items.length ?? 0) - authors.length}',
                compact: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBentoCard(StudentStorageFile file, {required bool isFullWidth}) {
    final colors = StudentThemeScope.colorsOf(context);
    final style = _fileStyle(context, file);

    return GestureDetector(
      onTap: () => _showFileDetails(file),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isFullWidth
                ? style.color.withValues(alpha: 0.18)
                : colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 18),
                ),
                Icon(Icons.more_vert, color: colors.textMuted, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${file.updatedLabel} • ${formatStudentStorageBytes(file.sizeBytes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startUploadFlow() async {
    if (_courses.isEmpty) {
      _showSnack('Hãy thêm học phần trước khi lưu tài liệu.');
      await _loadData(silent: true);
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _mimeByExtension.keys.toList(),
      withData: false,
    );

    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = _mimeByExtension[extension];
    if (mimeType == null) {
      _showSnack('Định dạng tệp chưa được backend hỗ trợ.');
      return;
    }

    final maxBytes = mimeType.startsWith('video/')
        ? _videoMaxBytes
        : _documentMaxBytes;
    if (file.size <= 0 || file.size > maxBytes) {
      _showSnack(
        'Tệp vượt quá dung lượng tối đa ${formatStudentStorageBytes(maxBytes)}.',
      );
      return;
    }

    final draft = await showModalBottomSheet<_StorageUploadDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StudentThemeScope.colorsOf(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _UploadDocumentSheet(
          fileName: file.name,
          sizeBytes: file.size,
          courses: _courses,
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    try {
      final bytes = await _readPickedFileBytes(file);
      await widget.studentApi.uploadSharedDocument(
        title: draft.title,
        courseId: draft.courseId,
        visibility: draft.visibility,
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
        sizeBytes: file.size,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Đã lưu tài liệu vào kho UniBuddy.');
      await _loadData(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Không thể đọc file đã chọn, vui lòng thử lại.');
      }
    }
  }

  Future<List<int>> _readPickedFileBytes(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) {
      return bytes;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const FileSystemException('Missing picked file path');
    }

    return File(path).readAsBytes();
  }

  void _showFileDetails(StudentStorageFile file) {
    final colors = StudentThemeScope.colorsOf(context);
    final style = _fileStyle(context, file);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.64,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(style.icon, color: style.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              file.categoryLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.primaryStrong,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Mô tả chi tiết',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${file.courseLabel} • ${file.visibility.label} • ${file.authorLabel}',
                    style: TextStyle(fontSize: 13, color: colors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primaryStrong.withValues(alpha: 0.08),
                      border: Border.all(
                        color: colors.primaryStrong.withValues(alpha: 0.18),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: colors.primaryStrong,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tóm Tắt Bằng AI (Gemini)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.primaryStrong,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _buildLocalSummary(file),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyLink(file),
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: const Text('Sao chép liên kết'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primaryStrong,
                            side: BorderSide(
                              color: colors.primaryStrong.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () => _confirmDelete(file),
                        icon: const Icon(Icons.delete_outline),
                        color: const Color(0xFFFFB4AB),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(StudentStorageFile file) async {
    final colors = StudentThemeScope.colorsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Xóa tài liệu', style: TextStyle(color: colors.text)),
        content: Text(
          'Bạn muốn xóa "${file.name}" khỏi kho lưu trữ?',
          style: TextStyle(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.studentApi.deleteStorageDocument(file.id);
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      _showSnack('Đã xóa tài liệu.');
      await _loadData(silent: true);
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<void> _copyLink(StudentStorageFile file) async {
    await Clipboard.setData(ClipboardData(text: file.downloadUrl));
    if (mounted) {
      _showSnack('Đã sao chép liên kết tài liệu.');
    }
  }

  String _buildLocalSummary(StudentStorageFile file) {
    return 'Tệp ${file.name} thuộc ${file.courseLabel}, dung lượng '
        '${formatStudentStorageBytes(file.sizeBytes)}. Tài liệu đang ở chế độ '
        '${file.visibility.label.toLowerCase()} và được cập nhật ${file.updatedLabel}.';
  }

  void _showAiCoPilot() {
    final colors = StudentThemeScope.colorsOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const _AssistantIcon(),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UniBuddy Co-pilot',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            'AI trợ lý đồng hành cùng kho học tập',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.border),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: const [
                      _ChatBubble(
                        text:
                            'Xin chào! Mình có thể giúp bạn rà soát tài liệu, gợi ý nhóm tệp quan trọng và tóm tắt nhanh kho lưu trữ UniBuddy.',
                        isAi: true,
                      ),
                      _ChatBubble(
                        text:
                            'Tóm tắt giúp mình các tài liệu mới nhất trong kho.',
                        isAi: false,
                      ),
                      _ChatBubble(
                        text:
                            'Bạn có thể mở từng tài liệu để xem tóm tắt metadata hiện có. Khi backend bổ sung AI/Gemini, phần này sẽ nối API phân tích nội dung thật.',
                        isAi: true,
                      ),
                    ],
                  ),
                ),
                _buildChatInputField(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatInputField() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: TextStyle(color: colors.text),
              decoration: InputDecoration(
                hintText: 'Hỏi Co-pilot...',
                hintStyle: TextStyle(color: colors.textSubtle, fontSize: 13),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () =>
                _showSnack('Backend chưa có API chat AI cho lưu trữ.'),
            icon: Icon(Icons.send, color: colors.primaryStrong),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập tên tài liệu hợp lệ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

class _AssistantIcon extends StatelessWidget {
  const _AssistantIcon();

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.primaryStrong.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.auto_awesome, color: colors.primaryStrong),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isAi});

  final String text;
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isAi ? colors.surface : colors.primaryStrong,
          borderRadius: BorderRadius.circular(16).copyWith(
            topLeft: isAi ? Radius.zero : const Radius.circular(16),
            topRight: isAi ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isAi ? colors.text : colors.onPrimary,
          ),
        ),
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
