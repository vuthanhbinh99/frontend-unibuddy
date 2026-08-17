import '../../../../models/auth_models.dart';
import '../../../../models/student_assistant_models.dart';
import '../../../../models/student_course_models.dart';
import '../../../../models/student_deadline_models.dart';
import '../../../../models/student_exam_models.dart';
import '../../../../models/student_flashcard_models.dart';
import '../../../../models/student_grade_models.dart';
import '../../../../models/student_home_models.dart';
import '../../../../models/student_kanban_models.dart';
import '../../../../models/student_note_models.dart';
import '../../../../models/student_notification_models.dart';
import '../../../../models/student_schedule_models.dart';
import '../../../../models/student_study_group_models.dart';
import '../../../../models/student_storage_models.dart';
import '../../core/api_client.dart';

/// Module API cho các chức năng backend của role `SINH_VIEN`.
///
/// Các API hồ sơ sinh viên, học phần, lịch học, ghi chú, tài liệu, flashcard,
/// Kanban, nhóm học tập, thông báo và trợ lý AI được gom ở đây.
class StudentApiService {
  StudentApiService(this._apiClient);

  final ApiClient _apiClient;

  // ===========================================================================
  // MODULE 1: Cấu hình chung
  // ===========================================================================
  // Nhóm này không gọi endpoint nghiệp vụ trực tiếp.
  // Nó chỉ chỉnh cách StudentApiService gửi request xuống ApiClient.

  /// Cập nhật ngôn ngữ cho các request student, ví dụ message lỗi/trả về từ backend.
  void setAcceptLanguageCode(String? languageCode) {
    _apiClient.setAcceptLanguageCode(languageCode);
  }

  // ===========================================================================
  // MODULE 2: Tài khoản & hồ sơ sinh viên
  // ===========================================================================
  // Các API liên quan đến `/users/me`: đọc hồ sơ, cập nhật thông tin cá nhân,
  // và upload ảnh đại diện của sinh viên đang đăng nhập.

  /// Lấy thông tin người dùng hiện tại qua `/users/me`.
  Future<PublicUser> getCurrentUser() async {
    final data = await _apiClient.get('/users/me');
    return PublicUser.fromJson(data as Map<String, dynamic>);
  }

  /// Cập nhật hồ sơ cá nhân của sinh viên.
  Future<PublicUser> updateCurrentUserProfile({
    required String fullName,
    String? phoneNumber,
    String? maSinhVien,
  }) async {
    final payload = <String, Object?>{
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'maSinhVien': maSinhVien,
    };
    final data = await _apiClient.patch('/users/me', body: payload);
    final map = data as Map<String, dynamic>;
    final rawUser = map['user'] ?? data;
    return PublicUser.fromJson(rawUser as Map<String, dynamic>);
  }

