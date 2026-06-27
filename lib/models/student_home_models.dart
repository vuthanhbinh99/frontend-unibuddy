import 'auth_models.dart';

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
}
