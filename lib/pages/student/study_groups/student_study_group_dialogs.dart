part of 'student_study_groups_page.dart';

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog({required this.onSubmit});

  final Future<StudentStudyGroup> Function(String inviteCode) onSubmit;

  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colors.surface,
      title: Text(
        'Tham gia nhóm',
        style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_saving,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            style: TextStyle(color: colors.text),
            decoration: InputDecoration(
              labelText: 'Mã mời',
              labelStyle: TextStyle(color: colors.primaryStrong),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            StudentInlineMessage(message: _errorMessage!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryStrong,
          ),
          child: Text(
            _saving ? 'Đang tham gia...' : 'Tham gia',
            style: TextStyle(color: colors.onPrimary),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final inviteCode = _controller.text.trim();
    if (inviteCode.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mã mời.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final group = await widget.onSubmit(inviteCode);
      if (mounted) {
        Navigator.pop(context, group);
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
        _errorMessage = 'Không thể tham gia nhóm lúc này.';
      });
    }
  }
}

class _DeleteGroupPasswordDialog extends StatefulWidget {
  const _DeleteGroupPasswordDialog();

  @override
  State<_DeleteGroupPasswordDialog> createState() =>
      _DeleteGroupPasswordDialogState();
}

class _DeleteGroupPasswordDialogState
    extends State<_DeleteGroupPasswordDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Xác nhận giải tán',
        style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: _controller,
        obscureText: true,
        style: TextStyle(color: colors.text),
        decoration: InputDecoration(
          labelText: 'Mật khẩu tài khoản',
          labelStyle: TextStyle(color: colors.primaryStrong),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Xóa nhóm'),
        ),
      ],
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.courses, required this.onSubmit});

  final List<_GroupCourseOption> courses;
  final Future<StudentStudyGroup> Function(_CreateGroupResult result) onSubmit;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _chatLinkController = TextEditingController();
  String? _selectedCourseId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courses.isEmpty ? null : widget.courses.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _chatLinkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final courseId = _selectedCourseId;
    if (name.isEmpty || courseId == null) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tên nhóm và chọn môn học.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final group = await widget.onSubmit(
        _CreateGroupResult(
          name: name,
          courseId: courseId,
          chatLink: _chatLinkController.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.pop(context, group);
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
        _errorMessage = 'Không thể tạo nhóm lúc này.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colors.surface,
      title: Text(
        'Tạo nhóm học tập mới',
        style: TextStyle(fontWeight: FontWeight.bold, color: colors.text),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_saving,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedCourseId,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Môn học trong TKB'),
              selectedItemBuilder: (context) {
                return widget.courses
                    .map(
                      (course) => Text(
                        course.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList();
              },
              items: widget.courses
                  .map(
                    (course) => DropdownMenuItem(
                      value: course.id,
                      child: Text(
                        course.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _selectedCourseId = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chatLinkController,
              enabled: !_saving,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Link nhóm chat'),
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
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryStrong,
          ),
          child: Text(
            _saving ? 'Đang tạo...' : 'Tạo nhóm',
            style: TextStyle(color: colors.onPrimary),
          ),
        ),
      ],
    );
  }
}
