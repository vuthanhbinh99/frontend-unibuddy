import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_feedback_screen.dart';
import 'student_theme.dart';

class StudentSettingsTab extends StatefulWidget {
  const StudentSettingsTab({
    super.key,
    required this.user,
    required this.studentApi,
    required this.currentSessionRefreshToken,
    required this.isDarkMode,
    required this.currentLanguageCode,
    required this.onToggleTheme,
    required this.onLanguageChanged,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final PublicUser user;
  final StudentApiService studentApi;
  final String currentSessionRefreshToken;
  final bool isDarkMode;
  final String currentLanguageCode;
  final ValueChanged<bool> onToggleTheme;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  @override
  State<StudentSettingsTab> createState() => _StudentSettingsTabState();
}

class _StudentSettingsTabState extends State<StudentSettingsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<AuthDeviceSession> _sessions = [];
  bool _isLoadingSessions = true;

  double _cacheSize = 24.5;
  bool _appNotifications = true;
  String _deadlineReminder = '12h';
  bool _dailyFlashcard = true;
  String _flashcardTime = '20:00';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void didUpdateWidget(covariant StudentSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSessionRefreshToken !=
        widget.currentSessionRefreshToken) {
      _loadSessions();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _text(String vi, String en) {
    return widget.currentLanguageCode == 'vi' ? vi : en;
  }

  bool _matchesSearch(String label) {
    if (_searchQuery.isEmpty) return true;
    return label.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openFeedbackScreen() {
    Navigator.of(context).push(
      studentThemedRoute(
        context: context,
        builder: (_) => StudentFeedbackScreen(
          studentApi: widget.studentApi,
          currentLanguageCode: widget.currentLanguageCode,
        ),
      ),
    );
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);
    final next = widget.studentApi.listCurrentUserSessions(
      widget.currentSessionRefreshToken,
    );
    final sessions = await next;
    if (!mounted) {
      return;
    }
    setState(() {
      _sessions = sessions;
      _isLoadingSessions = false;
    });
  }

  Future<void> _signOutDevice(AuthDeviceSession session) async {
    final previousSessions = List<AuthDeviceSession>.from(_sessions);
    setState(() {
      _sessions.removeWhere((item) => item.id == session.id);
    });

    try {
      await widget.studentApi.revokeCurrentUserSession(session.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(_text('Đã đăng xuất thiết bị', 'Device signed out'));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessions = previousSessions;
      });
      _showSnackBar(
        _text(
          'Không thể đăng xuất thiết bị lúc này',
          'Could not sign out device right now',
        ),
      );
    }
  }

  String _formatLastActive(DateTime lastActiveAt, bool isVietnamese) {
    final difference = DateTime.now().difference(lastActiveAt);
    if (difference.inMinutes < 1) {
      return isVietnamese ? 'Vừa hoạt động' : 'Active just now';
    }
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return isVietnamese
          ? '$minutes phút trước'
          : '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return isVietnamese
          ? '$hours giờ trước'
          : '$hours hour${hours == 1 ? '' : 's'} ago';
    }

    final days = difference.inDays;
    return isVietnamese
        ? '$days ngày trước'
        : '$days day${days == 1 ? '' : 's'} ago';
  }

  void _clearCache() {
    setState(() {
      _cacheSize = 0;
    });
    _showSnackBar(
      _text('Bộ nhớ đệm đã dọn dẹp thành công!', 'Cache cleared successfully!'),
    );
  }

