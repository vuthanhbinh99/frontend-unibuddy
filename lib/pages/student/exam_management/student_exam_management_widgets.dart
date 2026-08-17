part of 'student_exam_management_page.dart';

class _ExamSummaryBanner extends StatelessWidget {
  const _ExamSummaryBanner({required this.total, required this.upcoming});

  final int total;
  final int upcoming;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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
              _InfoPill(icon: Icons.event, label: formatDate(exam.examTime)),
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

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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
            FilledButton(onPressed: () => onAction(), child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _SemesterPickerSheet extends StatelessWidget {
  const _SemesterPickerSheet({required this.semesters});

  final List<StudentSemester> semesters;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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
            subtitle: const Text(
              'Dùng khi mã môn không bị trùng giữa các học kỳ',
            ),
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
  const _ExamFormSheet({required this.courses, this.exam});

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

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.courses.firstWhere(
      (course) => course.id == widget.exam?.courseId,
      orElse: () => widget.courses.first,
    );
    _examTime =
        widget.exam?.examTime.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    _roomController = TextEditingController(text: widget.exam?.room ?? '');
    _examLocationController = TextEditingController(
      text: widget.exam?.examLocation ?? '',
    );
  }

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _roomController.dispose();
    _examLocationController.dispose();
    super.dispose();
  }

  /// Xử lý sự kiện pick date từ người dùng hoặc hệ thống.
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

  /// Xử lý sự kiện pick time từ người dùng hoặc hệ thống.
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

  /// Xử lý thao tác submit và đồng bộ kết quả với UI.
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

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
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
