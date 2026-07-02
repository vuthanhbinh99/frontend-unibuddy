import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/student_kanban_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

enum _TaskPriority { high, medium, low }

class StudentKanbanPage extends StatefulWidget {
  const StudentKanbanPage({
    super.key,
    required this.studentApi,
    this.initialGroupId,
    this.onViewAllNotifications,
  });

  final StudentApiService studentApi;
  final String? initialGroupId;
  final VoidCallback? onViewAllNotifications;

  @override
  State<StudentKanbanPage> createState() => _StudentKanbanPageState();
}

class _StudentKanbanPageState extends State<StudentKanbanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _groupIdController = TextEditingController();
  final Map<String, List<StudentKanbanComment>> _sessionComments = {};

  StudentKanbanBoardData? _board;
  List<StudentKanbanTask> _tasks = [];
  String? _activeGroupId;
  String? _errorMessage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final initialGroupId = widget.initialGroupId?.trim();
    if (initialGroupId != null && initialGroupId.isNotEmpty) {
      _activeGroupId = initialGroupId;
      _groupIdController.text = initialGroupId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBoard(initialGroupId);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupIdController.dispose();
    super.dispose();
  }

  Future<void> _loadBoard([String? groupId]) async {
    final targetGroupId = (groupId ?? _activeGroupId ?? '').trim();
    if (targetGroupId.isEmpty) {
      await _openGroupDialog();
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _activeGroupId = targetGroupId;
      _groupIdController.text = targetGroupId;
    });

    try {
      final board = await widget.studentApi.getKanbanBoard(targetGroupId);
      if (!mounted) {
        return;
      }
      setState(() {
        _board = board;
        _tasks = _sortTasks(board.tasks);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = 'Không thể tải bảng Kanban lúc này.';
      });
    }
  }

  Future<void> _openGroupDialog() async {
    final colors = StudentThemeScope.colorsOf(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Chọn nhóm học tập',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _groupIdController,
            autofocus: true,
            style: TextStyle(color: colors.text),
            decoration: InputDecoration(
              hintText: 'Nhập mã nhóm học tập',
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _groupIdController.text.trim()),
              child: const Text('Tải bảng'),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      await _loadBoard(result);
    }
  }

  void _openCreateTaskSheet() {
    final colors = StudentThemeScope.colorsOf(context);
    final groupId = _activeGroupId?.trim();
    if (groupId == null || groupId.isEmpty) {
      _openGroupDialog();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return _TaskFormSheet(
          members: _board?.members ?? const [],
          onSubmit: (result) async {
            final task = await widget.studentApi.createKanbanTask(
              groupId: groupId,
              title: result.title,
              description: result.description,
              dueDate: result.dueDate,
              assigneeId: result.assigneeId,
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _tasks = _sortTasks([..._tasks, task]);
            });
            _showSnack('Đã thêm công việc vào Kanban.');
          },
        );
      },
    );
  }

  void _openTaskDetails(StudentKanbanTask task) {
    final colors = StudentThemeScope.colorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return _TaskDetailsWidget(
              task: task,
              members: _board?.members ?? const [],
              comments: _sessionComments[task.id] ?? const [],
              scrollController: scrollController,
              onStatusChanged: (status) => _changeTaskStatus(task, status),
              onComment: (content) => _commentTask(task, content),
              onTaskChanged: _replaceTask,
            );
          },
        );
      },
    );
  }

  Future<StudentKanbanTask> _changeTaskStatus(
    StudentKanbanTask task,
    StudentKanbanStatus status,
  ) async {
    final updated = await widget.studentApi.updateKanbanTaskStatus(
      taskId: task.id,
      status: status,
      position: task.position <= 0 ? null : task.position,
    );
    if (mounted) {
      _replaceTask(updated);
      _showSnack('Đã cập nhật trạng thái công việc.');
    }
    return updated;
  }

  Future<StudentKanbanComment> _commentTask(
    StudentKanbanTask task,
    String content,
  ) async {
    final comment = await widget.studentApi.commentKanbanTask(
      taskId: task.id,
      content: content,
    );
    if (mounted) {
      setState(() {
        final comments = [...?_sessionComments[task.id], comment];
        _sessionComments[task.id] = comments;
      });
      _replaceTask(task.copyWith(commentCount: task.commentCount + 1));
    }
    return comment;
  }

  void _replaceTask(StudentKanbanTask updated) {
    setState(() {
      _tasks = _sortTasks(
        _tasks.map((task) => task.id == updated.id ? updated : task).toList(),
      );
    });
  }

  Future<void> _copyChatLink() async {
    final groupId = _activeGroupId;
    if (groupId == null || groupId.isEmpty) {
      _showSnack('Vui lòng chọn nhóm học tập trước.');
      return;
    }

    try {
      final link = await widget.studentApi.getKanbanChatLink(groupId);
      if (!mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: link));
      _showSnack('Đã sao chép liên kết nhóm chat.');
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Theme(
      data: buildStudentMaterialTheme(colors),
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Quản lý dự án',
            style: TextStyle(
              fontSize: 16,
              color: colors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.group_outlined, color: colors.text),
              onPressed: _openGroupDialog,
            ),
            IconButton(
              tooltip: 'Sao chép link chat',
              icon: Icon(Icons.link_rounded, color: colors.text),
              onPressed: _copyChatLink,
            ),
            StudentNotificationBell(
              studentApi: widget.studentApi,
              onViewAll: widget.onViewAllNotifications,
              icon: Icons.notifications_outlined,
              iconColor: colors.text,
              backgroundColor: colors.surface,
              borderColor: colors.border,
              margin: const EdgeInsets.symmetric(vertical: 8),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_errorMessage != null) _buildErrorBanner(),
            const SizedBox(height: 15),
            _buildTabs(),
            const SizedBox(height: 15),
            Expanded(
              child: _loading && _tasks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTaskList(StudentKanbanStatus.todo),
                        _buildTaskList(StudentKanbanStatus.doing),
                        _buildTaskList(StudentKanbanStatus.done),
                        _buildTaskList(StudentKanbanStatus.overdue),
                      ],
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreateTaskSheet,
          backgroundColor: colors.primaryStrong,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    final group = _board?.group;
    final members = _board?.members ?? const <StudentKanbanMember>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group?.name ?? 'Dự án nhóm',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  group == null
                      ? 'Chọn nhóm học tập để tải bảng Kanban'
                      : 'Bảng công việc nhóm học tập',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildAvatarPreview(members),
        ],
      ),
    );
  }

  Widget _buildAvatarPreview(List<StudentKanbanMember> members) {
    final colors = StudentThemeScope.colorsOf(context);
    if (members.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: colors.surfaceAlt,
        child: Icon(
          Icons.groups_2_outlined,
          color: colors.textSubtle,
          size: 16,
        ),
      );
    }

    final visible = members.take(3).toList();
    final hiddenCount = members.length - visible.length;

    return SizedBox(
      width: 32.0 + (visible.length - 1) * 24 + (hiddenCount > 0 ? 42 : 0),
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 24,
              child: _MemberAvatar(member: visible[index], radius: 16),
            ),
          if (hiddenCount > 0)
            Positioned(
              left: visible.length * 24 + 5,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  '+$hiddenCount',
                  style: TextStyle(fontSize: 10, color: colors.text),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final colors = StudentThemeScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.tint(colors.danger, lightAlpha: 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage ?? '',
                style: TextStyle(color: colors.danger, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: () => _loadBoard(),
              icon: const Icon(Icons.refresh, size: 18),
              color: colors.danger,
              tooltip: 'Tải lại',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: colors.primaryStrong.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: colors.primaryStrong.withValues(alpha: 0.4),
          ),
        ),
        labelColor: colors.primaryStrong,
        unselectedLabelColor: colors.textSubtle,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Cần làm'),
          Tab(text: 'Đang làm'),
          Tab(text: 'Xong'),
          Tab(text: 'Trễ hạn'),
        ],
      ),
    );
  }

  Widget _buildTaskList(StudentKanbanStatus status) {
    final colors = StudentThemeScope.colorsOf(context);
    if (_activeGroupId == null || _activeGroupId!.isEmpty) {
      return _EmptyKanbanState(onSelectGroup: _openGroupDialog);
    }

    final filtered = _tasks.where((task) => task.status == status).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _loading ? 'Đang tải dữ liệu...' : 'Mục này hiện đang trống',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadBoard(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final task = filtered[index];
          return GestureDetector(
            onTap: () => _openTaskDetails(task),
            child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: task.status == StudentKanbanStatus.overdue
                    ? colors.tint(colors.danger, lightAlpha: 0.08)
                    : colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: task.status == StudentKanbanStatus.overdue
                      ? colors.danger.withValues(alpha: 0.3)
                      : colors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPriorityBadge(task),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          task.assigneeId == null ? 'Chưa gán' : 'Được giao',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.info,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: task.status == StudentKanbanStatus.overdue
                          ? colors.danger
                          : colors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.description?.trim().isNotEmpty == true
                        ? task.description!.trim()
                        : 'Chưa có mô tả chi tiết.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 14,
                            color: colors.textSubtle,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${task.commentCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSubtle,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: task.status == StudentKanbanStatus.overdue
                                  ? const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.15)
                                  : colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _formatDueDate(task.dueDate),
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    task.status == StudentKanbanStatus.overdue
                                    ? colors.danger
                                    : colors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildTaskAssignee(task),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskAssignee(StudentKanbanTask task) {
    final colors = StudentThemeScope.colorsOf(context);
    final member = _memberById(task.assigneeId);
    if (member != null) {
      return _MemberAvatar(member: member, radius: 10);
    }
    if (task.assigneeName != null && task.assigneeName!.trim().isNotEmpty) {
      final avatarColor = Colors.indigoAccent;
      return CircleAvatar(
        radius: 10,
        backgroundColor: avatarColor,
        child: Text(
          _initials(task.assigneeName!),
          style: TextStyle(fontSize: 8, color: colors.onColor(avatarColor)),
        ),
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: colors.surfaceAlt,
      child: Icon(Icons.person_outline, size: 12, color: colors.textSubtle),
    );
  }

  Widget _buildPriorityBadge(StudentKanbanTask task) {
    final colors = StudentThemeScope.colorsOf(context);
    if (task.status == StudentKanbanStatus.overdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.tint(colors.danger),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
        ),
        child: Text(
          'TRỄ HẠN',
          style: TextStyle(
            fontSize: 9,
            color: colors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final priority = _priorityFor(task);
    final Color color;
    final String text;
    switch (priority) {
      case _TaskPriority.high:
        color = colors.danger;
        text = 'Ưu tiên Cao';
        break;
      case _TaskPriority.medium:
        color = colors.warning;
        text = 'Trung bình';
        break;
      case _TaskPriority.low:
        color = colors.success;
        text = 'Thấp';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _TaskPriority _priorityFor(StudentKanbanTask task) {
    final dueDate = task.dueDate;
    if (dueDate == null) {
      return _TaskPriority.low;
    }
    final daysLeft = dueDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 3) {
      return _TaskPriority.high;
    }
    if (daysLeft <= 7) {
      return _TaskPriority.medium;
    }
    return _TaskPriority.low;
  }

  StudentKanbanMember? _memberById(String? memberId) {
    if (memberId == null) {
      return null;
    }
    final members = _board?.members ?? const <StudentKanbanMember>[];
    for (final member in members) {
      if (member.id == memberId) {
        return member;
      }
    }
    return null;
  }

  List<StudentKanbanTask> _sortTasks(List<StudentKanbanTask> tasks) {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      final position = a.position.compareTo(b.position);
      if (position != 0) {
        return position;
      }
      final aDate = a.dueDate ?? DateTime(9999);
      final bDate = b.dueDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return sorted;
  }
}

class _TaskDetailsWidget extends StatefulWidget {
  const _TaskDetailsWidget({
    required this.task,
    required this.members,
    required this.comments,
    required this.scrollController,
    required this.onStatusChanged,
    required this.onComment,
    required this.onTaskChanged,
  });

  final StudentKanbanTask task;
  final List<StudentKanbanMember> members;
  final List<StudentKanbanComment> comments;
  final ScrollController scrollController;
  final Future<StudentKanbanTask> Function(StudentKanbanStatus status)
  onStatusChanged;
  final Future<StudentKanbanComment> Function(String content) onComment;
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

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _comments = [...widget.comments];
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(StudentKanbanStatus? status) async {
    if (status == null || status == _task.status) {
      return;
    }
    if (status == StudentKanbanStatus.overdue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trễ hạn do hệ thống tự cập nhật khi quá hạn, không chuyển thủ công.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _changingStatus = true;
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
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sendingComment) {
      return;
    }

    setState(() {
      _sendingComment = true;
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
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

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
                        ? 'Có ${task.commentCount} bình luận trước đó. Bình luận mới của bạn sẽ xuất hiện tại đây.'
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

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({required this.members, required this.onSubmit});

  final List<StudentKanbanMember> members;
  final Future<void> Function(_KanbanTaskFormResult result) onSubmit;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _assigneeId;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final colors = StudentThemeScope.colorsOf(context);
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 1)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 4)),
      builder: (context, child) {
        return Theme(
          data: buildStudentMaterialTheme(colors).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: colors.primaryStrong,
              brightness: colors.brightness,
            ).copyWith(primary: colors.primaryStrong, surface: colors.surface),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề công việc.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      await widget.onSubmit(
        _KanbanTaskFormResult(
          title: title,
          description: _descriptionController.text.trim(),
          dueDate: _dueDate,
          assigneeId: _assigneeId,
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
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể thêm công việc lúc này.')),
      );
    }
  }

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
              initialValue: _assigneeId,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.text),
              decoration: _fieldDecoration('Người phụ trách'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Chưa gán'),
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
                  _assigneeId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _fieldDecoration('Hạn hoàn thành'),
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
  });

  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? assigneeId;
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
  const _EmptyKanbanState({required this.onSelectGroup});

  final VoidCallback onSelectGroup;

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
              'Chọn nhóm học tập',
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn một nhóm để xem công việc, thành viên và thảo luận.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onSelectGroup,
              child: const Text('Nhập mã nhóm'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDueDate(DateTime? date) {
  if (date == null) {
    return 'Không hạn';
  }
  return '${date.day.toString().padLeft(2, '0')} Th${date.month.toString().padLeft(2, '0')}';
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
  String firstLetter(String value) {
    return String.fromCharCode(value.runes.first).toUpperCase();
  }

  if (words.length == 1) {
    return firstLetter(words.first);
  }
  return '${firstLetter(words.first)}${firstLetter(words.last)}';
}
