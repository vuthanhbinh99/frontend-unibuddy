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
  }) {
    final totalCredits =
        gradeData.summary.calculatedCredits +
        gradeData.summary.remainingCredits;
    final fallbackCredits = courseData.items.fold<int>(
      0,
      (sum, item) => sum + item.credits,
    );
    final todayBackendDay = _todayBackendDay();
    final todaySchedule = scheduleData.items
        .where((item) => item.dayOfWeek == todayBackendDay)
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
        joinedSemester: _selectedSemesterName(courseData),
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
      projects: const [],
      schedule: todaySchedule,
    );
  }
}

int _todayBackendDay() {
  final weekday = DateTime.now().weekday;
  return weekday == DateTime.sunday ? 8 : weekday + 1;
}

String _selectedSemesterName(catalog.StudentCourseData data) {
  final selectedId = data.selectedSemesterId;
  if (selectedId == null) {
    return data.semesters.isEmpty ? '--' : data.semesters.first.name;
  }

  final selected = data.semesters.where((item) => item.id == selectedId);
  return selected.isEmpty ? '--' : selected.first.name;
}
