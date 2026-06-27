import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../models/student_home_models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.showAppBar = true,
    required this.profile,
    required this.courses,
    required this.projects,
    required this.schedule,
    required this.onOpenFocusMode,
    required this.onLogout,
  });

  final bool showAppBar;
  final StudentProfile profile;
  final List<Course> courses;
  final List<Project> projects;
  final List<ScheduleItem> schedule;
  final VoidCallback onOpenFocusMode;
  final VoidCallback onLogout;

  double _calculateGpa() {
    double totalCredits = 0;
    double weightedPoints = 0;
    for (final c in courses) {
      totalCredits += c.credits;
      weightedPoints += c.grade * c.credits;
    }
    return totalCredits > 0 ? weightedPoints / totalCredits : 0;
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'Laptop':
        return LucideIcons.laptop;
      case 'BookOpen':
        return LucideIcons.bookOpen;
      case 'Globe':
        return LucideIcons.globe;
      case 'Cpu':
        return LucideIcons.cpu;
      case 'Smile':
        return LucideIcons.smile;
      case 'Pizza':
        return LucideIcons.pizza;
      case 'Droplet':
        return LucideIcons.droplet;
      default:
        return LucideIcons.graduationCap;
    }
  }

  Color _getProjectColor(String name) {
    if (name == 'rose') return const Color(0xFFF43F5E);
    if (name == 'sky') return const Color(0xFF0EA5E9);
    if (name == 'indigo') return Colors.indigo;
    return Colors.indigo;
  }

  String _gpaLabel(double gpa) {
    if (gpa <= 0) {
      return 'Chưa có dữ liệu';
    }
    if (gpa >= 3.6) {
      return 'Xuất sắc';
    }
    if (gpa >= 3.2) {
      return 'Giỏi';
    }
    return 'Khá';
  }

  @override
  Widget build(BuildContext context) {
    final gpa = _calculateGpa();
    final graduationPercent = profile.totalCreditsNeeded == 0
        ? 0.0
        : profile.completedCredits / profile.totalCreditsNeeded;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? const Icon(LucideIcons.user)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chao ngay moi,',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    Text(
                      profile.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${profile.major} • ${profile.joinedSemester}',
                      style: const TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.sparkles, color: Colors.amber),
                onPressed: onOpenFocusMode,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ĐIỂM TÍCH LŨY GPA',
                        style: TextStyle(
                          color: Colors.indigoAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gpa.toStringAsFixed(2),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Xếp loại: ${_gpaLabel(gpa)} (Hệ 4.0)',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mục tiêu: ${profile.targetGpa <= 0 ? '--' : profile.targetGpa.toStringAsFixed(1)} GPA',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 100,
                  width: 1,
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                CircularPercentIndicator(
                  radius: 40,
                  lineWidth: 8,
                  percent: graduationPercent.clamp(0.0, 1.0),
                  center: Text(
                    '${(graduationPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tin chi: ${profile.completedCredits}/${profile.totalCreditsNeeded}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: const Color(0xFF10B981),
                  backgroundColor: Colors.white10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onOpenFocusMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.alarmClock,
                      color: Colors.pinkAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chế độ tập trung (Pomodoro)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Bắt đầu một phiên 25 phút để tăng tốc hoàn thành bài tập!',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.pinkAccent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dự án & Dự án nhóm',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${projects.length} dự án',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final proj = projects[index];
                final color = _getProjectColor(proj.color);
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(_getIconData(proj.icon), color: color, size: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              proj.role == 'TRUONG_NHOM'
                                  ? 'Trưởng nhóm'
                                  : 'Thành viên',
                              style: TextStyle(
                                color: color,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proj.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            proj.subject,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: proj.progress / 100,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${proj.progress}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch lên lớp hôm nay',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Icon(
                LucideIcons.calendarRange,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          schedule.isEmpty
              ? const Card(
                  color: Color(0xFF1E293B),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('Hôm nay bạn không có lịch lên lớp nào'),
                    ),
                  ),
                )
              : Column(
                  children: schedule.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.completed
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.1)
                                  : Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconData(item.icon),
                              color: item.completed
                                  ? const Color(0xFF10B981)
                                  : Colors.indigoAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    decoration: item.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.time} • ${item.room}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.completed)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF10B981),
                              size: 18,
                            )
                          else
                            const Icon(
                              Icons.circle_outlined,
                              color: Colors.grey,
                              size: 18,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );

    if (!showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: content,
    );
  }
}
