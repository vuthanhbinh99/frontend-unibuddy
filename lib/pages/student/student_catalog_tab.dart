import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/student_course_models.dart';
import '../../models/student_grade_models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api/modules/student_api_service.dart';
import 'student_course_management_page.dart';
import 'student_flashcard_decks_page.dart';
import 'student_kanban_page.dart';
import 'student_notes_page.dart';
import 'student_study_groups_page.dart';
import 'student_storage_page.dart';
import 'student_theme.dart';

class StudentCatalogTab extends StatelessWidget {
  const StudentCatalogTab({
    super.key,
    required this.data,
    required this.grades,
    required this.studentName,
    required this.studentMajor,
    required this.studentApi,
    required this.onChangeTab,
    required this.onAcademicDataChanged,
    required this.onOpenFocusMode,
    required this.onRefresh,
  });

  final StudentCourseData data;
  final StudentGradeTranscriptData grades;
  final String studentName;
  final String studentMajor;
  final StudentApiService studentApi;
  final ValueChanged<int> onChangeTab;
  final Future<void> Function() onAcademicDataChanged;
  final VoidCallback onOpenFocusMode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final themeController = StudentThemeScope.controllerOf(context);
    void openNotificationsFromPushedPage() {
      Navigator.of(context).popUntil((route) => route.isFirst);
      onChangeTab(3);
    }

