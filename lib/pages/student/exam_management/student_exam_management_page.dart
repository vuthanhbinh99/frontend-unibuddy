import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/student_course_models.dart';
import '../../../models/student_exam_models.dart';
import '../../../services/api/api_exception.dart';
import '../../../services/api/modules/student_api_service.dart';
import '../theme/student_theme.dart';
part 'student_exam_management_widgets.dart';

class StudentExamManagementPage extends StatefulWidget {
  const StudentExamManagementPage({super.key, required this.studentApi});

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
    return error is ApiException
        ? error.message
        : 'Có lỗi xảy ra, vui lòng thử lại.';
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      builder: (context) => _ExamFormSheet(courses: _courses, exam: exam),
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
        content: Text(
          'Bạn có chắc chắn muốn xóa lịch thi môn ${exam.courseName}?',
        ),
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
        result = await confirmImport(
          replaceExistingExams: replaceExistingExams,
        );
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
