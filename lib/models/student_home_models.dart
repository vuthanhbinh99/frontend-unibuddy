import 'auth_models.dart';
import 'student_course_models.dart' as catalog;
import 'student_grade_models.dart';
import 'student_schedule_models.dart' as schedule_model;

class StudentProfile {
  const StudentProfile({
    required this.name,
    required this.avatarUrl,
    required this.major,
    required this.joinedSemester,
    required this.completedCredits,
    required this.totalCreditsNeeded,
    required this.targetGpa,
  });

  final String name;
  final String? avatarUrl;
  final String major;
  final String joinedSemester;
  final int completedCredits;
  final int totalCreditsNeeded;
  final double targetGpa;
}

class Course {
  const Course({required this.credits, required this.grade});

  final double credits;
  final double grade;
}

class Project {
  const Project({
    required this.name,
    required this.subject,
    required this.icon,
    required this.color,
    required this.role,
    required this.progress,
  });

  final String name;
  final String subject;
  final String icon;
  final String color;
  final String role;
  final int progress;
}

class ScheduleItem {
  const ScheduleItem({
    required this.name,
    required this.time,
    required this.room,
    required this.icon,
    required this.completed,
  });

  final String name;
  final String time;
  final String room;
  final String icon;
  final bool completed;
}

class StudentHomeData {
  const StudentHomeData({
    required this.profile,
    required this.courses,
    required this.projects,
    required this.schedule,
  });

  final StudentProfile profile;
  final List<Course> courses;
  final List<Project> projects;
  final List<ScheduleItem> schedule;

  factory StudentHomeData.fromCurrentUser(PublicUser user) {
    return StudentHomeData(
      profile: StudentProfile(
        name: user.fullName,
        avatarUrl: user.avatarUrl,
        major: '--',
        joinedSemester: '--',
        completedCredits: 0,
        totalCreditsNeeded: 0,
        targetGpa: 0,
      ),
      courses: const [],
      projects: const [],
      schedule: const [],
    );
  }

  factory StudentHomeData.fromBackend({
    required PublicUser user,
    required catalog.StudentCourseData courseData,
    required schedule_model.StudentScheduleData scheduleData,
    required StudentGradeTranscriptData gradeData,
    List<Project> projects = const [],
  }) {
    final totalCredits =
        gradeData.summary.calculatedCredits +
        gradeData.summary.remainingCredits;
    final fallbackCredits = courseData.items.fold<int>(
      0,
      (sum, item) => sum + item.credits,
    );
    final selectedSemesterName = _selectedSemesterName(courseData);
    final todayBackendDay = _todayBackendDay();
    final today = _normalizeDate(DateTime.now());
    final todayScheduleItems =
        scheduleData.items
            .where(
              (item) =>
                  item.dayOfWeek == todayBackendDay &&
                  _belongsToSemester(item, selectedSemesterName) &&
                  _isActiveOnDate(item, today),
            )
            .toList()
          ..sort((left, right) {
            final periodComparison = left.startPeriod.compareTo(
              right.startPeriod,
            );
            if (periodComparison != 0) {
              return periodComparison;
            }

            final roomComparison = (left.room ?? '').compareTo(
              right.room ?? '',
            );
            if (roomComparison != 0) {
              return roomComparison;
            }

            return left.courseName.compareTo(right.courseName);
          });
    final seenScheduleKeys = <String>{};
    final todaySchedule = todayScheduleItems
        .where((item) => seenScheduleKeys.add(_homeScheduleKey(item)))
        .map(
          (item) => ScheduleItem(
            name: item.courseName,
            time: 'Tiết ${item.startPeriod}-${item.endPeriod}',
            room: item.room ?? 'Chưa cập nhật phòng',
            icon: 'BookOpen',
            completed: false,
          ),
        )
        .toList();

    return StudentHomeData(
      profile: StudentProfile(
        name: user.fullName,
        avatarUrl: user.avatarUrl,
        major: user.role.name,
        joinedSemester: selectedSemesterName,
        completedCredits: gradeData.summary.calculatedCredits,
        totalCreditsNeeded: totalCredits > 0 ? totalCredits : fallbackCredits,
        targetGpa: 0,
      ),
      courses: gradeData.items
          .where((item) => item.result.score4 != null)
          .map(
            (item) => Course(
              credits: item.credits.toDouble(),
              grade: item.result.score4!,
            ),
          )
          .toList(),
      projects: projects,
      schedule: todaySchedule,
    );
  }
}

int _todayBackendDay() {
  final weekday = DateTime.now().weekday;
  return weekday == DateTime.sunday ? 8 : weekday + 1;
}

bool _belongsToSemester(
  schedule_model.StudentScheduleItem item,
  String selectedSemesterName,
) {
  if (selectedSemesterName.isEmpty || selectedSemesterName == '--') {
    return true;
  }

  final itemSemester = item.semesterName.trim();
  if (itemSemester.isEmpty || itemSemester == '--') {
    return true;
  }

  return itemSemester == selectedSemesterName;
}

bool _isActiveOnDate(schedule_model.StudentScheduleItem item, DateTime date) {
  final start = _parseFlexibleDate(item.startDate);
  final end = _parseFlexibleDate(item.endDate);

  if (start == null || end == null) {
    return false;
  }

  final normalizedStart = _normalizeDate(start);
  final normalizedEnd = _normalizeDate(end);

  return !date.isBefore(normalizedStart) && !date.isAfter(normalizedEnd);
}

DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime? _parseFlexibleDate(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  final iso = DateTime.tryParse(text);
  if (iso != null) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  final normalized = text.replaceAll('-', '/');
  final parts = normalized.split('/');
  if (parts.length != 3) {
    return null;
  }

  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  final third = int.tryParse(parts[2]);
  if (first == null || second == null || third == null) {
    return null;
  }

  if (parts[0].length == 4) {
    return DateTime(first, second, third);
  }

  final year = third < 100 ? 2000 + third : third;
  return DateTime(year, second, first);
}

String _homeScheduleKey(schedule_model.StudentScheduleItem item) {
  final normalizedStart = _normalizedDateKey(item.startDate);
  final normalizedEnd = _normalizedDateKey(item.endDate);

  return [
    item.courseCode ?? '',
    item.courseName,
    item.dayOfWeek.toString(),
    item.startPeriod.toString(),
    item.endPeriod.toString(),
    item.room ?? '',
    normalizedStart,
    normalizedEnd,
  ].join('|');
}

String _selectedSemesterName(catalog.StudentCourseData data) {
  final selectedId = data.selectedSemesterId;
  if (selectedId == null) {
    final today = _normalizeDate(DateTime.now());

    for (final semester in data.semesters) {
      final start = _parseFlexibleDate(semester.startDate);
      final end = _parseFlexibleDate(semester.endDate);

      if (start == null || end == null) {
        continue;
      }

      final normalizedStart = _normalizeDate(start);
      final normalizedEnd = _normalizeDate(end);
      if (!today.isBefore(normalizedStart) && !today.isAfter(normalizedEnd)) {
        return semester.name;
      }
    }

    return '--';
  }

  final selected = data.semesters.where((item) => item.id == selectedId);
  return selected.isEmpty ? '--' : selected.first.name;
}

String _normalizedDateKey(String? raw) {
  final parsed = _parseFlexibleDate(raw);
  if (parsed == null) {
    return raw?.trim() ?? '';
  }

  final normalized = _normalizeDate(parsed);
  final year = normalized.year.toString().padLeft(4, '0');
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
