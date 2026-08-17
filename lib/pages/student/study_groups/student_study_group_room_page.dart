part of 'student_study_groups_page.dart';

class _StudyGroupRoomPage extends StatefulWidget {
  const _StudyGroupRoomPage({
    required this.group,
    required this.studentApi,
    required this.currentUserId,
    this.onViewAllNotifications,
    this.onKanbanChanged,
  });

  final StudentStudyGroup group;
  final StudentApiService studentApi;
  final String currentUserId;
  final VoidCallback? onViewAllNotifications;
  final VoidCallback? onKanbanChanged;

  @override
  State<_StudyGroupRoomPage> createState() => _StudyGroupRoomPageState();
}

class _StudyGroupRoomPageState extends State<_StudyGroupRoomPage> {
  StudentKanbanBoardData? _board;
  bool _loadingBoard = true;
  String? _boardError;
  bool _showAllTasksForLeader = true;

  bool get _canViewAllTasks => _board?.myRole == 'TRUONG_NHOM';

  /// Kiểm tra điều kiện can see task trước khi cho phép thao tác tiếp theo.
  bool _canSeeTask(StudentKanbanTask task) {
    return (_canViewAllTasks && _showAllTasksForLeader) ||
        task.assigneeId == widget.currentUserId;
  }

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  /// Tải hoặc lấy dữ liệu load board để cập nhật UI.
  Future<void> _loadBoard() async {
    setState(() {
      _loadingBoard = true;
      _boardError = null;
    });

    try {
      final board = await widget.studentApi.getKanbanBoard(widget.group.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _board = board;
        _loadingBoard = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBoard = false;
        _boardError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBoard = false;
        _boardError = 'Không thể tải dữ liệu nhóm lúc này.';
      });
    }
  }

  /// Hiển thị hoặc mở phần giao diện open external chat cho người dùng.
  Future<void> _openExternalChat(StudentStudyGroup group) async {
    final raw = group.chatLink.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhóm chưa có link chat ngoài.')),
      );
      return;
    }

    final uri = _normalizeChatUri(raw);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) {
      return;
    }

    if (!mounted) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: raw));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không mở được app chat, đã sao chép link để bạn dán thủ công.',
        ),
      ),
    );
  }

  Uri _normalizeChatUri(String raw) {
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.parse('https://$raw');
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final colors = StudentThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${group.courseLabel} • Phòng nhóm',
              style: TextStyle(fontSize: 11, color: colors.textSubtle),
            ),
          ],
        ),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            tooltip: 'Sao chép mã mời',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: group.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép mã mời.')),
              );
            },
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Bảng Kanban',
            onPressed: () {
              Navigator.push(
                context,
                studentThemedRoute(
                  context: context,
                  builder: (_) => StudentKanbanPage(
                    studentApi: widget.studentApi,
                    currentUserId: widget.currentUserId,
                    initialGroupId: group.id,
                    onViewAllNotifications: widget.onViewAllNotifications,
                    onKanbanChanged: widget.onKanbanChanged,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.view_kanban_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: colors.surfaceAlt.withValues(alpha: 0.75),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, size: 16, color: colors.primaryStrong),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.chatLink.trim().isEmpty
                            ? 'Nhóm chưa có link chat ngoài'
                            : group.chatLink,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (group.chatLink.trim().isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: group.chatLink),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép link chat.'),
                            ),
                          );
                        },
                        child: const Text('Copy'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openExternalChat(group),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primaryStrong,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text(
                      'Vào nhóm chat Zalo/Discord',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBoard,
              child: _buildGroupInsightBody(colors),
            ),
          ),
        ],
      ),
    );
  }

  /// Dựng phần giao diện build group insight body cho màn hình hiện tại.
  Widget _buildGroupInsightBody(StudentThemeColors colors) {
    if (_loadingBoard && _board == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_boardError != null && _board == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.tint(colors.danger, lightAlpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
            ),
            child: Text(
              _boardError!,
              style: TextStyle(color: colors.danger, fontSize: 13),
            ),
          ),
        ],
      );
    }

    final members = _board?.members ?? const <StudentKanbanMember>[];
    final tasks = (_board?.tasks ?? const <StudentKanbanTask>[])
        .where(_canSeeTask)
        .toList();
    final viewingAllTasks = _canViewAllTasks && _showAllTasksForLeader;
    final taskSectionTitle = viewingAllTasks ? 'Task của nhóm' : 'Task của tôi';
    final emptyTaskMessage = viewingAllTasks
        ? 'Nhóm chưa có task nào.'
        : 'Bạn chưa có task nào trong nhóm này.';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        Text(
          'Thành viên nhóm (${members.length})',
          style: TextStyle(
            color: colors.text,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (members.isEmpty)
          Text(
            'Chưa có thành viên nào trong nhóm.',
            style: TextStyle(color: colors.textSubtle),
          )
        else
          ...members.map(
            (member) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.primaryStrong,
                    child: Text(
                      member.initials,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          member.email,
                          style: TextStyle(
                            color: colors.textSubtle,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: member.role == 'TRUONG_NHOM'
                          ? colors.tint(colors.warning, lightAlpha: 0.18)
                          : colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      member.role == 'TRUONG_NHOM'
                          ? 'Trưởng nhóm'
                          : 'Thành viên',
                      style: TextStyle(
                        fontSize: 10,
                        color: member.role == 'TRUONG_NHOM'
                            ? colors.warning
                            : colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (_canViewAllTasks) ...[
          _buildTaskScopeSelector(colors),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$taskSectionTitle (${tasks.length})',
              style: TextStyle(
                color: colors.text,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  studentThemedRoute(
                    context: context,
                    builder: (_) => StudentKanbanPage(
                      studentApi: widget.studentApi,
                      currentUserId: widget.currentUserId,
                      initialGroupId: widget.group.id,
                      onViewAllNotifications: widget.onViewAllNotifications,
                      onKanbanChanged: widget.onKanbanChanged,
                    ),
                  ),
                );
              },
              child: const Text('Mở Kanban'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (tasks.isEmpty)
          Text(emptyTaskMessage, style: TextStyle(color: colors.textSubtle))
        else
          ...tasks.map(
            (task) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.status.label,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.assigneeName?.trim().isNotEmpty == true
                        ? 'Phụ trách: ${task.assigneeName}'
                        : 'Phụ trách: Chưa gán',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  if (task.dueDate != null)
                    Text(
                      'Hạn: ${_formatDate(task.dueDate!)}',
                      style: TextStyle(color: colors.textSubtle, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Dựng phần giao diện build task scope selector cho màn hình hiện tại.
  Widget _buildTaskScopeSelector(StudentThemeColors colors) {
    final allTasks = _board?.tasks ?? const <StudentKanbanTask>[];
    final myTaskCount = allTasks
        .where((task) => task.assigneeId == widget.currentUserId)
        .length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _buildTaskScopeOption(
            colors: colors,
            label: 'Của tôi',
            count: myTaskCount,
            selected: !_showAllTasksForLeader,
            onTap: () => setState(() => _showAllTasksForLeader = false),
          ),
          _buildTaskScopeOption(
            colors: colors,
            label: 'Toàn nhóm',
            count: allTasks.length,
            selected: _showAllTasksForLeader,
            onTap: () => setState(() => _showAllTasksForLeader = true),
          ),
        ],
      ),
    );
  }

  /// Dựng phần giao diện build task scope option cho màn hình hiện tại.
  Widget _buildTaskScopeOption({
    required StudentThemeColors colors,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primaryStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
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

  /// Tạo giá trị hiển thị format date dùng trong giao diện.
  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _CreateGroupResult {
  const _CreateGroupResult({
    required this.name,
    required this.courseId,
    required this.chatLink,
  });

  final String name;
  final String courseId;
  final String chatLink;
}

class _GroupCourseOption {
  const _GroupCourseOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String? code;
  final String name;

  String get displayName {
    final normalizedCode = code?.trim();
    if (normalizedCode == null || normalizedCode.isEmpty) {
      return name;
    }
    return '${normalizedCode.toUpperCase()} • $name';
  }

  factory _GroupCourseOption.fromCourse(StudentCourseItem item) {
    return _GroupCourseOption(id: item.id, code: item.code, name: item.name);
  }
}
