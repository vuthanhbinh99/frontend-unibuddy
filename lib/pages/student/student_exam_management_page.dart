import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/student_course_models.dart';
import '../../models/student_exam_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';

class StudentExamManagementPage extends StatefulWidget {
  const StudentExamManagementPage({
    super.key,
    required this.studentApi,
  });

  final StudentApiService studentApi;

  @override
  State<StudentExamManagementPage> createState() =>
      _StudentExamManagementPageState();
}

class _StudentExamManagementPageState extends State<StudentExamManagementPage> {
  late Future<void> _loadFuture;
  List<StudentExamItem> _exams = [];
  List<StudentCourseItem> _courses = [];
  List<StudentSemester> _semesters = [];
  String? _examLoadWarning;
  bool _busy = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final courseData = await widget.studentApi.listCourses(tatCa: true);
    StudentExamData examData;
    String? examLoadWarning;

    try {
      examData = await widget.studentApi.listExams();
    } catch (error, stackTrace) {
      debugPrint('Load exams failed: $error\n$stackTrace');
      examData = const StudentExamData(
        message: 'Chưa tải được lịch thi',
        items: [],
      );
      examLoadWarning = _errorMessage(error);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _exams = examData.items;
      _courses = courseData.items;
      _semesters = courseData.semesters;
      _examLoadWarning = examLoadWarning;
    });
  }

  Future<void> _reload() async {
    setState(() => _loadFuture = _load());
    await _loadFuture;
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('HH:mm - dd/MM/yyyy').format(value.toLocal());
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd/MM/yyyy').format(value.toLocal());
  }

  String _errorMessage(Object error) {
    return error is ApiException ? error.message : 'Có lỗi xảy ra, vui lòng thử lại.';
  }

  bool _isExamAlreadyExistsError(Object error) {
    if (error is! ApiException || error.statusCode != 409) {
      return false;
    }
    final details = error.details;
    return details is Map && details['reasonCode'] == 'EXAM_ALREADY_EXISTS';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmOverwriteExamData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ghi đè lịch thi'),
        content: const Text('Bạn có muốn tiếp tục ghi đè dữ liệu ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _showExamForm({StudentExamItem? exam}) async {
    if (_courses.isEmpty) {
      _showSnack('Bạn cần thêm môn học trước khi tạo lịch thi.');
      return;
    }

    final result = await showModalBottomSheet<_ExamFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExamFormSheet(
        courses: _courses,
        exam: exam,
      ),
    );

    if (result == null) {
      return;
    }

    final hasExistingExam =
        exam == null && _exams.any((item) => item.courseId == result.course.id);
    if (hasExistingExam) {
      final confirmedOverwrite = await _confirmOverwriteExamData();
      if (!confirmedOverwrite) {
        return;
      }
    }
    if (!mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      if (exam == null) {
        Future<StudentExamItem> create({required bool replaceExistingExam}) {
          return widget.studentApi.createExam(
            courseId: result.course.id,
            examTime: result.examTime,
            room: result.room,
            examLocation: result.examLocation,
            replaceExistingExam: replaceExistingExam,
          );
        }

        try {
          await create(replaceExistingExam: hasExistingExam);
        } catch (error) {
          if (hasExistingExam || !_isExamAlreadyExistsError(error)) {
            rethrow;
          }

          final confirmedOverwrite = await _confirmOverwriteExamData();
          if (!confirmedOverwrite || !mounted) {
            return;
          }
          await create(replaceExistingExam: true);
        }
        _showSnack('Thêm lịch thi thành công');
      } else {
        await widget.studentApi.updateExam(
          examId: exam.id,
          courseId: result.course.id,
          examTime: result.examTime,
          room: result.room,
          examLocation: result.examLocation,
        );
        _showSnack('Cập nhật lịch thi thành công');
      }
      await _reload();
    } catch (error) {
      _showSnack(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteExam(StudentExamItem exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch thi'),
        content: Text('Bạn có chắc chắn muốn xóa lịch thi môn ${exam.courseName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.studentApi.deleteExam(examId: exam.id);
      _showSnack('Đã xóa lịch thi thành công');
      await _reload();
    } catch (error) {
      _showSnack(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importWithAi() async {
    if (_importing) {
      return;
    }

    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
      withData: true,
    );
    if (!mounted || pickedFile == null || pickedFile.files.isEmpty) {
      return;
    }

    final file = pickedFile.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('Không thể đọc nội dung file đã chọn.');
      return;
    }

    final semesterId = await _chooseImportSemester();
    if (!mounted) {
      return;
    }

    setState(() => _importing = true);
    try {
      final headers = await widget.studentApi.extractExamImportHeaders(
        bytes: bytes,
        fileName: file.name,
      );
      var mapping = headers.suggestedMapping;
      try {
        mapping = await widget.studentApi.suggestExamImportMappingWithAi(
          headers: headers.headers,
          sampleRows: headers.rows.take(12).toList(),
        );
      } catch (_) {
        mapping = headers.suggestedMapping;
      }
      final preview = await widget.studentApi.previewExamImport(
        rows: headers.rows,
        mapping: mapping,
        maHocKy: semesterId,
      );

      if (!mounted) {
        return;
      }
      final confirm = await _showImportPreview(preview, mapping);
      if (confirm != true) {
        return;
      }

      if (preview.validItems.isEmpty) {
        _showSnack('Không có dòng lịch thi hợp lệ để import.');
        return;
      }

      var replaceExistingExams = false;
      if (preview.hasExistingExam) {
        replaceExistingExams = await _confirmOverwriteExamData();
        if (!replaceExistingExams || !mounted) {
          return;
        }
      }

      Future<StudentExamImportConfirmData> confirmImport({
        required bool replaceExistingExams,
      }) {
        return widget.studentApi.confirmExamImport(
          items: preview.validItems,
          replaceExistingExams: replaceExistingExams,
        );
      }

      late final StudentExamImportConfirmData result;
      try {
        result = await confirmImport(replaceExistingExams: replaceExistingExams);
      } catch (error) {
        if (replaceExistingExams || !_isExamAlreadyExistsError(error)) {
          rethrow;
        }

        final confirmedOverwrite = await _confirmOverwriteExamData();
        if (!confirmedOverwrite || !mounted) {
          return;
        }
        result = await confirmImport(replaceExistingExams: true);
      }
      _showSnack('Đã import ${result.importedCount} lịch thi');
      await _reload();
    } catch (error) {
      _showSnack(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<String?> _chooseImportSemester() async {
    if (_semesters.isEmpty) {
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SemesterPickerSheet(semesters: _semesters),
    );
  }

  Future<bool?> _showImportPreview(
    StudentExamImportPreviewData preview,
    StudentExamImportMapping mapping,
  ) {
    final colors = StudentThemeScope.colorsOf(context);
    final displayMapping = preview.mapping ?? mapping;
    final mappings = <String, String?>{
      'Mã môn': displayMapping.maMon,
      'Tên môn': displayMapping.tenMon,
      'Thời gian thi': displayMapping.thoiGianThi,
      'Ngày thi': displayMapping.ngayThi,
      'Giờ bắt đầu': displayMapping.gioBatDau,
      'Phòng thi': displayMapping.phongThi,
      'Địa điểm thi': displayMapping.diaDiemThi,
    }.entries.where((entry) => entry.value != null).toList();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xem trước import lịch thi'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ImportStatChip(
                    label: 'Hợp lệ',
                    value: preview.validRows.toString(),
                    color: Colors.greenAccent,
                  ),
                  _ImportStatChip(
                    label: 'Cần kiểm tra',
                    value: preview.invalidRows.toString(),
                    color: Colors.orangeAccent,
                  ),
                  if (preview.existingExamRows > 0)
                    _ImportStatChip(
                      label: 'Đã có lịch thi',
                      value: preview.existingExamRows.toString(),
                      color: Colors.lightBlueAccent,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Cột đã mapping',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mappings
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
              if (preview.invalidRows > 0) ...[
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: preview.items
                          .where((item) => !item.isValid)
                          .take(8)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Dòng ${item.rowIndex}: ${item.errors.join(', ')}',
                                style: TextStyle(color: colors.textMuted),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
              if (preview.existingExamRows > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Một số môn đã có lịch thi. Khi tiếp tục, hệ thống sẽ hỏi xác nhận ghi đè dữ liệu.',
                  style: TextStyle(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: preview.validRows == 0
                ? null
                : () => Navigator.of(context).pop(true),
            child: Text('Import ${preview.validRows} dòng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final upcoming = _exams
        .where((exam) => exam.examTime.isAfter(DateTime.now()))
        .toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Lịch thi'),
        actions: [
          IconButton(
            tooltip: 'AI import',
            onPressed: _importing ? null : () => _importWithAi(),
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.sparkles),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : () => _showExamForm(),
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _loadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _exams.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && _exams.isEmpty) {
                return _EmptyExamState(
                  title: 'Không thể tải lịch thi',
                  subtitle: _errorMessage(snapshot.error!),
                  onAction: _reload,
                  actionLabel: 'Thử lại',
                );
              }
              if (_exams.isEmpty) {
                if (_examLoadWarning != null) {
                  return _EmptyExamState(
                    title: 'Chưa tải được lịch thi',
                    subtitle:
                        'Môn học đã tải được, nhưng lịch thi chưa phản hồi: $_examLoadWarning',
                    onAction: _reload,
                    actionLabel: 'Thử lại',
                  );
                }
                return _EmptyExamState(
                  title: 'Chưa có lịch thi',
                  subtitle:
                      'Thêm thủ công hoặc dùng AI import để hệ thống nhắc bạn trước ngày thi.',
                  onAction: _importWithAi,
                  actionLabel: 'AI import',
                );
              }

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _ExamSummaryBanner(
                      total: _exams.length,
                      upcoming: upcoming.length,
                    ),
                    const SizedBox(height: 14),
                    ..._exams.map(
                      (exam) => _ExamCard(
                        exam: exam,
                        onEdit: () => _showExamForm(exam: exam),
                        onDelete: () => _deleteExam(exam),
                        formatDate: _formatDate,
                        formatDateTime: _formatDateTime,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExamSummaryBanner extends StatelessWidget {
  const _ExamSummaryBanner({
    required this.total,
    required this.upcoming,
  });

  final int total;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.calendar, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$upcoming lịch thi sắp tới',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tổng cộng $total lịch thi, hệ thống nhắc trước 1 ngày.',
                  style: TextStyle(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.onEdit,
    required this.onDelete,
    required this.formatDate,
    required this.formatDateTime,
  });

  final StudentExamItem exam;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(DateTime value) formatDate;
  final String Function(DateTime value) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(text: exam.courseCode ?? 'Môn học'),
                    _Tag(text: exam.semesterName),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            exam.courseName,
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: Icons.schedule,
                label: formatDateTime(exam.examTime),
              ),
              _InfoPill(
                icon: Icons.event,
                label: formatDate(exam.examTime),
              ),
              if (exam.room != null)
                _InfoPill(icon: Icons.location_on_outlined, label: exam.room!),
              if (exam.examLocation != null)
                _InfoPill(icon: Icons.map_outlined, label: exam.examLocation!),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.primaryStrong),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: colors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ImportStatChip extends StatelessWidget {
  const _ImportStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(radius: 5, backgroundColor: color),
      label: Text('$label: $value'),
    );
  }
}

class _EmptyExamState extends StatelessWidget {
  const _EmptyExamState({
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendar, size: 44, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => onAction(),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterPickerSheet extends StatelessWidget {
  const _SemesterPickerSheet({required this.semesters});

  final List<StudentSemester> semesters;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn học kỳ để đối chiếu môn',
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tất cả học kỳ'),
            subtitle: const Text('Dùng khi mã môn không bị trùng giữa các học kỳ'),
            onTap: () => Navigator.of(context).pop(null),
          ),
          ...semesters.map(
            (semester) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(semester.name),
              onTap: () => Navigator.of(context).pop(semester.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamFormResult {
  const _ExamFormResult({
    required this.course,
    required this.examTime,
    required this.room,
    required this.examLocation,
  });

  final StudentCourseItem course;
  final DateTime examTime;
  final String? room;
  final String? examLocation;
}

class _ExamFormSheet extends StatefulWidget {
  const _ExamFormSheet({
    required this.courses,
    this.exam,
  });

  final List<StudentCourseItem> courses;
  final StudentExamItem? exam;

  @override
  State<_ExamFormSheet> createState() => _ExamFormSheetState();
}

class _ExamFormSheetState extends State<_ExamFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late StudentCourseItem _selectedCourse;
  late DateTime _examTime;
  late TextEditingController _roomController;
  late TextEditingController _examLocationController;

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.courses.firstWhere(
      (course) => course.id == widget.exam?.courseId,
      orElse: () => widget.courses.first,
    );
    _examTime = widget.exam?.examTime.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    _roomController = TextEditingController(text: widget.exam?.room ?? '');
    _examLocationController = TextEditingController(text: widget.exam?.examLocation ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    _examLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _examTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _examTime.hour,
        _examTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_examTime),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _examTime = DateTime(
        _examTime.year,
        _examTime.month,
        _examTime.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _ExamFormResult(
        course: _selectedCourse,
        examTime: _examTime,
        room: _roomController.text.trim().isEmpty
            ? null
            : _roomController.text.trim(),
        examLocation: _examLocationController.text.trim().isEmpty
            ? null
            : _examLocationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            18,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exam == null ? 'Thêm lịch thi' : 'Sửa lịch thi',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StudentCourseItem>(
                value: _selectedCourse,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Môn học'),
                items: widget.courses
                    .map(
                      (course) => DropdownMenuItem(
                        value: course,
                        child: Text(
                          '${course.code ?? 'Môn'} - ${course.name} (${course.semesterName})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (course) {
                  if (course != null) {
                    setState(() => _selectedCourse = course);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(DateFormat('dd/MM/yyyy').format(_examTime)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(DateFormat('HH:mm').format(_examTime)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(labelText: 'Phòng thi'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _examLocationController,
                decoration: const InputDecoration(labelText: 'Địa điểm thi'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

