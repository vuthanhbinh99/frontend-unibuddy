import 'package:flutter/material.dart';

import '../../models/auth_models.dart' as auth;
import '../../models/student_course_models.dart';
import '../../models/student_home_models.dart';
import '../../models/student_schedule_models.dart';
import '../../services/api/modules/student_api_service.dart';
import 'focus_mode_screen.dart';
import 'home_screen.dart';
import 'student_catalog_tab.dart';
import 'student_schedule_tab.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({
    super.key,
    required this.session,
    required this.studentApi,
    required this.onLogout,
  });

  final auth.AuthSession session;
  final StudentApiService studentApi;
  final Future<void> Function() onLogout;

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  int _selectedIndex = 0;
  late Future<StudentHomeData> _homeDataFuture;
  late Future<StudentScheduleData> _scheduleDataFuture;
  late Future<StudentCourseData> _courseDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = widget.studentApi.getStudentHomeData();
    _scheduleDataFuture = widget.studentApi.listSchedules();
    _courseDataFuture = widget.studentApi.listCourses();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Trang chủ', 'Lịch học', 'Danh mục'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          FutureBuilder<StudentHomeData>(
            future: _homeDataFuture,
            initialData: StudentHomeData.fromCurrentUser(widget.session.user),
            builder: (context, snapshot) {
              final homeData =
                  snapshot.data ??
                  StudentHomeData.fromCurrentUser(widget.session.user);

              return HomeScreen(
                showAppBar: false,
                profile: homeData.profile,
                courses: homeData.courses,
                projects: homeData.projects,
                schedule: homeData.schedule,
                onOpenFocusMode: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FocusModeScreen()),
                  );
                },
                onLogout: () {
                  widget.onLogout();
                },
              );
            },
          ),
          FutureBuilder<StudentScheduleData>(
            future: _scheduleDataFuture,
            initialData: const StudentScheduleData(
              message: 'Đang tải lịch học...',
              warning: null,
              items: [],
            ),
            builder: (context, snapshot) {
              final data =
                  snapshot.data ??
                  const StudentScheduleData(
                    message: 'Đang tải lịch học...',
                    warning: null,
                    items: [],
                  );
              return StudentScheduleTab(
                data: data,
                onRefresh: () async {
                  setState(() {
                    _scheduleDataFuture = widget.studentApi.listSchedules();
                  });
                  await _scheduleDataFuture;
                },
              );
            },
          ),
          FutureBuilder<StudentCourseData>(
            future: _courseDataFuture,
            initialData: const StudentCourseData(
              message: 'Đang tải danh mục...',
              selectedSemesterId: null,
              semesters: [],
              items: [],
            ),
            builder: (context, snapshot) {
              final data =
                  snapshot.data ??
                  const StudentCourseData(
                    message: 'Đang tải danh mục...',
                    selectedSemesterId: null,
                    semesters: [],
                    items: [],
                  );
              return StudentCatalogTab(
                data: data,
                onRefresh: () async {
                  setState(() {
                    _courseDataFuture = widget.studentApi.listCourses();
                  });
                  await _courseDataFuture;
                },
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch học',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Danh mục',
          ),
        ],
      ),
    );
  }
}
