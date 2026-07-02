import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../l10n/app_localizations.dart';
import '../../models/student_home_models.dart';
import 'student_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.showAppBar = true,
    required this.profile,
    required this.courses,
    required this.projects,
    required this.schedule,
    required this.onOpenFocusMode,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final bool showAppBar;
  final StudentProfile profile;
  final List<Course> courses;
  final List<Project> projects;
  final List<ScheduleItem> schedule;
  final VoidCallback onOpenFocusMode;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  double _calculateGpa() {
    double totalCredits = 0;
    double weightedPoints = 0;
    for (final course in courses) {
      totalCredits += course.credits;
      weightedPoints += course.grade * course.credits;
    }
    return totalCredits > 0 ? weightedPoints / totalCredits : 0;
  }

  IconData _projectIcon(String name) {
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

  Color _projectColor(String name) {
    if (name == 'rose') return const Color(0xFFF43F5E);
    if (name == 'sky') return const Color(0xFF0EA5E9);
    return Colors.indigo;
  }

  String _gpaLabel(BuildContext context, double gpa) {
    final l10n = context.l10n;
    if (gpa <= 0) return l10n.t('student.dashboard.home.gpaLevel.none');
    if (gpa >= 3.6) return l10n.t('student.dashboard.home.gpaLevel.excellent');
    if (gpa >= 3.2) return l10n.t('student.dashboard.home.gpaLevel.good');
    return l10n.t('student.dashboard.home.gpaLevel.fair');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final studentTheme = StudentThemeScope.controllerOf(context);
    final colors = studentTheme.colors;
    final gpa = _calculateGpa();
    final graduationPercent = profile.totalCreditsNeeded == 0
        ? 0.0
        : profile.completedCredits / profile.totalCreditsNeeded;

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onOpenProfile,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.surfaceAlt,
                  backgroundImage: profile.avatarUrl == null
                      ? null
                      : NetworkImage(profile.avatarUrl!),
                  child: profile.avatarUrl == null
                      ? Icon(LucideIcons.user, color: colors.textMuted)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('student.dashboard.home.greeting'),
                      style: TextStyle(color: colors.textSubtle, fontSize: 13),
                    ),
                    Text(
                      profile.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      '${profile.major} • ${profile.joinedSemester}',
                      style: TextStyle(
                        color: colors.primaryStrong,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: studentTheme.isLight
                    ? l10n.t('student.dashboard.home.toggleThemeDark')
                    : l10n.t('student.dashboard.home.toggleThemeLight'),
                icon: Icon(
                  studentTheme.isLight ? LucideIcons.moon : LucideIcons.sun,
                  color: studentTheme.isLight
                      ? colors.primaryStrong
                      : Colors.amber,
                ),
                onPressed: studentTheme.toggle,
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
              gradient: LinearGradient(
                colors: [colors.gpaGradientStart, colors.gpaGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primaryStrong.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
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
                      Text(
                        l10n.t('student.dashboard.home.gpaTitle'),
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.85),
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
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.t(
                          'student.dashboard.home.gpaLabel',
                          arguments: {'label': _gpaLabel(context, gpa)},
                        ),
                        style: TextStyle(
                          color: colors.onPrimary.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.t(
                          'student.dashboard.home.target',
                          arguments: {
                            'value': profile.targetGpa <= 0
                                ? '--'
                                : profile.targetGpa.toStringAsFixed(1),
                          },
                        ),
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
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
                  color: colors.onPrimary.withValues(alpha: 0.16),
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
                      color: Colors.white,
                    ),
                  ),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.t(
                        'student.dashboard.home.credits',
                        arguments: {
                          'completed': profile.completedCredits,
                          'total': profile.totalCreditsNeeded,
                        },
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onPrimary.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: const Color(0xFF10B981),
                  backgroundColor: colors.onPrimary.withValues(alpha: 0.16),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('student.dashboard.home.focusTitle'),
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.t('student.dashboard.home.focusSubtitle'),
                          style: TextStyle(
                            color: colors.textSubtle,
                            fontSize: 10,
                          ),
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
                l10n.t('student.dashboard.home.projectsTitle'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              Text(
                l10n.t(
                  'student.dashboard.home.projectsCount',
                  arguments: {'count': projects.length},
                ),
                style: TextStyle(fontSize: 11, color: colors.textSubtle),
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
                final project = projects[index];
                final color = _projectColor(project.color);
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
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
                          Icon(
                            _projectIcon(project.icon),
                            color: color,
                            size: 20,
                          ),
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
                              project.role == 'TRUONG_NHOM'
                                  ? l10n.t('student.dashboard.home.roleLeader')
                                  : l10n.t('student.dashboard.home.roleMember'),
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
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            project.subject,
                            style: TextStyle(
                              color: colors.textSubtle,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: project.progress / 100,
                              backgroundColor: colors.overlay(0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${project.progress}%',
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
                l10n.t('student.dashboard.home.scheduleTitle'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              Icon(
                LucideIcons.calendarRange,
                color: colors.textSubtle,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (schedule.isEmpty)
            Card(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(l10n.t('student.dashboard.home.scheduleEmpty')),
                ),
              ),
            )
          else
            Column(
              children: schedule.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.completed
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _projectIcon(item.icon),
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
                                color: colors.text,
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
                                color: colors.textSubtle,
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
                        Icon(
                          Icons.circle_outlined,
                          color: colors.textSubtle,
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

    if (!showAppBar) return body;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(l10n.t('student.dashboard.home.appBarTitle')),
        actions: [
          IconButton(
            tooltip: l10n.t('common.logout'),
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: body,
    );
  }
}
