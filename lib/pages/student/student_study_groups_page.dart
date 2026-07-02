import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/student_course_models.dart';
import '../../models/student_schedule_models.dart';
import '../../models/student_study_group_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_kanban_page.dart';
import 'student_theme.dart';
import 'widgets/student_notification_dropdown.dart';

class StudentStudyGroupsPage extends StatefulWidget {
  const StudentStudyGroupsPage({
    super.key,
    required this.studentApi,
    required this.courses,
    this.onViewAllNotifications,
  });

  final StudentApiService studentApi;
  final List<StudentCourseItem> courses;
  final VoidCallback? onViewAllNotifications;

  @override
  State<StudentStudyGroupsPage> createState() => _StudentStudyGroupsPageState();
}

class _StudentStudyGroupsPageState extends State<StudentStudyGroupsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'my_groups';
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _loading = true;
  bool _loadingCourses = false;
  String? _errorMessage;
  List<StudentStudyGroup> _groups = [];
  List<_GroupCourseOption> _courseOptions = [];

  @override
  void initState() {
    super.initState();
    _courseOptions = widget.courses.map(_GroupCourseOption.fromCourse).toList();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadGroups(), _loadCourseOptions()]);
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final data = await widget.studentApi.listStudyGroups();
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = data.items;
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
        _errorMessage = 'Không thể tải danh sách nhóm học tập lúc này.';
      });
    }
  }

  Future<void> _loadCourseOptions() async {
    if (_loadingCourses) {
      return;
    }
    setState(() => _loadingCourses = true);
    try {
      final schedules = await widget.studentApi.listSchedules();
      final fromSchedule = _courseOptionsFromSchedules(schedules.items);
      if (!mounted) {
        return;
      }
      setState(() {
        if (fromSchedule.isNotEmpty) {
          _courseOptions = fromSchedule;
        }
        _loadingCourses = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCourses = false);
      }
    }
  }

  List<_GroupCourseOption> _courseOptionsFromSchedules(
    List<StudentScheduleItem> schedules,
  ) {
    final byCourse = <String, _GroupCourseOption>{};
    for (final item in schedules) {
      byCourse[item.courseId] = _GroupCourseOption(
        id: item.courseId,
        code: item.courseCode,
        name: item.courseName,
      );
    }
    return byCourse.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Future<void> _showCreateGroupDialog() async {
    if (_courseOptions.isEmpty) {
      _showSnack(
        'Hãy thêm hoặc import thời khóa biểu trước khi tạo nhóm học tập.',
      );
      await _loadCourseOptions();
      return;
    }

    final result = await showDialog<_CreateGroupResult>(
      context: context,
      builder: (context) {
        return _CreateGroupDialog(courses: _courseOptions);
      },
    );

    if (result == null) {
      return;
    }

    try {
      final group = await widget.studentApi.createStudyGroup(
        name: result.name,
        courseId: result.courseId,
        chatLink: result.chatLink,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = [group, ..._groups.where((item) => item.id != group.id)];
        _activeTab = 'my_groups';
      });
      _showSnack('Đã tạo nhóm "${group.name}" thành công.');
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<void> _showJoinDialog() async {
    final colors = StudentThemeScope.colorsOf(context);
    final controller = TextEditingController();
    final inviteCode = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colors.surface,
          title: Text(
            'Tham gia nhóm',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: colors.text),
            decoration: InputDecoration(
              labelText: 'Mã mời',
              labelStyle: TextStyle(color: colors.primaryStrong),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryStrong,
              ),
              child: Text(
                'Tham gia',
                style: TextStyle(color: colors.onPrimary),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (inviteCode == null || inviteCode.trim().isEmpty) {
      return;
    }

    try {
      final group = await widget.studentApi.joinStudyGroup(inviteCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = [group, ..._groups.where((item) => item.id != group.id)];
        _activeTab = 'my_groups';
      });
      _showSnack('Đã tham gia nhóm "${group.name}".');
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<void> _leaveGroup(StudentStudyGroup group) async {
    final confirmed = await _confirm(
      title: 'Rời nhóm',
      message: 'Bạn muốn rời khỏi nhóm "${group.name}"?',
      actionLabel: 'Rời nhóm',
    );
    if (confirmed != true) {
      return;
    }

    try {
      await widget.studentApi.leaveStudyGroup(group.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = _groups.where((item) => item.id != group.id).toList();
      });
      _showSnack('Đã rời khỏi nhóm "${group.name}".');
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<void> _deleteGroup(StudentStudyGroup group) async {
    final password = await _askPassword(group);
    if (password == null || password.isEmpty) {
      return;
    }

    try {
      await widget.studentApi.deleteStudyGroup(
        groupId: group.id,
        password: password,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = _groups.where((item) => item.id != group.id).toList();
      });
      _showSnack('Đã giải tán nhóm "${group.name}".');
    } on ApiException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) {
    final colors = StudentThemeScope.colorsOf(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPassword(StudentStudyGroup group) {
    final colors = StudentThemeScope.colorsOf(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Xác nhận giải tán',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Xóa nhóm'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _openGroupRoom(StudentStudyGroup group) {
    Navigator.push(
      context,
      studentThemedRoute(
        context: context,
        builder: (_) => _StudyGroupRoomPage(
          group: group,
          studentApi: widget.studentApi,
          onViewAllNotifications: widget.onViewAllNotifications,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final filtered = _groups.where((group) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          group.name.toLowerCase().contains(query) ||
          group.courseLabel.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'all' ||
          _categoryFor(group) == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    final myGroups = filtered;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGroups,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                Text(
                  'Nhóm Học Tập',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryStrong,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tìm kiếm và kết nối nhóm học thuật chất lượng cao của bạn.',
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
                ),
                const SizedBox(height: 24),
                _buildTabs(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildCategoryFilters(),
                const SizedBox(height: 24),
                if (_activeTab == 'my_groups')
                  _buildMyGroups(myGroups)
                else
                  _buildDiscover(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: colors.primaryStrong,
        foregroundColor: colors.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = StudentThemeScope.colorsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceAlt.withValues(alpha: 0.75),
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, size: 18, color: colors.text),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Text(
          'Quản lý nhóm học tập',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textMuted,
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

  Widget _buildTabs() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _buildTabButton(
            id: 'my_groups',
            label: 'Nhóm Của Tôi (${_groups.length})',
          ),
          _buildTabButton(id: 'discover', label: 'Khám Phá'),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String id, required String label}) {
    final colors = StudentThemeScope.colorsOf(context);
    final active = _activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? colors.primaryStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? colors.onPrimary : colors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = StudentThemeScope.colorsOf(context);
    final hasQuery = _searchQuery.trim().isNotEmpty;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasQuery
              ? colors.primaryStrong.withValues(alpha: 0.45)
              : colors.border,
          width: hasQuery ? 1.2 : 1,
        ),
        boxShadow: colors.isLight
            ? [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.tint(colors.primaryStrong, lightAlpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.search, color: colors.primaryStrong, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              cursorColor: colors.primaryStrong,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: colors.text),
              decoration: InputDecoration.collapsed(
                hintText: 'Tìm kiếm khóa học, chủ đề...',
                hintStyle: TextStyle(color: colors.textSubtle, fontSize: 14),
              ),
            ),
          ),
          if (hasQuery) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18, color: colors.textSubtle),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final colors = StudentThemeScope.colorsOf(context);
    const filters = [
      ('all', 'Tất cả'),
      ('code', 'Code'),
      ('calculate', 'Tính toán'),
      ('general', 'Chung'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final active = _selectedCategory == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: active,
              onSelected: (_) => setState(() => _selectedCategory = filter.$1),
              selectedColor: colors.primaryStrong,
              backgroundColor: colors.surface,
              labelStyle: TextStyle(
                color: active ? colors.onPrimary : colors.textMuted,
                fontWeight: FontWeight.bold,
              ),
              side: BorderSide(color: colors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMyGroups(List<StudentStudyGroup> groups) {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhóm của tôi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null)
          _buildErrorState()
        else if (groups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Bạn chưa tham gia nhóm nào.',
                style: TextStyle(color: colors.textSubtle),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groups.length,
            itemBuilder: (context, index) => _buildGroupCard(groups[index]),
          ),
      ],
    );
  }

  Widget _buildDiscover() {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Khám phá nhóm học tập',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 12),
        _buildJoinInviteCard(),
      ],
    );
  }

  Widget _buildJoinInviteCard() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.tint(colors.info),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'MÃ MỜI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.info,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tham gia bằng mã nhóm',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhập mã mời do trưởng nhóm chia sẻ để vào nhóm học tập.',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _showJoinDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryStrong,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Tham Gia'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage ?? '',
            style: TextStyle(color: colors.danger, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadGroups, child: const Text('Tải lại')),
        ],
      ),
    );
  }

  Widget _buildGroupCard(StudentStudyGroup group) {
    final colors = StudentThemeScope.colorsOf(context);
    final isLeader = group.isLeader;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLeader
            ? colors.tint(colors.primaryStrong, lightAlpha: 0.1)
            : colors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeader ? 8 : 32),
          topRight: Radius.circular(isLeader ? 32 : 8),
          bottomLeft: const Radius.circular(32),
          bottomRight: const Radius.circular(32),
        ),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.tint(colors.info),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.courseLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.info,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.role.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isLeader
                          ? const Color(0xFFFFAFD3)
                          : const Color(0xFF89CEFF),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    color: colors.surface,
                    icon: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    onSelected: (value) {
                      if (value == 'leave') {
                        _leaveGroup(group);
                      } else if (value == 'delete') {
                        _deleteGroup(group);
                      } else if (value == 'copy') {
                        Clipboard.setData(
                          ClipboardData(text: group.inviteCode),
                        );
                        _showSnack('Đã sao chép mã mời.');
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Text('Sao chép mã mời'),
                      ),
                      if (isLeader)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa nhóm'),
                        )
                      else
                        const PopupMenuItem(
                          value: 'leave',
                          child: Text('Rời nhóm'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            group.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            group.description,
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInitials(group.initials),
              const SizedBox(width: 8),
              Text(
                '${group.memberCount} thành viên',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: colors.primaryStrong),
                  const SizedBox(width: 6),
                  Text(
                    group.timeString,
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _openGroupRoom(group),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryStrong,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text('Vào Phòng'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(List<String> initials) {
    final colors = StudentThemeScope.colorsOf(context);
    final avatarColors = [colors.primaryStrong, colors.info, colors.danger];
    return SizedBox(
      width: 24.0 + (initials.take(3).length - 1) * 18,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < initials.take(3).length; index++)
            Positioned(
              left: index * 18,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: avatarColors[index % avatarColors.length],
                child: Text(
                  initials[index],
                  style: TextStyle(
                    color: colors.onColor(
                      avatarColors[index % avatarColors.length],
                    ),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _categoryFor(StudentStudyGroup group) {
    final code = group.courseLabel.toLowerCase();
    if (code.contains('cs') ||
        code.contains('it') ||
        code.contains('se') ||
        code.contains('is')) {
      return 'code';
    }
    if (code.contains('math') ||
        code.contains('cal') ||
        code.contains('stat') ||
        code.contains('phy')) {
      return 'calculate';
    }
    return 'general';
  }
}

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog({required this.courses});

  final List<_GroupCourseOption> courses;

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _chatLinkController = TextEditingController();
  String? _selectedCourseId;

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

  void _submit() {
    final name = _nameController.text.trim();
    final courseId = _selectedCourseId;
    if (name.isEmpty || courseId == null) {
      return;
    }
    Navigator.pop(
      context,
      _CreateGroupResult(
        name: name,
        courseId: courseId,
        chatLink: _chatLinkController.text.trim(),
      ),
    );
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
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedCourseId,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Môn học trong TKB'),
              items: widget.courses
                  .map(
                    (course) => DropdownMenuItem(
                      value: course.id,
                      child: Text(course.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCourseId = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chatLinkController,
              style: TextStyle(color: colors.text),
              decoration: const InputDecoration(labelText: 'Link nhóm chat'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryStrong,
          ),
          child: Text('Tạo nhóm', style: TextStyle(color: colors.onPrimary)),
        ),
      ],
    );
  }
}

class _StudyGroupRoomPage extends StatefulWidget {
  const _StudyGroupRoomPage({
    required this.group,
    required this.studentApi,
    this.onViewAllNotifications,
  });

  final StudentStudyGroup group;
  final StudentApiService studentApi;
  final VoidCallback? onViewAllNotifications;

  @override
  State<_StudyGroupRoomPage> createState() => _StudyGroupRoomPageState();
}

class _StudyGroupRoomPageState extends State<_StudyGroupRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, Object>> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _messages.add({'sender': 'Bạn', 'text': text, 'isYou': true});
      _controller.clear();
    });
  }

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
                    initialGroupId: group.id,
                    onViewAllNotifications: widget.onViewAllNotifications,
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
            child: Row(
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
                      Clipboard.setData(ClipboardData(text: group.chatLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép link chat.')),
                      );
                    },
                    child: const Text('Copy'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Hãy là người nhắn tin đầu tiên!',
                      style: TextStyle(color: colors.textSubtle),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isYou = msg['isYou'] as bool;
                      return Align(
                        alignment: isYou
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isYou
                                ? colors.primaryStrong
                                : colors.surfaceAlt.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isYou
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: isYou
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            msg['text'] as String,
                            style: TextStyle(
                              color: isYou ? colors.onPrimary : colors.text,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: colors.text),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: TextStyle(
                        color: colors.textSubtle,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: colors.primaryStrong),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