  /// Upload ảnh đại diện của sinh viên bằng multipart request.
  Future<PublicUser> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final data = await _apiClient.postMultipart(
      '/users/me/avatar',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
      fields: {'mimeType': mimeType},
    );
    final map = data as Map<String, dynamic>;
    final rawUser = map['user'] ?? data;
    return PublicUser.fromJson(rawUser as Map<String, dynamic>);
  }

  // ===========================================================================
  // MODULE 3: Góp ý & phản hồi
  // ===========================================================================
  // Các API để sinh viên gửi phản hồi cho hệ thống.
  // Nếu có file đính kèm thì dùng multipart request.

  /// Gửi góp ý/phản hồi của sinh viên, có thể kèm file đính kèm.
  Future<void> submitFeedback({
    required String category,
    required String message,
    List<int>? attachmentBytes,
    String? attachmentFileName,
    String? attachmentMimeType,
  }) async {
    if (attachmentBytes == null) {
      await _apiClient.post(
        '/users/me/feedback',
        body: _withoutNulls({'category': category, 'message': message.trim()}),
      );
      return;
    }

    await _apiClient.postMultipart(
      '/users/me/feedback',
      fileField: 'file',
      bytes: attachmentBytes,
      filename: attachmentFileName ?? 'feedback-image.jpg',
      fields: (() {
        final fields = <String, String>{
          'category': category,
          'message': message.trim(),
        };
        if (attachmentFileName != null) {
          fields['attachmentFileName'] = attachmentFileName;
        }
        if (attachmentMimeType != null) {
          fields['attachmentMimeType'] = attachmentMimeType;
        }
        return fields;
      })(),
    );
  }

  // ===========================================================================
  // MODULE 4: Phiên đăng nhập & thiết bị
  // ===========================================================================
  // Các API quản lý thiết bị/phiên đăng nhập hiện tại.
  // Dùng cho màn xem phiên và thao tác thu hồi phiên.

  /// Lấy danh sách phiên đăng nhập/thiết bị hiện tại của sinh viên.
  Future<List<AuthDeviceSession>> listCurrentUserSessions(
    String refreshToken,
  ) async {
    final data = await _apiClient.post(
      '/auth/sessions',
      body: {'refreshToken': refreshToken},
    );
    final items = data as List<dynamic>;
    return items
        .map((item) => AuthDeviceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Thu hồi một phiên đăng nhập theo session id.
  Future<void> revokeCurrentUserSession(String sessionId) async {
    await _apiClient.delete('/auth/sessions/${Uri.encodeComponent(sessionId)}');
  }

  // ===========================================================================
  // MODULE 5: Trang chủ sinh viên
  // ===========================================================================
  // Gom nhiều nguồn dữ liệu để dựng màn Home: profile, lịch học, deadline,
  // bảng điểm và các task Kanban cần theo dõi.

  /// Tải dữ liệu trang chủ sinh viên bằng cách gom profile, lịch học, deadline, điểm và Kanban.
  Future<StudentHomeData> getStudentHomeData() async {
    final user = await getCurrentUser();
    final courses = await _fallback(
      () => listCourses(),
      const StudentCourseData(
        message: 'Chưa có dữ liệu môn học.',
        selectedSemesterId: null,
        semesters: [],
        items: [],
      ),
    );
    final schedules = await _fallback(
      () => listSchedules(),
      const StudentScheduleData(
        message: 'Chưa có dữ liệu lịch học.',
        warning: null,
        items: [],
      ),
    );
    final grades = await _fallback(
      () => getGradeTranscript(),
      StudentGradeTranscriptData.empty(),
    );
    final projects = await _loadPersonalKanbanProjects(user);

    return StudentHomeData.fromBackend(
      user: user,
      courseData: courses,
      scheduleData: schedules,
      gradeData: grades,
      projects: projects,
    );
  }

  /// Gom task Kanban cá nhân/nhóm để hiển thị thành project trên trang chủ.
  Future<List<Project>> _loadPersonalKanbanProjects(PublicUser user) async {
    final groups = await _fallback(
      () => listStudyGroups(),
      const StudentStudyGroupData(message: 'Chưa có nhóm học tập.', items: []),
    );
    if (groups.items.isEmpty) {
      return const [];
    }

    final projects = <Project>[];
    final boardResults = await Future.wait(
      groups.items.map((group) async {
        try {
          final board = await getKanbanBoard(group.id);
          return (group: group, board: board);
        } catch (_) {
          return (group: group, board: null);
        }
      }),
    );

    for (final result in boardResults) {
      final board = result.board;
      if (board == null) {
        continue;
      }
      final group = result.group;
      final personalTasks =
          board.tasks
              .where(
                (task) =>
                    task.assigneeId == user.id &&
                    _shouldShowKanbanTaskOnHome(task),
              )
              .toList()
            ..sort(_compareKanbanTasksForHome);
      for (final task in personalTasks) {
        projects.add(
          Project(
            name: task.title,
            subject: _kanbanTaskSubject(group, task),
            icon: _kanbanProjectIcon(task.status),
            color: _kanbanProjectColor(task.status),
            role: group.role.value,
            progress: _kanbanTaskProgress(task.status),
          ),
        );
      }
    }

    return projects;
  }

  /// Chỉ lấy các task Kanban còn cần theo dõi trên trang chủ.
  bool _shouldShowKanbanTaskOnHome(StudentKanbanTask task) {
    return task.status == StudentKanbanStatus.todo ||
        task.status == StudentKanbanStatus.doing;
  }

  /// Sắp xếp task Kanban theo mức ưu tiên hiển thị ở trang chủ.
  int _compareKanbanTasksForHome(
    StudentKanbanTask left,
    StudentKanbanTask right,
  ) {
    final statusComparison = _kanbanTaskSortWeight(
      left.status,
    ).compareTo(_kanbanTaskSortWeight(right.status));
    if (statusComparison != 0) {
      return statusComparison;
    }

    final leftDue = left.dueDate;
    final rightDue = right.dueDate;
    if (leftDue != null && rightDue != null) {
      return leftDue.compareTo(rightDue);
    }
    if (leftDue != null) {
      return -1;
    }
    if (rightDue != null) {
      return 1;
    }

    return left.title.compareTo(right.title);
  }

  /// Quy đổi trạng thái Kanban thành trọng số để sort task.
  int _kanbanTaskSortWeight(StudentKanbanStatus status) {
    switch (status) {
      case StudentKanbanStatus.overdue:
        return 0;
      case StudentKanbanStatus.doing:
        return 1;
      case StudentKanbanStatus.todo:
        return 2;
      case StudentKanbanStatus.done:
        return 3;
    }
  }

  /// Tạo nhãn môn học/nhóm hiển thị cho task Kanban ở trang chủ.
  String _kanbanTaskSubject(StudentStudyGroup group, StudentKanbanTask task) {
    final groupName = group.name.trim().isEmpty ? 'Nhóm học tập' : group.name;
    return '${group.courseLabel} • $groupName • ${task.status.label}';
  }

  /// Chọn icon đại diện theo trạng thái task Kanban.
  String _kanbanProjectIcon(StudentKanbanStatus status) {
    switch (status) {
      case StudentKanbanStatus.doing:
        return 'Laptop';
      case StudentKanbanStatus.done:
        return 'BookOpen';
      case StudentKanbanStatus.overdue:
        return 'Cpu';
      case StudentKanbanStatus.todo:
        return 'Globe';
    }
  }

  /// Chọn màu đại diện theo trạng thái task Kanban.
  String _kanbanProjectColor(StudentKanbanStatus status) {
    switch (status) {
      case StudentKanbanStatus.doing:
        return 'sky';
      case StudentKanbanStatus.done:
        return 'emerald';
      case StudentKanbanStatus.overdue:
        return 'rose';
      case StudentKanbanStatus.todo:
        return 'indigo';
    }
  }

  /// Quy đổi trạng thái Kanban thành phần trăm tiến độ hiển thị.
  int _kanbanTaskProgress(StudentKanbanStatus status) {
    switch (status) {
      case StudentKanbanStatus.todo:
        return 0;
      case StudentKanbanStatus.doing:
        return 50;
      case StudentKanbanStatus.done:
        return 100;
      case StudentKanbanStatus.overdue:
        return 25;
    }
  }

  // ===========================================================================
  // MODULE 6: Helper payload dùng chung
  // ===========================================================================
  // Helper nhỏ phục vụ nhiều module bên dưới.
  // Mục tiêu là giữ payload gửi backend gọn và tránh field rỗng không cần thiết.

  /// Bỏ field null hoặc chuỗi rỗng khỏi body trước khi gửi request student.
  Map<String, Object?> _withoutNulls(Map<String, Object?> input) {
    final result = <String, Object?>{};
    for (final entry in input.entries) {
      if (entry.value != null) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  // ===========================================================================
  // MODULE 7: Lịch học
  // ===========================================================================
  // Các API CRUD lịch học của sinh viên.

  /// Lấy lịch học của sinh viên, có thể lọc theo môn học.
  Future<StudentScheduleData> listSchedules({String? maMonHoc}) async {
    final data = await _apiClient.get(
      '/schedules',
      query: maMonHoc == null ? null : {'maMonHoc': maMonHoc},
    );
    return StudentScheduleData.fromJson(data);
  }

  /// Tạo lịch học mới cho một môn học.
  Future<StudentScheduleItem> createSchedule({
    required String courseId,
    required int dayOfWeek,
    required int startPeriod,
    required int periodCount,
    String? room,
    String? startDate,
    String? endDate,
  }) async {
    final normalizedRoom = room?.trim();
    final data = await _apiClient.post(
      '/schedules',
      body: {
        'maMonHoc': courseId,
        'thu': dayOfWeek,
        'tietBatDau': startPeriod,
        'soTiet': periodCount,
        'phongHoc': normalizedRoom == null || normalizedRoom.isEmpty
            ? null
            : normalizedRoom,
        'ngayBatDau': startDate,
        'ngayKetThuc': endDate,
      },
    );
    return _scheduleFromMutation(data);
  }

  /// Cập nhật thông tin một lịch học đã có.
  Future<void> updateSchedule({
    required String scheduleId,
    required String courseId,
    required int dayOfWeek,
    required int startPeriod,
    required int periodCount,
    String? room,
    String? startDate,
    String? endDate,
  }) async {
    final normalizedRoom = room?.trim();
    await _apiClient.put(
      '/schedules/${Uri.encodeComponent(scheduleId)}',
      body: {
        'maMonHoc': courseId,
        'thu': dayOfWeek,
        'tietBatDau': startPeriod,
        'soTiet': periodCount,
        'phongHoc': normalizedRoom == null || normalizedRoom.isEmpty
            ? null
            : normalizedRoom,
        'ngayBatDau': startDate,
        'ngayKetThuc': endDate,
      },
    );
  }

  /// Xóa một lịch học theo id.
  Future<void> deleteSchedule({required String scheduleId}) async {
    await _apiClient.delete('/schedules/${Uri.encodeComponent(scheduleId)}');
  }

  /// Parse response tạo/cập nhật lịch học; backend có thể bọc item trong key `lichHoc`.
  StudentScheduleItem _scheduleFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawSchedule = map['lichHoc'] ?? data;
    return StudentScheduleItem.fromJson(rawSchedule as Map<String, dynamic>);
  }

  // ===========================================================================
  // MODULE 8: Lịch thi
  // ===========================================================================
  // Các API CRUD lịch thi của sinh viên.

  /// Lấy danh sách lịch thi, có thể lọc theo môn học.
  Future<StudentExamData> listExams({String? maMonHoc}) async {
    final data = await _apiClient.get(
      '/exams',
      query: maMonHoc == null ? null : {'maMonHoc': maMonHoc},
    );
    return StudentExamData.fromJson(data);
  }

  /// Tạo lịch thi mới.
  Future<StudentExamItem> createExam({
    required String courseId,
    required DateTime examTime,
    String? room,
    String? examLocation,
    bool replaceExistingExam = false,
  }) async {
    final data = await _apiClient.post(
      '/exams',
      body: _withoutNulls({
        'maMonHoc': courseId,
        'thoiGianThi': examTime.toIso8601String(),
        'phongThi': room?.trim(),
        'diaDiemThi': examLocation?.trim(),
        'replaceExistingExam': replaceExistingExam,
      }),
    );
    return _examFromMutation(data);
  }

  /// Cập nhật lịch thi đã có.
  Future<StudentExamItem> updateExam({
    required String examId,
    required String courseId,
    required DateTime examTime,
    String? room,
    String? examLocation,
  }) async {
    final data = await _apiClient.put(
      '/exams/${Uri.encodeComponent(examId)}',
      body: _withoutNulls({
        'maMonHoc': courseId,
        'thoiGianThi': examTime.toIso8601String(),
        'phongThi': room?.trim(),
        'diaDiemThi': examLocation?.trim(),
      }),
    );
    return _examFromMutation(data);
  }

  /// Xóa lịch thi theo id.
  Future<void> deleteExam({required String examId}) async {
    await _apiClient.delete('/exams/${Uri.encodeComponent(examId)}');
  }

  /// Parse response tạo/cập nhật lịch thi; backend có thể bọc item trong key `lichThi`.
  StudentExamItem _examFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawExam = map['lichThi'] ?? data;
    return StudentExamItem.fromJson(rawExam as Map<String, dynamic>);
  }

  // ===========================================================================
  // MODULE 9: Import lịch thi
  // ===========================================================================
  // Quy trình import lịch thi: đọc header -> preview mapping -> AI gợi ý mapping
  // nếu cần -> xác nhận import.

  /// Upload file lịch thi để backend đọc danh sách cột/header.
  Future<StudentExamImportHeadersData> extractExamImportHeaders({
    required List<int> bytes,
    required String fileName,
  }) async {
    final data = await _apiClient.postMultipart(
      '/exams/import/headers',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
    );
    return StudentExamImportHeadersData.fromJson(data as Map<String, dynamic>);
  }

  /// Gửi mapping cột để backend preview dữ liệu lịch thi trước khi import thật.
  Future<StudentExamImportPreviewData> previewExamImport({
    required List<Map<String, Object?>> rows,
    required StudentExamImportMapping mapping,
    String? maHocKy,
  }) async {
    final data = await _apiClient.post(
      '/exams/import/preview',
      body: {'maHocKy': maHocKy, 'rows': rows, 'mapping': mapping.toJson()},
    );
    return StudentExamImportPreviewData.fromJson(data as Map<String, dynamic>);
  }

  /// Nhờ AI gợi ý mapping cột cho file import lịch thi.
  Future<StudentExamImportMapping> suggestExamImportMappingWithAi({
    required List<String> headers,
    required List<Map<String, Object?>> sampleRows,
  }) async {
    final data = await _apiClient.post(
      '/exams/ai/suggest-mapping',
      body: {'headers': headers, 'sampleRows': sampleRows},
    );
    final map = data as Map<String, dynamic>;
    final rawMapping = map['mapping'];
    return StudentExamImportMapping.fromJson(
      rawMapping is Map ? rawMapping : null,
    );
  }

  /// Xác nhận import lịch thi sau bước preview.
  Future<StudentExamImportConfirmData> confirmExamImport({
    required List<StudentExamImportCandidate> items,
    bool replaceExistingExams = false,
  }) async {
    final data = await _apiClient.post(
      '/exams/import/confirm',
      body: {
        'items': items.map((item) => item.toJson()).toList(),
        'replaceExistingExams': replaceExistingExams,
      },
    );
    return StudentExamImportConfirmData.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{},
    );
  }

  // ===========================================================================
  // MODULE 10: Import lịch học
  // ===========================================================================
  // Quy trình import lịch học: đọc header -> preview mapping -> AI gợi ý mapping
  // nếu cần -> xác nhận import.

  /// Upload file lịch học để backend đọc danh sách cột/header.
  Future<StudentScheduleImportHeadersData> extractScheduleImportHeaders({
    required List<int> bytes,
    required String fileName,
  }) async {
    final data = await _apiClient.postMultipart(
      '/schedules/import/headers',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
    );
    return StudentScheduleImportHeadersData.fromJson(
      data as Map<String, dynamic>,
    );
  }

  /// Gửi mapping cột để backend preview dữ liệu lịch học trước khi import thật.
  Future<StudentScheduleImportPreviewData> previewScheduleImport({
    required List<Map<String, Object?>> rows,
    required StudentScheduleImportMapping mapping,
    String? maHocKy,
    bool replaceExistingCourseSchedules = false,
  }) async {
    final data = await _apiClient.post(
      '/schedules/import/preview',
      body: {
        'maHocKy': maHocKy,
        'rows': rows,
        'mapping': mapping.toJson(),
        'replaceExistingCourseSchedules': replaceExistingCourseSchedules,
      },
    );
    return StudentScheduleImportPreviewData.fromJson(
      data as Map<String, dynamic>,
    );
  }

  /// Nhờ AI gợi ý mapping cột cho file import lịch học.
  Future<StudentScheduleImportMapping> suggestScheduleImportMappingWithAi({
    required List<String> headers,
    required List<Map<String, Object?>> sampleRows,
  }) async {
    final data = await _apiClient.post(
      '/schedules/ai/suggest-mapping',
      body: {'headers': headers, 'sampleRows': sampleRows},
    );
    final map = data as Map<String, dynamic>;
    final rawMapping = map['mapping'];
    return StudentScheduleImportMapping.fromJson(
      rawMapping is Map ? rawMapping : null,
    );
  }

  /// Xác nhận import lịch học sau bước preview.
  Future<StudentScheduleImportConfirmData> confirmScheduleImport({
    required List<StudentScheduleImportCandidate> items,
    String? maHocKy,
    bool replaceExistingCourseSchedules = false,
  }) async {
    final data = await _apiClient.post(
      '/schedules/import/confirm',
      body: {
        'maHocKy': maHocKy,
        'items': items.map((item) => item.toJson()).toList(),
        'replaceExistingCourseSchedules': replaceExistingCourseSchedules,
      },
    );
    return StudentScheduleImportConfirmData.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{},
    );
  }

  // ===========================================================================
  // MODULE 11: Học kỳ, học phần & điểm thành phần
  // ===========================================================================
  // Các API quản lý học kỳ, môn học, trọng số điểm và các cột điểm con.

  /// Lấy danh sách học kỳ, môn học và dữ liệu điểm liên quan.
  Future<StudentCourseData> listCourses({
    String? maHocKy,
    bool tatCa = false,
  }) async {
    final data = await _apiClient.get(
      '/courses',
      query: tatCa
          ? {'tatCa': 'true'}
          : (maHocKy == null ? null : {'maHocKy': maHocKy}),
    );
    return StudentCourseData.fromJson(data);
  }

  /// Tạo học kỳ mới cho sinh viên.
  Future<StudentSemester> createSemester({
    required String name,
    String? startDate,
    String? endDate,
  }) async {
    final data = await _apiClient.post(
      '/courses/semesters',
      body: _withoutNulls({
        'tenHocKy': name.trim(),
        'ngayBatDau': startDate?.trim(),
        'ngayKetThuc': endDate?.trim(),
      }),
    );
    final map = Map<String, dynamic>.from(data as Map);
    final rawSemester = map['hocKy'] ?? data;
    return StudentSemester.fromJson(
      Map<String, dynamic>.from(rawSemester as Map),
    );
  }

  /// Cập nhật thông tin học kỳ.
  Future<void> updateSemester({
    required String semesterId,
    required String name,
    String? startDate,
    String? endDate,
  }) async {
    await _apiClient.put(
      '/courses/semesters/${Uri.encodeComponent(semesterId)}',
      body: _withoutNulls({
        'tenHocKy': name.trim(),
        'ngayBatDau': startDate?.trim(),
        'ngayKetThuc': endDate?.trim(),
      }),
    );
  }

  /// Xóa học kỳ; tham số force dùng khi backend yêu cầu xác nhận xóa dữ liệu liên quan.
  Future<void> deleteSemester(String semesterId, {bool force = false}) async {
    await _apiClient.delete(
      '/courses/semesters/${Uri.encodeComponent(semesterId)}',
      body: {'force': force},
    );
  }

  /// Tạo môn học mới trong một học kỳ.
  Future<StudentCourseItem> createCourse({
    required String semesterId,
    required String name,
    required int credits,
    String? code,
  }) async {
    final normalizedCode = code?.trim();
    final data = await _apiClient.post(
      '/courses',
      body: {
        'maHocKy': semesterId,
        'maMon': normalizedCode == null || normalizedCode.isEmpty
            ? null
            : normalizedCode,
        'tenMon': name.trim(),
        'soTinChi': credits,
      },
    );
    return _courseFromMutation(data);
  }

  /// Cập nhật thông tin môn học.
  Future<StudentCourseItem> updateCourse({
    required String courseId,
    required String semesterId,
    required String name,
    required int credits,
    String? code,
  }) async {
    final normalizedCode = code?.trim();
    final data = await _apiClient.put(
      '/courses/${Uri.encodeComponent(courseId)}',
      body: {
        'maHocKy': semesterId,
        'maMon': normalizedCode == null || normalizedCode.isEmpty
            ? null
            : normalizedCode,
        'tenMon': name.trim(),
        'soTinChi': credits,
      },
    );
    return _courseFromMutation(data);
  }

  /// Xóa môn học; tham số force dùng khi backend yêu cầu xác nhận xóa dữ liệu liên quan.
  Future<void> deleteCourse(String courseId, {bool force = false}) async {
    await _apiClient.delete(
      '/courses/${Uri.encodeComponent(courseId)}',
      body: {'force': force},
    );
  }

  /// Cấu hình trọng số chuyên cần/giữa kỳ/cuối kỳ cho môn học.
  Future<void> configureGradeWeights({
    required String courseId,
    required List<StudentGradeWeightInput> components,
  }) async {
    await _apiClient.post(
      '/diem-so/trong-so',
      body: {
        'maMonHoc': courseId,
        'components': components
            .map((component) => component.toJson())
            .toList(),
      },
    );
  }

  /// Tạo một cột/thành phần điểm cho môn học.
  Future<StudentGradeComponent> createGradeComponent({
    required String courseId,
    required String name,
    required double weight,
    required double score,
  }) async {
    final data = await _apiClient.post(
      '/diem-so',
      body: {
        'maMonHoc': courseId,
        'tenThanhPhan': name.trim(),
        'trongSo': weight,
        'diem': score,
      },
    );
    return StudentGradeComponent.fromJson(data as Map<String, dynamic>);
  }

  /// Cập nhật điểm hoặc thông tin thành phần điểm.
  Future<StudentGradeComponent> updateGradeComponent({
    required String componentId,
    required double score,
  }) async {
    final data = await _apiClient.put(
      '/diem-so/${Uri.encodeComponent(componentId)}',
      body: {'diem': score},
    );
    return StudentGradeComponent.fromJson(data as Map<String, dynamic>);
  }

  // ===========================================================================
  // MODULE 12: Ghi chú học tập
  // ===========================================================================
  // Các API tạo/sửa/xóa ghi chú và đính kèm tài liệu vào ghi chú.

  /// Lấy danh sách ghi chú, có tìm kiếm/lọc theo môn học và phân trang.
  Future<StudentNoteData> listNotes({
    String? query,
    String? courseId,
    StudentNoteSort sort = StudentNoteSort.updatedDesc,
    int page = 1,
    int limit = 50,
  }) async {
    final data = await _apiClient.get(
      '/notes',
      query: _query({
        'q': query,
        'maMonHoc': courseId,
        'sort': sort.value,
        'page': page.toString(),
        'limit': limit.toString(),
      }),
    );
    return StudentNoteData.fromJson(data);
  }

  /// Lấy chi tiết một ghi chú.
  Future<StudentNote> getNoteDetail(String noteId) async {
    final data = await _apiClient.get('/notes/${Uri.encodeComponent(noteId)}');
    return StudentNote.fromJson(data as Map<String, dynamic>);
  }

  /// Tạo ghi chú mới.
  Future<StudentNote> createNote({
    required String title,
    String? content,
    String? courseId,
    List<StudentNoteAttachmentInput> attachments = const [],
  }) async {
    final data = await _apiClient.post(
      '/notes',
      body: {
        'tieuDe': title,
        'noiDung': content,
        'maMonHoc': courseId,
        'tepDinhKem': attachments.map((item) => item.toJson()).toList(),
      },
    );
    return _noteFromMutation(data);
  }

  /// Cập nhật ghi chú đã có.
  Future<StudentNote> updateNote({
    required String noteId,
    required String title,
    String? content,
    String? courseId,
    List<StudentNoteAttachmentInput> newAttachments = const [],
    List<String> deletedAttachmentIds = const [],
  }) async {
    final data = await _apiClient.put(
      '/notes/${Uri.encodeComponent(noteId)}',
      body: {
        'tieuDe': title,
        'noiDung': content,
        'maMonHoc': courseId,
        'tepDinhKemMoi': newAttachments.map((item) => item.toJson()).toList(),
        'maTaiLieuCanXoa': deletedAttachmentIds,
      },
    );
    return _noteFromMutation(data);
  }

  /// Đính kèm tài liệu/file vào ghi chú bằng multipart request.
  Future<StudentNoteAttachment> attachNoteDocument({
    required String noteId,
    required StudentNoteAttachmentInput attachment,
  }) async {
    final data = await _apiClient.post(
      '/attachments',
      body: {'maGhiChu': noteId, ...attachment.toJson()},
    );
    final map = data as Map<String, dynamic>;
    final rawAttachment = map['taiLieu'] ?? map['tepDinhKem'] ?? data;
    return StudentNoteAttachment.fromJson(
      rawAttachment as Map<String, dynamic>,
    );
  }

  /// Xóa ghi chú theo id.
  Future<void> deleteNote(String noteId) async {
    await _apiClient.delete('/notes/${Uri.encodeComponent(noteId)}');
  }

  // ===========================================================================
  // MODULE 13: Thông báo
  // ===========================================================================
  // Các API đọc, ẩn và đánh dấu thông báo của sinh viên.

  /// Lấy danh sách thông báo của sinh viên theo trạng thái/loại.
  Future<StudentNotificationData> listNotifications({
    StudentNotificationStatusFilter status =
        StudentNotificationStatusFilter.all,
    StudentNotificationCategory? category,
    int page = 1,
    int limit = 50,
  }) async {
    final data = await _apiClient.get(
      '/notifications',
      query: _query({
        'status': status.value,
        'loaiThongBao': category?.value,
        'page': page.toString(),
        'limit': limit.toString(),
      }),
    );
    return StudentNotificationData.fromJson(data);
  }

  /// Đánh dấu một thông báo là đã đọc.
  Future<void> markNotificationRead(String notificationId) async {
    await _apiClient.patch(
      '/notifications/${Uri.encodeComponent(notificationId)}/read',
    );
  }

  /// Ẩn một thông báo khỏi UI của sinh viên.
  Future<void> hideNotification(String notificationId) async {
    await _apiClient.patch(
      '/notifications/${Uri.encodeComponent(notificationId)}/hide',
    );
  }

  /// Đánh dấu toàn bộ thông báo là đã đọc.
  Future<void> markAllNotificationsRead() async {
    await _apiClient.patch('/notifications/read-all');
  }

  // ===========================================================================
  // MODULE 14: Kho tài liệu sinh viên
  // ===========================================================================
  // Các API quản lý tài liệu: list, tạo metadata, đổi hiển thị, báo cáo
  // và nhờ AI tóm tắt nội dung.

  /// Lấy danh sách tài liệu lưu trữ của sinh viên, có tìm kiếm/lọc/phân trang.
  Future<StudentStorageData> listStorageDocuments({
    String? query,
    int page = 1,
    int limit = 100,
  }) async {
    final data = await _apiClient.get(
      '/student/documents',
      query: _query({
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
      }),
    );
    return StudentStorageData.fromJson(data);
  }

  /// Tạo metadata tài liệu chia sẻ; hiện route này chưa upload byte file thật nếu backend chưa hỗ trợ.
  Future<StudentStorageFile> uploadSharedDocument({
    required String title,
    required String courseId,
    required StudentStorageVisibility visibility,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final data = await _apiClient.postMultipart(
      '/student/documents',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
      fields: {
        'tieuDe': title.trim(),
        'maMonHoc': courseId,
        'cheDoHienThi': visibility.value,
        'loaiFile': mimeType,
        'dungLuong': sizeBytes.toString(),
      },
    );
    final map = data as Map<String, dynamic>;
    final rawFile = map['taiLieu'] ?? data;
    return StudentStorageFile.fromJson(rawFile as Map<String, dynamic>);
  }

  /// Xóa mềm tài liệu lưu trữ theo id.
  Future<void> deleteStorageDocument(String documentId) async {
    await _apiClient.delete(
      '/student/documents/${Uri.encodeComponent(documentId)}',
    );
  }

  /// Cập nhật chế độ hiển thị/chia sẻ của tài liệu.
  Future<void> updateStorageDocumentVisibility({
    required String documentId,
    required StudentStorageVisibility visibility,
  }) async {
    await _apiClient.patch(
      '/student/documents/${Uri.encodeComponent(documentId)}/visibility',
      body: {'cheDoHienThi': visibility.value},
    );
  }

  /// Gửi báo cáo vi phạm cho một tài liệu.
  Future<void> reportDocument({
    required String documentId,
    required String reason,
  }) async {
    await _apiClient.post(
      '/student/documents/${Uri.encodeComponent(documentId)}/report',
      body: {'lyDo': reason.trim()},
    );
  }

  /// Gửi nội dung tài liệu cho AI để tóm tắt/gợi ý học tập.
  Future<Map<String, dynamic>> summarizeDocumentWithAi({
    required String title,
    required String content,
    String? objective,
  }) async {
    final data = await _apiClient.post(
      '/student/documents/ai/summarize',
      body: {
        'title': title.trim(),
        'content': content.trim(),
        'objective': _nullableTrim(objective),
      },
    );
    return data as Map<String, dynamic>;
  }

  // ===========================================================================
  // MODULE 15: Flashcard
  // ===========================================================================
  // Các API quản lý bộ flashcard, thẻ flashcard, import file/AI và ghi nhận
  // kết quả ôn tập.

  /// Lấy danh sách bộ flashcard, có thể lọc theo môn học.
  Future<StudentFlashcardDeckData> listFlashcardDecks({
    String? courseId,
  }) async {
    final data = await _apiClient.get(
      '/flashcard-decks',
      query: _query({'maMonHoc': courseId}),
    );
    return StudentFlashcardDeckData.fromJson(data);
  }

  /// Lấy thống kê học flashcard của sinh viên.
  Future<StudentFlashcardStatisticsData> getFlashcardStatistics() async {
    final data = await _apiClient.get('/flashcards/statistics');
    return StudentFlashcardStatisticsData.fromJson(data);
  }

  /// Tạo bộ flashcard mới.
  Future<StudentFlashcardMutationData> createFlashcardDeck({
    required String title,
    String? courseId,
  }) async {
    final data = await _apiClient.post(
      '/flashcard-decks',
      body: {'tenBo': title.trim(), 'maMonHoc': courseId},
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Xóa bộ flashcard theo id.
  Future<void> deleteFlashcardDeck(String deckId) async {
    await _apiClient.delete('/flashcard-decks/${Uri.encodeComponent(deckId)}');
  }

  /// Tạo flashcard dạng thuật ngữ/định nghĩa.
  Future<StudentFlashcardMutationData> createFlashcard({
    required String deckId,
    required String front,
    required String back,
  }) async {
    final data = await _apiClient.post(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/flashcards',
      body: {
        'loaiThe': StudentFlashcardCardType.essay.value,
        'matTruoc': front.trim(),
        'matSau': back.trim(),
      },
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Tạo flashcard dạng câu hỏi trắc nghiệm.
  Future<StudentFlashcardMutationData> createQuizFlashcard({
    required String deckId,
    required StudentFlashcardQuizDraft quiz,
  }) async {
    final data = await _apiClient.post(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/flashcards',
      body: {
        'loaiThe': StudentFlashcardCardType.quiz.value,
        'tracNghiem': quiz.toJson(),
      },
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Cập nhật flashcard dạng thuật ngữ/định nghĩa.
  Future<StudentFlashcardMutationData> updateFlashcard({
    required String cardId,
    required String front,
    required String back,
  }) async {
    final data = await _apiClient.put(
      '/flashcards/${Uri.encodeComponent(cardId)}',
      body: {
        'loaiThe': StudentFlashcardCardType.essay.value,
        'matTruoc': front.trim(),
        'matSau': back.trim(),
      },
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Cập nhật flashcard dạng câu hỏi trắc nghiệm.
  Future<StudentFlashcardMutationData> updateQuizFlashcard({
    required String cardId,
    required StudentFlashcardQuizDraft quiz,
  }) async {
    final data = await _apiClient.put(
      '/flashcards/${Uri.encodeComponent(cardId)}',
      body: {
        'loaiThe': StudentFlashcardCardType.quiz.value,
        'tracNghiem': quiz.toJson(),
      },
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Xóa một flashcard theo id.
  Future<void> deleteFlashcard(String cardId) async {
    await _apiClient.delete('/flashcards/${Uri.encodeComponent(cardId)}');
  }

  /// Import flashcards từ file upload.
  Future<StudentFlashcardMutationData> importFlashcards({
    required String deckId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final data = await _apiClient.postMultipart(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/flashcards/import',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Lấy toàn bộ flashcard trong một bộ để quản lý/ôn tập.
  Future<StudentFlashcardReviewData> listAllFlashcards(String deckId) async {
    return startFlashcardReview(deckId, hocLai: true);
  }

  /// Nhờ AI tạo flashcard thường từ nội dung đầu vào.
  Future<StudentFlashcardMutationData> aiImportFlashcards({
    required String deckId,
    required List<int> bytes,
    required String fileName,
    int desiredCount = 8,
  }) async {
    final data = await _apiClient.postMultipart(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/flashcards/ai-import',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
      fields: {'desiredCount': '$desiredCount'},
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Nhờ AI tạo flashcard/câu hỏi dạng tự luận từ nội dung đầu vào.
  Future<StudentFlashcardMutationData> aiImportEssayFlashcards({
    required String deckId,
    required List<int> bytes,
    required String fileName,
    int desiredCount = 8,
  }) async {
    final data = await _apiClient.postMultipart(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/flashcards/ai-import-tu-luan',
      fileField: 'file',
      bytes: bytes,
      filename: fileName,
      fields: {'desiredCount': '$desiredCount'},
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Bắt đầu phiên ôn tập flashcard theo chế độ backend hỗ trợ.
  Future<StudentFlashcardReviewData> startFlashcardReview(
    String deckId, {
    bool hocLai = false,
  }) async {
    final data = await _apiClient.get(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/review',
      query: hocLai ? {'hocLai': 'true'} : null,
    );
    return StudentFlashcardReviewData.fromJson(data);
  }

  /// Ghi nhận kết quả cả phiên ôn tập flashcard.
  Future<void> recordFlashcardSessionResult({
    required String deckId,
    required int correct,
    required int wrong,
  }) async {
    await _apiClient.post(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}/session-result',
      body: {'soCauDung': correct, 'soCauSai': wrong},
    );
  }

  /// Cập nhật tiến độ nhớ của một flashcard.
  Future<StudentFlashcardMutationData> updateFlashcardProgress({
    required String cardId,
    required StudentFlashcardMemoryLevel memoryLevel,
  }) async {
    final data = await _apiClient.patch(
      '/flashcards/${Uri.encodeComponent(cardId)}/progress',
      body: {'mucDo': memoryLevel.value},
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  /// Gửi kết quả trả lời một flashcard trong phiên ôn tập.
  Future<StudentFlashcardMutationData> submitFlashcardResult({
    required String cardId,
    required StudentFlashcardResult result,
    required int responseMs,
  }) async {
    final data = await _apiClient.patch(
      '/flashcards/${Uri.encodeComponent(cardId)}/progress',
      body: {'ketQua': result.value, 'thoiGianPhanHoiMs': responseMs},
    );
    return StudentFlashcardMutationData.fromJson(data);
  }

  // ===========================================================================
  // MODULE 16: Deadline & cài đặt nhắc nhở
  // ===========================================================================
  // Các API deadline và tùy chọn nhắc deadline/thông báo đẩy của sinh viên.

  /// Lấy danh sách deadline, có thể lọc theo môn học và trạng thái.
  Future<StudentDeadlineData> listDeadlines({
    String? maMonHoc,
    StudentDeadlineStatus? status,
  }) async {
    final data = await _apiClient.get(
      '/deadlines',
      query: _query({'maMonHoc': maMonHoc, 'trangThai': status?.value}),
    );
    return StudentDeadlineData.fromJson(data);
  }

  /// Cập nhật trạng thái deadline, ví dụ CHUA_LAM/DANG_LAM/HOAN_THANH.
  Future<StudentDeadlineItem> updateDeadlineStatus({
    required String deadlineId,
    required StudentDeadlineStatus status,
  }) async {
    final data = await _apiClient.patch(
      '/deadlines/${Uri.encodeComponent(deadlineId)}/status',
      body: {'trangThai': status.value},
    );
    return StudentDeadlineItem.fromJson(data as Map<String, dynamic>);
  }

  /// Lấy tùy chỉnh nhắc nhở deadline hiện tại của sinh viên.
  /// Trả về số giờ trước hạn (`null` = dùng mốc mặc định, `0` = tắt nhắc).
  Future<int?> getDeadlineReminderPreference() async {
    final data = await _apiClient.get('/deadlines/reminder-preference');
    final map = data as Map<String, dynamic>;
    final soGio = map['soGioTruocHan'];
    return soGio == null ? null : (soGio as num).toInt();
  }

  /// Cập nhật tùy chỉnh nhắc nhở deadline.
  /// [soGioTruocHan]: `null` = mốc mặc định, `0` = tắt, hoặc 3/12/24.
  Future<int?> updateDeadlineReminderPreference(int? soGioTruocHan) async {
    final data = await _apiClient.patch(
      '/deadlines/reminder-preference',
      body: {'soGioTruocHan': soGioTruocHan},
    );
    final map = data as Map<String, dynamic>;
    final soGio = map['soGioTruocHan'];
    return soGio == null ? null : (soGio as num).toInt();
  }

  /// Lấy tùy chọn nhận thông báo đẩy (toggle "Thông báo ứng dụng").
  /// Trả về `true` nếu đang bật.
  Future<bool> getAppNotificationPreference() async {
    final data = await _apiClient.get('/notifications/preference');
    final map = data as Map<String, dynamic>;
    return (map['nhanThongBao'] as bool?) ?? true;
  }

  /// Cập nhật tùy chọn nhận thông báo đẩy.
  Future<bool> updateAppNotificationPreference(bool nhanThongBao) async {
    final data = await _apiClient.patch(
      '/notifications/preference',
      body: {'nhanThongBao': nhanThongBao},
    );
    final map = data as Map<String, dynamic>;
    return (map['nhanThongBao'] as bool?) ?? nhanThongBao;
  }

  // ===========================================================================
  // MODULE 17: Bảng điểm, GPA & tư vấn học tập
  // ===========================================================================
  // Các API xem bảng điểm, dự phóng GPA và xin lời khuyên học tập từ AI.

  /// Lấy bảng điểm theo học kỳ để hiển thị transcript/GPA.
  Future<StudentGradeTranscriptData> getGradeTranscript({
    String? maHocKy,
  }) async {
    final data = await _apiClient.get(
      '/diem-so/bang-diem',
      query: maHocKy == null ? null : {'maHocKy': maHocKy},
    );
    return StudentGradeTranscriptData.fromJson(data);
  }

  /// Gửi dữ liệu giả lập điểm để backend tính dự phóng GPA.
  Future<StudentGpaProjectionData> projectGpa({
    required String maHocKy,
    required double targetGpa,
  }) async {
    final data = await _apiClient.post(
      '/diem-so/du-phong',
      body: {'maHocKy': maHocKy, 'targetGpa': targetGpa},
    );
    return StudentGpaProjectionData.fromJson(data);
  }

  /// Nhờ AI phân tích điểm và đưa gợi ý cải thiện học tập.
  Future<Map<String, dynamic>> getAiGradeStudyAdvice({
    required String maHocKy,
    required double targetGpa,
    String? focus,
  }) async {
    final data = await _apiClient.post(
      '/diem-so/ai/study-advice',
      body: {
        'maHocKy': maHocKy,
        'targetGpa': targetGpa,
        'focus': _nullableTrim(focus),
      },
    );
    return data as Map<String, dynamic>;
  }

  // ===========================================================================
  // MODULE 18: Trợ lý AI học tập
  // ===========================================================================
  // API chat trực tiếp với assistant học tập của sinh viên.

  /// Gửi tin nhắn đến trợ lý AI học tập và nhận phản hồi.
  Future<AssistantChatReply> chatWithAssistant({
    required String message,
    List<AssistantChatMessage> history = const [],
  }) async {
    final data = await _apiClient.post(
      '/assistant/chat',
      body: {
        'message': message.trim(),
        'lichSu': history
            .map((item) => {'vaiTro': item.role, 'noiDung': item.content})
            .toList(),
      },
    );
    return AssistantChatReply.fromJson(data as Map<String, dynamic>);
  }

  // ===========================================================================
  // MODULE 19: Kanban nhóm học tập
  // ===========================================================================
  // Các API bảng Kanban, task, phân công và bình luận trong nhóm học tập.

  /// Lấy bảng Kanban của nhóm học tập.
  Future<StudentKanbanBoardData> getKanbanBoard(String groupId) async {
    final data = await _apiClient.get(
      '/kanban/groups/${Uri.encodeComponent(groupId)}/board',
    );
    return StudentKanbanBoardData.fromJson(data);
  }

  /// Lấy link phòng chat/liên kết trao đổi của nhóm Kanban.
  Future<String> getKanbanChatLink(String groupId) async {
    final data = await _apiClient.get(
      '/kanban/groups/${Uri.encodeComponent(groupId)}/chat-link',
    );
    final map = data as Map<String, dynamic>;
    return map['linkNhomChat'] as String? ?? '';
  }

  /// Tạo task Kanban mới trong nhóm học tập.
  Future<StudentKanbanTask> createKanbanTask({
    required String groupId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assigneeId,
    bool assignAllMembers = false,
  }) async {
    final data = await _apiClient.post(
      '/kanban/tasks',
      body: {
        'maNhom': groupId,
        'tieuDe': title.trim(),
        'moTa': _nullableTrim(description),
        'hanHoanThanh': dueDate?.toUtc().toIso8601String(),
        'nguoiDuocGiao': _nullableTrim(assigneeId),
        'giaoChoTatCa': assignAllMembers,
      },
    );
    return _kanbanTaskFromMutation(data);
  }

  /// Cập nhật nội dung task Kanban.
  Future<StudentKanbanTask> updateKanbanTask({
    required String taskId,
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    final data = await _apiClient.put(
      '/kanban/tasks/${Uri.encodeComponent(taskId)}',
      body: {
        'tieuDe': title.trim(),
        'moTa': _nullableTrim(description),
        'hanHoanThanh': dueDate?.toUtc().toIso8601String(),
      },
    );
    return _kanbanTaskFromMutation(data);
  }

  /// Cập nhật trạng thái task Kanban.
  Future<StudentKanbanTask> updateKanbanTaskStatus({
    required String taskId,
    required StudentKanbanStatus status,
    int? position,
  }) async {
    final data = await _apiClient.patch(
      '/kanban/tasks/${Uri.encodeComponent(taskId)}/status',
      body: {
        'trangThaiMoi': status.value,
        'viTriMoi': position,
        'nguonThaoTac': 'FALLBACK_UI',
      },
    );
    return _kanbanTaskFromMutation(data);
  }

  /// Gán task Kanban cho thành viên trong nhóm.
  Future<StudentKanbanTask> assignKanbanTask({
    required String taskId,
    String? assigneeId,
  }) async {
    final data = await _apiClient.patch(
      '/kanban/tasks/${Uri.encodeComponent(taskId)}/assignee',
      body: {'nguoiDuocGiao': _nullableTrim(assigneeId)},
    );
    return _kanbanTaskFromMutation(data);
  }

  /// Xóa task Kanban theo id.
  Future<void> deleteKanbanTask(String taskId) async {
    await _apiClient.delete('/kanban/tasks/${Uri.encodeComponent(taskId)}');
  }

  /// Thêm bình luận vào task Kanban.
  Future<StudentKanbanComment> commentKanbanTask({
    required String taskId,
    required String content,
  }) async {
    final data = await _apiClient.post(
      '/kanban/tasks/${Uri.encodeComponent(taskId)}/comments',
      body: {'noiDung': content.trim()},
    );
    final map = data as Map<String, dynamic>;
    final rawComment = map['binhLuan'] ?? data;
    return StudentKanbanComment.fromJson(rawComment as Map<String, dynamic>);
  }

  // ===========================================================================
  // MODULE 20: Nhóm học tập
  // ===========================================================================
  // Các API tạo nhóm, tham gia bằng mã mời, rời nhóm hoặc xóa nhóm.

  /// Lấy danh sách nhóm học tập của sinh viên.
  Future<StudentStudyGroupData> listStudyGroups() async {
    final data = await _apiClient.get('/study-groups');
    return StudentStudyGroupData.fromJson(data);
  }

  /// Tạo nhóm học tập mới.
  Future<StudentStudyGroup> createStudyGroup({
    required String name,
    required String courseId,
    String? chatLink,
  }) async {
    final data = await _apiClient.post(
      '/study-groups',
      body: {
        'tenNhom': name.trim(),
        'maMonHoc': courseId,
        'linkNhomChat': _nullableTrim(chatLink) ?? '',
      },
    );
    return _studyGroupFromMutation(
      data,
      fallbackRole: StudentStudyGroupRole.leader,
    );
  }

  /// Tham gia nhóm học tập bằng mã mời.
  Future<StudentStudyGroup> joinStudyGroup(String inviteCode) async {
    final data = await _apiClient.post(
      '/study-groups/join',
      body: {'maThamGia': inviteCode.trim().toUpperCase()},
    );
    return _studyGroupFromMutation(data);
  }

  /// Rời khỏi một nhóm học tập.
  Future<void> leaveStudyGroup(String groupId) async {
    await _apiClient.post(
      '/study-groups/${Uri.encodeComponent(groupId)}/leave',
    );
  }

  /// Xóa nhóm học tập nếu người dùng có quyền.
  Future<void> deleteStudyGroup({
    required String groupId,
    required String password,
  }) async {
    await _apiClient.delete(
      '/study-groups/${Uri.encodeComponent(groupId)}',
      body: {'matKhauXacNhan': password},
    );
  }

  // ===========================================================================
  // MODULE 21: Helper parse/query cuối file
  // ===========================================================================
  // Gom logic tạo query param và parse response mutation để các hàm API phía
  // trên không phải lặp lại ép kiểu raw JSON.

  /// Tạo query param cho các API list/search và bỏ giá trị null/rỗng.
  Map<String, String>? _query(Map<String, String?> input) {
    final output = Map.fromEntries(
      input.entries
          .where((entry) => entry.value != null && entry.value!.isNotEmpty)
          .map((entry) => MapEntry(entry.key, entry.value!)),
    );
    return output.isEmpty ? null : output;
  }

  /// Chạy API phụ và trả fallback nếu lỗi để màn hình chính vẫn render được.
  Future<T> _fallback<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
    }
  }

  /// Parse response tạo/cập nhật ghi chú; backend có thể bọc item trong key `ghiChu`.
  StudentNote _noteFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawNote = map['ghiChu'];
    return StudentNote.fromJson(rawNote as Map<String, dynamic>);
  }

  /// Parse response tạo/cập nhật môn học; backend có thể bọc item trong key `monHoc`.
  StudentCourseItem _courseFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawCourse = map['monHoc'] ?? data;
    return StudentCourseItem.fromJson(rawCourse as Map<String, dynamic>);
  }

  /// Parse response thao tác Kanban task; backend có thể bọc item trong key `task`.
  StudentKanbanTask _kanbanTaskFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawTask = map['congViec'] ?? data;
    return StudentKanbanTask.fromJson(rawTask as Map<String, dynamic>);
  }

  /// Parse response tạo/tham gia nhóm học tập; backend có thể bọc item trong key `nhom`.
  StudentStudyGroup _studyGroupFromMutation(
    Object? data, {
    StudentStudyGroupRole fallbackRole = StudentStudyGroupRole.member,
  }) {
    final map = data as Map<String, dynamic>;
    final rawGroup = map['nhom'] as Map<String, dynamic>? ?? map;
    final rawMember = map['thanhVien'] as Map<String, dynamic>?;
    return StudentStudyGroup.fromMutation(
      rawGroup,
      memberJson: rawMember,
      fallbackRole: fallbackRole,
    );
  }

  /// Trim chuỗi và đổi chuỗi rỗng thành null trước khi gửi lên backend.
  String? _nullableTrim(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