  Future<void> _pickFlashcardTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked == null) return;

    setState(() {
      _flashcardTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
    _showSnackBar(
      _text(
        'Đã cập nhật thời gian: $_flashcardTime',
        'Notification time updated: $_flashcardTime',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final isVietnamese = widget.currentLanguageCode == 'vi';

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              l10n.t('student.settings.title'),
              style: TextStyle(
                color: colors.text,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('student.settings.subtitle'),
              style: TextStyle(color: colors.textSubtle, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _SettingsCard(
              colors: colors,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  hintText: _text('Tìm kiếm cài đặt...', 'Search settings...'),
                  hintStyle: TextStyle(color: colors.textMuted),
                  prefixIcon: Icon(Icons.search, color: colors.primaryStrong),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_matchesSearch(_text('Tài khoản', 'Account')) ||
                _matchesSearch(widget.user.fullName) ||
                _matchesSearch(_text('thiết bị', 'device'))) ...[
              _SectionHeader(
                colors: colors,
                title: _text('TÀI KHOẢN & BẢO MẬT', 'ACCOUNT & SECURITY'),
              ),
              _SettingsCard(
                colors: colors,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.primarySoft,
                      backgroundImage: widget.user.avatarUrl == null
                          ? null
                          : NetworkImage(widget.user.avatarUrl!),
                      child: widget.user.avatarUrl == null
                          ? Icon(Icons.person, color: colors.primaryStrong)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.fullName,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.email,
                            style: TextStyle(
                              color: colors.textSubtle,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.user.role.displayName,
                            style: TextStyle(
                              color: colors.textSubtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenProfile,
                      child: Text(l10n.t('student.settings.profile')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                colors: colors,
                child: Column(
                  children: [
                    if (_isLoadingSessions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.primaryStrong,
                          ),
                        ),
                      )
                    else if (_sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _text(
                            'Chưa có thiết bị nào đang đăng nhập.',
                            'No active devices found.',
                          ),
                          style: TextStyle(
                            color: colors.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.phone_iphone_outlined,
                                color: colors.primaryStrong,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVietnamese
                                          ? 'Thiết bị hiện tại'
                                          : 'Current device',
                                      style: TextStyle(
                                        color: colors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isVietnamese
                                          ? 'Thiết bị đang đăng nhập phiên này'
                                          : 'This device is currently signed in',
                                      style: TextStyle(
                                        color: colors.textSubtle,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                isVietnamese ? 'Đang dùng' : 'Active',
                                style: TextStyle(
                                  color: colors.primaryStrong,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: colors.border, height: 1),
                          const SizedBox(height: 12),
                          ..._sessions.map((session) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: session.isCurrent
                                          ? colors.primarySoft
                                          : colors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      session.isMobile
                                          ? Icons.smartphone
                                          : Icons.laptop_mac,
                                      color: colors.primaryStrong,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.deviceType
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? session.deviceType!.trim()
                                              : _text('Thiết bị', 'Device'),
                                          style: TextStyle(
                                            color: colors.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          session.isCurrent
                                              ? (isVietnamese
                                                    ? 'Thiết bị hiện tại'
                                                    : 'Current device')
                                              : _formatLastActive(
                                                  session.lastActiveAt,
                                                  isVietnamese,
                                                ),
                                          style: TextStyle(
                                            color: colors.textSubtle,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!session.isCurrent)
                                    TextButton(
                                      onPressed: () => _signOutDevice(session),
                                      child: Text(
                                        isVietnamese ? 'Đăng xuất' : 'Sign out',
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_matchesSearch(_text('Học tập', 'Academics')) ||
                _matchesSearch(_text('Thông báo', 'Notifications')) ||
                _matchesSearch(_text('Flashcard', 'Flashcard'))) ...[
              _SectionHeader(
                colors: colors,
                title: _text(
                  'HỌC TẬP & THÔNG BÁO',
                  'ACADEMICS & NOTIFICATIONS',
                ),
              ),
              _SettingsCard(
                colors: colors,
                child: Column(
                  children: [
                    _SwitchRow(
                      colors: colors,
                      icon: Icons.notifications_active_outlined,
                      iconColor: const Color(0xFF6366F1),
                      title: _text('Thông báo ứng dụng', 'App notifications'),
                      value: _appNotifications,
                      onChanged: (value) =>
                          setState(() => _appNotifications = value),
                    ),
                    const SizedBox(height: 10),
                    _DropdownRow(
                      colors: colors,
                      icon: Icons.calendar_month_outlined,
                      iconColor: const Color(0xFF818CF8),
                      title: _text('Nhắc nhở Deadline', 'Deadline reminder'),
                      value: _deadlineReminder,
                      items: const [
                        DropdownMenuItem(
                          value: '24h',
                          child: Text('24h Trước'),
                        ),
                        DropdownMenuItem(
                          value: '12h',
                          child: Text('12h Trước'),
                        ),
                        DropdownMenuItem(value: '3h', child: Text('3h Trước')),
                        DropdownMenuItem(
                          value: '0h',
                          child: Text('Không nhắc'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _deadlineReminder = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      colors: colors,
                      icon: Icons.auto_stories_outlined,
                      iconColor: Colors.pinkAccent,
                      title: _text(
                        'Ôn tập Flashcard mỗi ngày',
                        'Daily flashcard review',
                      ),
                      value: _dailyFlashcard,
                      onChanged: (value) =>
                          setState(() => _dailyFlashcard = value),
                    ),
                    if (_dailyFlashcard) ...[
                      const SizedBox(height: 10),
                      Divider(color: colors.border, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                color: colors.textSubtle,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _text(
                                  'Thời gian thông báo',
                                  'Notification time',
                                ),
                                style: TextStyle(
                                  color: colors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                _flashcardTime,
                                style: TextStyle(
                                  color: colors.primaryStrong,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                onPressed: _pickFlashcardTime,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: colors.textSubtle,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_matchesSearch(_text('Tùy chỉnh', 'Personalization')) ||
                _matchesSearch(_text('Ngôn ngữ', 'Language')) ||
                _matchesSearch(_text('Dark Mode', 'Dark mode'))) ...[
              _SectionHeader(
                colors: colors,
                title: _text('TÙY CHỈNH CÁ NHÂN', 'PERSONALIZATION'),
              ),
              _SettingsCard(
                colors: colors,
                child: Column(
                  children: [
                    _SwitchRow(
                      colors: colors,
                      icon: Icons.dark_mode_outlined,
                      iconColor: const Color(0xFF6366F1),
                      title: _text('Chế độ tối (Dark Mode)', 'Dark mode'),
                      value: widget.isDarkMode,
                      onChanged: widget.onToggleTheme,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language_outlined,
                              color: colors.textSubtle,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _text('Ngôn ngữ', 'Language'),
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _LanguageButton(
                                label: 'VI',
                                active: widget.currentLanguageCode == 'vi',
                                colors: colors,
                                onTap: () => widget.onLanguageChanged('vi'),
                              ),
                              _LanguageButton(
                                label: 'EN',
                                active: widget.currentLanguageCode == 'en',
                                colors: colors,
                                onTap: () => widget.onLanguageChanged('en'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_matchesSearch(_text('Hệ thống', 'System')) ||
                _matchesSearch(_text('Bộ nhớ đệm', 'Cache')) ||
                _matchesSearch(_text('Báo lỗi', 'Feedback'))) ...[
              _SectionHeader(
                colors: colors,
                title: _text('HỆ THỐNG & LƯU TRỮ', 'SYSTEM & STORAGE'),
              ),
              _SettingsCard(
                colors: colors,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.data_usage, color: Color(0xFFC7C4D7)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _text('Bộ nhớ đệm (Cache)', 'Cache'),
                                style: TextStyle(
                                  color: colors.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_text('Dung lượng đang dùng: ', 'Space used: ')}${_cacheSize.toStringAsFixed(1)} MB',
                                style: TextStyle(
                                  color: colors.textSubtle,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _cacheSize == 0 ? null : _clearCache,
                        child: Text(_text('Xóa Cache', 'Clear cache')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: colors.border, height: 1),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _openFeedbackScreen,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bug_report_outlined,
                                  color: Color(0xFFF43F5E),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _text(
                                    'Báo lỗi & Phản hồi',
                                    'Report bug & feedback',
                                  ),
                                  style: TextStyle(
                                    color: colors.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.chevron_right, color: colors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout, size: 18),
                label: Text(l10n.t('student.settings.logout')),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'UNIBUDDY v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                'Phát triển với ❤️ dành cho sinh viên STU',
                'Developed with ❤️ for STU Students',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.colors, required this.child});

  final StudentThemeColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.colors, required this.title});

  final StudentThemeColors colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primaryStrong,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool active;
  final StudentThemeColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? colors.primaryStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : colors.textSubtle,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final StudentThemeColors colors;
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final StudentThemeColors colors;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
