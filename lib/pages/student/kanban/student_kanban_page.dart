import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/student_kanban_models.dart';
import '../../../models/student_study_group_models.dart';
import '../../../services/api/core/api_exception.dart';
import '../../../services/api/modules/student/student_api_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_inline_message.dart';
import '../widgets/student_notification_dropdown.dart';
part 'student_kanban_task_details.dart';
part 'student_kanban_task_form.dart';

enum _TaskPriority { high, medium, low }

class StudentKanbanPage extends StatefulWidget {
  const StudentKanbanPage({
    super.key,
    required this.currentUserId,
    required this.studentApi,
    this.initialGroupId,
    this.onViewAllNotifications,
    this.onKanbanChanged,
  });
  final String currentUserId;
  final StudentApiService studentApi;
  final String? initialGroupId;
  final VoidCallback? onViewAllNotifications;
  final VoidCallback? onKanbanChanged;

  @override
  State<StudentKanbanPage> createState() => _StudentKanbanPageState();
}

class _StudentKanbanPageState extends State<StudentKanbanPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  StudentKanbanBoardData? _board;
  List<StudentKanbanTask> _tasks = [];
  List<StudentStudyGroup> _joinedGroups = [];
  String? _activeGroupId;
  String? _errorMessage;
  bool _loading = false;
  bool _loadingGroups = false;
  bool _showAllTasksForLeader = true;

  bool get _canViewAllTasks => _board?.myRole == 'TRUONG_NHOM';

  bool _canSeeTask(StudentKanbanTask task) {
    return (_canViewAllTasks && _showAllTasksForLeader) ||
        task.assigneeId == widget.currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadJoinedGroups(initialGroupId: widget.initialGroupId?.trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Tải danh sách nhóm học tập mà sinh viên đã tham gia (đồng bộ với trang
  /// Quản lý nhóm). Tự động mở bảng của nhóm phù hợp mà không cần nhập mã.
  Future<void> _loadJoinedGroups({String? initialGroupId}) async {
    setState(() {
      _loadingGroups = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.studentApi.listStudyGroups();
      if (!mounted) {
        return;
      }
      setState(() {
        _joinedGroups = data.items;
        _loadingGroups = false;
      });

      if (_joinedGroups.isEmpty) {
        return;
      }

      // Ưu tiên nhóm được mở trực tiếp, nếu không thì giữ nhóm đang xem hoặc
      // mặc định về nhóm đầu tiên.
      final requestedId = initialGroupId != null && initialGroupId.isNotEmpty
          ? initialGroupId
          : _activeGroupId;
      final target = _joinedGroups.firstWhere(
        (group) => group.id == requestedId,
        orElse: () => _joinedGroups.first,
      );
      await _loadBoard(target.id);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingGroups = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingGroups = false;
        _errorMessage = 'Không thể tải danh sách nhóm học tập lúc này.';
      });
    }
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

  /// Mở danh sách nhóm đã tham gia để chọn bảng Kanban cần xem. Nếu chưa có
  /// nhóm nào, hướng dẫn sinh viên sang trang Quản lý nhóm để tham gia.
  Future<void> _openGroupDialog() async {
    if (_joinedGroups.isEmpty && !_loadingGroups) {
      await _loadJoinedGroups(initialGroupId: _activeGroupId);
    }
    if (!mounted) {
      return;
    }

    final colors = StudentThemeScope.colorsOf(context);

    if (_joinedGroups.isEmpty) {
      _showSnack(
        'Bạn chưa tham gia nhóm nào. Hãy vào trang Quản lý nhóm để tham gia.',
      );
      return;
    }

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  'Chọn nhóm học tập',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _joinedGroups.length,
                  itemBuilder: (context, index) {
                    final group = _joinedGroups[index];
                    final selected = group.id == _activeGroupId;
                    return ListTile(
                      leading: Icon(
                        Icons.groups_2_outlined,
                        color: selected
                            ? colors.primaryStrong
                            : colors.textMuted,
                      ),
                      title: Text(
                        group.name,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        group.courseLabel,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: colors.primaryStrong,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, group.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selectedId != null && selectedId.isNotEmpty) {
      await _loadBoard(selectedId);
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
              assignAllMembers: result.assignAllMembers,
            );
            if (!mounted) {
              return;
            }
            setState(() {
              _tasks = _sortTasks([..._tasks, task]);
            });
            widget.onKanbanChanged?.call();
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
              comments: task.comments,
              scrollController: scrollController,
              canEdit: _board?.myRole == 'TRUONG_NHOM',
              onStatusChanged: (status) => _changeTaskStatus(task, status),
              onComment: (content) => _commentTask(task, content),
              onEditDue: (dueDate) => _changeTaskDue(task, dueDate),
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
      widget.onKanbanChanged?.call();
      _showSnack('Đã cập nhật trạng thái công việc.');
    }
    return updated;
  }

  Future<StudentKanbanTask> _changeTaskDue(
    StudentKanbanTask task,
    DateTime? dueDate,
  ) async {
    final updated = await widget.studentApi.updateKanbanTask(
      taskId: task.id,
      title: task.title,
      description: task.description,
      dueDate: dueDate,
    );
    if (mounted) {
      _replaceTask(updated);
      widget.onKanbanChanged?.call();
      _showSnack('Đã cập nhật hạn hoàn thành.');
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
      _replaceTask(
        task.copyWith(
          commentCount: task.commentCount + 1,
          comments: [...task.comments, comment],
        ),
      );
    }
    return comment;
  }

  void _replaceTask(StudentKanbanTask updated) {
    setState(() {
      _tasks = _sortTasks(
        _tasks.map((task) {
          if (task.id != updated.id) {
            return task;
          }

          return updated.comments.isEmpty && task.comments.isNotEmpty
              ? updated.copyWith(comments: task.comments)
              : updated;
        }).toList(),
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
              tooltip: 'Đổi nhóm học tập',
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
            if (_canViewAllTasks) ...[
              _buildTaskScopeSelector(),
              const SizedBox(height: 15),
            ],
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
        floatingActionButton: _canViewAllTasks
            ? FloatingActionButton(
                onPressed: _openCreateTaskSheet,
                backgroundColor: colors.primaryStrong,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add, size: 28),
              )
            : null,
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
              onPressed: () {
                final active = _activeGroupId?.trim();
                if (active == null || active.isEmpty) {
                  _loadJoinedGroups(initialGroupId: _activeGroupId);
                } else {
                  _loadBoard();
                }
              },
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

  Widget _buildTaskScopeSelector() {
    final colors = StudentThemeScope.colorsOf(context);
    final myTaskCount = _tasks
        .where((task) => task.assigneeId == widget.currentUserId)
        .length;
    final allTaskCount = _tasks.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _buildTaskScopeOption(
            label: 'Của tôi',
            count: myTaskCount,
            selected: !_showAllTasksForLeader,
            onTap: () => setState(() => _showAllTasksForLeader = false),
          ),
          _buildTaskScopeOption(
            label: 'Toàn nhóm',
            count: allTaskCount,
            selected: _showAllTasksForLeader,
            onTap: () => setState(() => _showAllTasksForLeader = true),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskScopeOption({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = StudentThemeScope.colorsOf(context);
    return Expanded(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primaryStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.textSubtle,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(StudentKanbanStatus status) {
    final colors = StudentThemeScope.colorsOf(context);
    if (_activeGroupId == null || _activeGroupId!.isEmpty) {
      if (_loadingGroups) {
        return const Center(child: CircularProgressIndicator());
      }
      return _EmptyKanbanState(
        hasGroups: _joinedGroups.isNotEmpty,
        onSelectGroup: _openGroupDialog,
      );
    }

    final filtered = _tasks
        .where((task) => task.status == status)
        .where(_canSeeTask)
        .toList();
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
