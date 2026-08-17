part of 'student_kanban_page.dart';

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({required this.members, required this.onSubmit});

  final List<StudentKanbanMember> members;
  final Future<void> Function(_KanbanTaskFormResult result) onSubmit;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  static const String _assignAllValue = '__ALL_MEMBERS__';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _assigneeId;
  bool _assignAllMembers = false;
  DateTime? _dueDate;
  bool _saving = false;
  String? _errorMessage;

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Xử lý sự kiện pick due date từ người dùng hoặc hệ thống.
  Future<void> _pickDueDate() async {
    final picked = await pickKanbanDueDateTime(context, _dueDate);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _dueDate = picked;
    });
  }

  /// Xử lý thao tác submit và đồng bộ kết quả với UI.
  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tiêu đề công việc.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(
        _KanbanTaskFormResult(
          title: title,
          description: _descriptionController.text.trim(),
          dueDate: _dueDate,
          assigneeId: _assignAllMembers ? null : _assigneeId,
          assignAllMembers: _assignAllMembers,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorMessage = 'Không thể thêm công việc lúc này.';
      });
    }
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.borderStrong,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Đầu việc Flutter Mới',
              style: TextStyle(
                fontSize: 20,
                color: colors.text,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              StudentInlineMessage(message: _errorMessage!),
            ],
            const SizedBox(height: 18),
            _KanbanTextField(
              controller: _titleController,
              label: 'Tiêu đề',
              hint: 'Nhập tên công việc',
            ),
            const SizedBox(height: 12),
            _KanbanTextField(
              controller: _descriptionController,
              label: 'Mô tả',
              hint: 'Nhiệm vụ được tạo từ Flutter widget tree.',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _assignAllMembers ? _assignAllValue : _assigneeId,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.text),
              decoration: _fieldDecoration('Người phụ trách'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Chưa gán'),
                ),
                const DropdownMenuItem<String?>(
                  value: _assignAllValue,
                  child: Text('Tất cả thành viên nhóm'),
                ),
                ...widget.members.map(
                  (member) => DropdownMenuItem<String?>(
                    value: member.id,
                    child: Text(member.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  if (value == _assignAllValue) {
                    _assignAllMembers = true;
                    _assigneeId = null;
                    return;
                  }
                  _assignAllMembers = false;
                  _assigneeId = value;
                });
              },
            ),
            if (_assignAllMembers) ...[
              const SizedBox(height: 6),
              Text(
                'Task sẽ gửi thông báo cho toàn bộ thành viên trong nhóm.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _fieldDecoration('Hạn hoàn thành (ngày & giờ)'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.indigoAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _dueDate == null
                          ? 'Chưa chọn hạn'
                          : _formatDueDate(_dueDate),
                      style: TextStyle(color: colors.text),
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _dueDate = null;
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Thêm công việc'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hàm hỗ trợ field decoration cho màn hình trong file này.
  InputDecoration _fieldDecoration(String label) {
    final colors = StudentThemeScope.colorsOf(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.primaryStrong, fontSize: 13),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

class _KanbanTaskFormResult {
  const _KanbanTaskFormResult({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.assigneeId,
    required this.assignAllMembers,
  });

  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? assigneeId;
  final bool assignAllMembers;
}

class _KanbanTextField extends StatelessWidget {
  const _KanbanTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: colors.primaryStrong, fontSize: 13),
        hintStyle: TextStyle(color: colors.textSubtle, fontSize: 13),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.radius});

  final StudentKanbanMember member;
  final double radius;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final avatarColor = _avatarColor(member.id);
    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor,
      child: Text(
        member.initials,
        style: TextStyle(
          fontSize: radius * 0.55,
          color: colors.onColor(avatarColor),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Hàm hỗ trợ avatar color cho màn hình trong file này.
  Color _avatarColor(String seed) {
    final colors = [
      Colors.indigoAccent,
      Colors.cyan,
      Colors.pinkAccent,
      Colors.amber,
      Colors.greenAccent,
    ];
    final hash = seed.runes.fold<int>(0, (value, rune) => value + rune);
    return colors[hash % colors.length];
  }
}

class _EmptyKanbanState extends StatelessWidget {
  const _EmptyKanbanState({
    required this.hasGroups,
    required this.onSelectGroup,
  });

  final bool hasGroups;
  final VoidCallback onSelectGroup;

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.view_kanban_outlined,
                color: colors.primaryStrong,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasGroups ? 'Chọn nhóm học tập' : 'Chưa có nhóm học tập',
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasGroups
                  ? 'Chọn một nhóm để xem công việc, thành viên và thảo luận.'
                  : 'Hãy vào trang Quản lý nhóm để tạo hoặc tham gia một nhóm học tập trước.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (hasGroups) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onSelectGroup,
                child: const Text('Chọn nhóm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mở lần lượt hộp chọn ngày rồi chọn giờ, trả về mốc hạn hoàn thành (giờ local).
/// Trả về null nếu người dùng huỷ ở bước chọn ngày. Mặc định giờ 23:59 khi chưa có.
Future<DateTime?> pickKanbanDueDateTime(
  BuildContext context,
  DateTime? current,
) async {
  final colors = StudentThemeScope.colorsOf(context);
  final now = DateTime.now();
  final currentLocal = current?.toLocal();

  /// Dựng widget apply theme phục vụ giao diện trong file này.
  Widget applyTheme(BuildContext context, Widget? child) {
    return Theme(
      data: buildStudentMaterialTheme(colors).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: colors.primaryStrong,
          brightness: colors.brightness,
        ).copyWith(primary: colors.primaryStrong, surface: colors.surface),
      ),
      child: child!,
    );
  }

  final date = await showDatePicker(
    context: context,
    initialDate: currentLocal ?? now.add(const Duration(days: 1)),
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365 * 4)),
    builder: applyTheme,
  );

  if (date == null || !context.mounted) {
    return null;
  }

  final initialTime = currentLocal != null
      ? TimeOfDay.fromDateTime(currentLocal)
      : const TimeOfDay(hour: 23, minute: 59);
  final time = await showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: applyTheme,
  );

  final chosenTime = time ?? initialTime;
  return DateTime(
    date.year,
    date.month,
    date.day,
    chosenTime.hour,
    chosenTime.minute,
  );
}

String _formatDueDate(DateTime? date) {
  if (date == null) {
    return 'Không hạn';
  }
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day Th$month $hour:$minute';
}

String _formatRelativeTime(DateTime? date) {
  if (date == null) {
    return 'Vừa xong';
  }
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) {
    return 'Vừa xong';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes} phút trước';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours} giờ trước';
  }
  return '${diff.inDays} ngày trước';
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return '?';
  }

  /// Hàm hỗ trợ first letter cho màn hình trong file này.
  String firstLetter(String value) {
    return String.fromCharCode(value.runes.first).toUpperCase();
  }

  if (words.length == 1) {
    return firstLetter(words.first);
  }
  return '${firstLetter(words.first)}${firstLetter(words.last)}';
}