    final categoriesList = [
      _CategoryItem(
        id: 'hocphan',
        label: l10n.t('student.dashboard.catalog.course'),
        desc: 'Danh sách môn học hiện tại',
        icon: LucideIcons.bookOpen,
        color: Colors.indigoAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => StudentCourseManagementPage(
                studentApi: studentApi,
                initialCourses: data,
                initialGrades: grades,
                onChanged: onAcademicDataChanged,
                onViewAllNotifications: openNotificationsFromPushedPage,
              ),
            ),
          );
        },
      ),
      _CategoryItem(
        id: 'schedule',
        label: l10n.t('student.dashboard.catalog.schedule'),
        desc: 'Lịch lên lớp trong tuần',
        icon: LucideIcons.calendar,
        color: Colors.greenAccent,
        action: () => onChangeTab(1),
      ),
      _CategoryItem(
        id: 'diemso',
        label: l10n.t('student.dashboard.catalog.grades'),
        desc: 'Tra cứu bảng điểm chi tiết',
        icon: LucideIcons.graduationCap,
        color: Colors.purpleAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => GradesSubScreen(grades: grades),
            ),
          );
        },
      ),
      _CategoryItem(
        id: 'focus',
        label: l10n.t('student.dashboard.catalog.focus'),
        desc: 'Tập trung học tập 25 phút',
        icon: LucideIcons.alarmClock,
        color: Colors.pinkAccent,
        action: onOpenFocusMode,
      ),
      _CategoryItem(
        id: 'study_groups',
        label: l10n.t('student.dashboard.catalog.studyGroups'),
        desc: 'Tạo nhóm, tham gia, mở Kanban',
        icon: LucideIcons.users,
        color: Colors.lightBlueAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => StudentStudyGroupsPage(
                studentApi: studentApi,
                courses: data.items,
                onViewAllNotifications: openNotificationsFromPushedPage,
              ),
            ),
          );
        },
      ),
      _CategoryItem(
        id: 'luutru',
        label: l10n.t('student.dashboard.catalog.storage'),
        desc: 'Tài liệu, liên kết học tập',
        icon: LucideIcons.archive,
        color: Colors.amberAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => StudentStoragePage(
                studentApi: studentApi,
                initialCourses: data.items,
                onViewAllNotifications: openNotificationsFromPushedPage,
              ),
            ),
          );
        },
      ),
      _CategoryItem(
        id: 'flashcard',
        label: l10n.t('student.dashboard.catalog.flashcard'),
        desc: 'Thẻ học thuật thông minh',
        icon: LucideIcons.layers,
        color: Colors.pinkAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => StudentFlashcardDecksPage(
                studentApi: studentApi,
                courses: data.items,
                onViewAllNotifications: openNotificationsFromPushedPage,
              ),
            ),
          );
        },
      ),
      _CategoryItem(
        id: 'kanban',
        label: l10n.t('student.dashboard.catalog.kanban'),
        desc: 'Quản lý việc cần làm của nhóm',
        icon: LucideIcons.trello,
        color: Colors.cyanAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => StudentKanbanPage(
                studentApi: studentApi,
                onViewAllNotifications: openNotificationsFromPushedPage,
              ),
            ),
          );
        },
      ),
      _CategoryItem(
        id: 'ghichu',
        label: l10n.t('student.dashboard.catalog.notes'),
        desc: 'Ghi chú bài giảng nhanh',
        icon: LucideIcons.fileText,
        color: Colors.orangeAccent,
        action: () {
          Navigator.push(
            context,
            buildStudentThemedRoute(
              controller: themeController,
              builder: (_) => StudentNotesPage(
                studentApi: studentApi,
                courses: data.items,
                onViewAllNotifications: openNotificationsFromPushedPage,
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('student.dashboard.catalog.title'),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('student.dashboard.catalog.subtitle'),
                  style: TextStyle(color: colors.textSubtle, fontSize: 12),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: categoriesList.length,
                  itemBuilder: (context, index) {
                    final cat = categoriesList[index];
                    return GestureDetector(
                      onTap: cat.action,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cat.color.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(cat.icon, color: cat.color, size: 20),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        cat.label,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 8,
                                      color: cat.color.withValues(alpha: 0.6),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat.desc,
                                  style: TextStyle(
                                    color: colors.textSubtle,
                                    fontSize: 9,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.indigo.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text('💡', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mẹo học tập: Sử dụng Pomodoro kết hợp với bảng deadline để giữ động lực học tập cho học kỳ này nhé!',
                          style: TextStyle(
                            color: Color(0xFFA5B4FC),
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoursesSubScreen extends StatelessWidget {
  const CoursesSubScreen({super.key, required this.courses});

  final List<StudentCourseItem> courses;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'Môn học & Tín chỉ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
      ),
      body: courses.isEmpty
          ? Center(child: Text(l10n.t('student.dashboard.catalog.noCourses')))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.indigo.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: colors.text,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${course.credits} tín chỉ',
                              style: const TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${course.code ?? course.id} • ${course.semesterName}',
                        style: TextStyle(
                          color: colors.textSubtle,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class GradesSubScreen extends StatelessWidget {
  const GradesSubScreen({super.key, required this.grades});

  final StudentGradeTranscriptData grades;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final gpa = grades.summary.cumulativeGpa;
    final totalCredits =
        grades.summary.calculatedCredits + grades.summary.remainingCredits;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'Bảng điểm Học kỳ',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.tint(colors.primaryStrong, lightAlpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primaryStrong.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'TÍCH LŨY HỌC KỲ',
                    style: TextStyle(
                      color: colors.primaryStrong,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gpa == null ? '--' : gpa.toStringAsFixed(2),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    grades.summary.academicStanding ??
                        'Chưa đủ dữ liệu để xếp loại',
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: colors.border),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'SỐ TÍN CHỈ',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCredits tín chỉ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.text,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'ĐÃ TÍNH GPA',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${grades.summary.calculatedCredits} tín chỉ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: colors.primaryStrong,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chi tiết điểm các môn học',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 12),
            if (grades.items.isEmpty)
              Text(
                grades.message,
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              )
            else
              Column(
                children: grades.items.map((course) {
                  final score4 = course.result.score4;
                  final scoreColor = (score4 ?? 0) >= 3.5
                      ? colors.success
                      : colors.warning;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${course.credits} tín chỉ • Quy đổi: ${course.result.letterGrade ?? '--'}',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 10,
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
                            color: (score4 ?? 0) >= 3.5
                                ? colors.tint(colors.success, lightAlpha: 0.1)
                                : colors.tint(colors.warning, lightAlpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            score4 == null ? '--' : score4.toStringAsFixed(1),
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem {
  const _CategoryItem({
    required this.id,
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
    required this.action,
  });

  final String id;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback action;
}
