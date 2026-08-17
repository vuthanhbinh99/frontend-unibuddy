part of 'student_kanban_page.dart';

class _TaskDetailsWidget extends StatefulWidget {
  const _TaskDetailsWidget({
    required this.task,
    required this.members,
    required this.comments,
    required this.scrollController,
    required this.canEdit,
    required this.onStatusChanged,
    required this.onComment,
    required this.onEditDue,
    required this.onTaskChanged,
  });

  final StudentKanbanTask task;
  final List<StudentKanbanMember> members;
  final List<StudentKanbanComment> comments;
  final ScrollController scrollController;
  final bool canEdit;
  final Future<StudentKanbanTask> Function(StudentKanbanStatus status)
  onStatusChanged;
  final Future<StudentKanbanComment> Function(String content) onComment;
  final Future<StudentKanbanTask> Function(DateTime? dueDate) onEditDue;
  final ValueChanged<StudentKanbanTask> onTaskChanged;

  @override
  State<_TaskDetailsWidget> createState() => _TaskDetailsWidgetState();
}

class _TaskDetailsWidgetState extends State<_TaskDetailsWidget> {
  late StudentKanbanTask _task;
  late List<StudentKanbanComment> _comments;
  final TextEditingController _commentController = TextEditingController();
  bool _sendingComment = false;
  bool _changingStatus = false;
  bool _editingDue = false;
  String? _errorMessage;

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _comments = [...widget.comments];
  }

  /// Giải phóng controller, listener hoặc tài nguyên khi widget bị hủy.
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Xử lý sự kiện change status từ người dùng hoặc hệ thống.
  Future<void> _changeStatus(StudentKanbanStatus? status) async {
    if (status == null || status == _task.status) {
      return;
    }
    if (status == StudentKanbanStatus.overdue) {
      setState(() {
        _errorMessage =
            'Trễ hạn do hệ thống tự cập nhật khi quá hạn, không chuyển thủ công.';
      });
      return;
    }

    setState(() {
      _changingStatus = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.onStatusChanged(status);
      if (!mounted) {
        return;
      }
      setState(() {
        _task = updated;
        _changingStatus = false;
      });
      widget.onTaskChanged(updated);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _changingStatus = false;
        _errorMessage = error.message;
      });
    }
  }

  /// Xử lý thao tác edit due và đồng bộ kết quả với UI.
  Future<void> _editDue() async {
    if (_editingDue) {
      return;
    }
    final picked = await pickKanbanDueDateTime(context, _task.dueDate);
    if (picked == null || !mounted || picked == _task.dueDate) {
      return;
    }

    setState(() {
      _editingDue = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.onEditDue(picked);
      if (!mounted) {
        return;
      }
      setState(() {
        _task = updated;
        _editingDue = false;
      });
      widget.onTaskChanged(updated);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _editingDue = false;
        _errorMessage = error.message;
      });
    }
  }

  /// Xử lý thao tác send comment và đồng bộ kết quả với UI.
  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sendingComment) {
      return;
    }

    setState(() {
      _sendingComment = true;
      _errorMessage = null;
    });
    try {
      final comment = await widget.onComment(content);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = [..._comments, comment];
        _task = _task.copyWith(commentCount: _task.commentCount + 1);
        _sendingComment = false;
      });
      _commentController.clear();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sendingComment = false;
        _errorMessage = error.message;
      });
    }
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final task = _task;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: colors.borderStrong,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: task.status == StudentKanbanStatus.overdue
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.indigo.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task.status == StudentKanbanStatus.overdue
                          ? 'TRỄ DEADLINE'
                          : task.status.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: task.status == StudentKanbanStatus.overdue
                            ? Colors.redAccent
                            : Colors.indigoAccent,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_changingStatus)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    DropdownButtonHideUnderline(
                      child: DropdownButton<StudentKanbanStatus>(
                        value: task.status,
                        dropdownColor: colors.surface,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        items: StudentKanbanStatus.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: _changeStatus,
                      ),
                    ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                StudentInlineMessage(message: _errorMessage!),
              ],
              const SizedBox(height: 15),
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                task.description?.trim().isNotEmpty == true
                    ? task.description!.trim()
                    : 'Chưa có mô tả chi tiết.',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.indigoAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hạn hoàn thành: ${_formatDueDate(task.dueDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.canEdit)
                      _editingDue
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton.icon(
                              onPressed: _editDue,
                              icon: const Icon(Icons.edit_calendar, size: 16),
                              label: const Text('Sửa'),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.primaryStrong,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Text(
                'Thảo luận nhóm',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 15),
              if (_comments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    task.commentCount > 0
                        ? 'Có ${task.commentCount} bình luận nhưng chưa tải được nội dung. Vui lòng tải lại bảng Kanban.'
                        : 'Chưa có thảo luận nào cho công việc này.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                )
              else
                ..._comments.map(_buildComment),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Thêm thảo luận...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: colors.textSubtle,
                    ),
                    fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: colors.primaryStrong),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  style: TextStyle(color: colors.text, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: _sendingComment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send, color: colors.primaryStrong),
                onPressed: _sendComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Dựng phần giao diện build comment cho màn hình hiện tại.
  Widget _buildComment(StudentKanbanComment comment) {
    final colors = StudentThemeScope.colorsOf(context);
    final avatarColor = Colors.indigoAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: avatarColor,
            child: Text(
              _initials(comment.authorName),
              style: TextStyle(
                fontSize: 10,
                color: colors.onColor(avatarColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceAlt.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          comment.authorName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatRelativeTime(comment.createdAt),
                        style: TextStyle(fontSize: 9, color: colors.textSubtle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    comment.content,
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
