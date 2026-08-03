import '../../../models/auth_models.dart';
import '../../../models/student_assistant_models.dart';
import '../../../models/student_course_models.dart';
import '../../../models/student_deadline_models.dart';
import '../../../models/student_exam_models.dart';
import '../../../models/student_flashcard_models.dart';
import '../../../models/student_grade_models.dart';
import '../../../models/student_home_models.dart';
import '../../../models/student_kanban_models.dart';
import '../../../models/student_note_models.dart';
import '../../../models/student_notification_models.dart';
import '../../../models/student_schedule_models.dart';
import '../../../models/student_study_group_models.dart';
import '../../../models/student_storage_models.dart';
import '../api_client.dart';

class StudentApiService {
  StudentApiService(this._apiClient);

  final ApiClient _apiClient;

  void setAcceptLanguageCode(String? languageCode) {
    _apiClient.setAcceptLanguageCode(languageCode);
  }

  Future<PublicUser> getCurrentUser() async {
    final data = await _apiClient.get('/users/me');
    return PublicUser.fromJson(data as Map<String, dynamic>);
  }

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

  Future<void> revokeCurrentUserSession(String sessionId) async {
    await _apiClient.delete('/auth/sessions/${Uri.encodeComponent(sessionId)}');
  }

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

    return StudentHomeData.fromBackend(
      user: user,
      courseData: courses,
      scheduleData: schedules,
      gradeData: grades,
    );
  }

  Map<String, Object?> _withoutNulls(Map<String, Object?> input) {
    final result = <String, Object?>{};
    for (final entry in input.entries) {
      if (entry.value != null) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Future<StudentScheduleData> listSchedules({String? maMonHoc}) async {
    final data = await _apiClient.get(
      '/schedules',
      query: maMonHoc == null ? null : {'maMonHoc': maMonHoc},
    );
    return StudentScheduleData.fromJson(data);
  }

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

  Future<StudentScheduleItem> updateSchedule({
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
    final data = await _apiClient.put(
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
    return _scheduleFromMutation(data);
  }

  Future<void> deleteSchedule({required String scheduleId}) async {
    await _apiClient.delete('/schedules/${Uri.encodeComponent(scheduleId)}');
  }

  StudentScheduleItem _scheduleFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawSchedule = map['lichHoc'] ?? data;
    return StudentScheduleItem.fromJson(rawSchedule as Map<String, dynamic>);
  }

  Future<StudentExamData> listExams({String? maMonHoc}) async {
    final data = await _apiClient.get(
      '/exams',
      query: maMonHoc == null ? null : {'maMonHoc': maMonHoc},
    );
    return StudentExamData.fromJson(data);
  }

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

  Future<void> deleteExam({required String examId}) async {
    await _apiClient.delete('/exams/${Uri.encodeComponent(examId)}');
  }

  StudentExamItem _examFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawExam = map['lichThi'] ?? data;
    return StudentExamItem.fromJson(rawExam as Map<String, dynamic>);
  }

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

  Future<StudentExamImportPreviewData> previewExamImport({
    required List<Map<String, Object?>> rows,
    required StudentExamImportMapping mapping,
    String? maHocKy,
  }) async {
    final data = await _apiClient.post(
      '/exams/import/preview',
      body: {
        'maHocKy': maHocKy,
        'rows': rows,
        'mapping': mapping.toJson(),
      },
    );
    return StudentExamImportPreviewData.fromJson(data as Map<String, dynamic>);
  }

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

  Future<StudentCourseData> listCourses({String? maHocKy, bool tatCa = false}) async {
    final data = await _apiClient.get(
      '/courses',
      query: tatCa
          ? {'tatCa': 'true'}
          : (maHocKy == null ? null : {'maHocKy': maHocKy}),
    );
    return StudentCourseData.fromJson(data);
  }

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

  Future<void> deleteSemester(String semesterId, {bool force = false}) async {
    await _apiClient.delete(
      '/courses/semesters/${Uri.encodeComponent(semesterId)}',
      body: {'force': force},
    );
  }

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

  Future<void> deleteCourse(String courseId, {bool force = false}) async {
    await _apiClient.delete(
      '/courses/${Uri.encodeComponent(courseId)}',
      body: {'force': force},
    );
  }

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

  Future<StudentNote> getNoteDetail(String noteId) async {
    final data = await _apiClient.get('/notes/${Uri.encodeComponent(noteId)}');
    return StudentNote.fromJson(data as Map<String, dynamic>);
  }

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

  Future<void> deleteNote(String noteId) async {
    await _apiClient.delete('/notes/${Uri.encodeComponent(noteId)}');
  }

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

  Future<void> markNotificationRead(String notificationId) async {
    await _apiClient.patch(
      '/notifications/${Uri.encodeComponent(notificationId)}/read',
    );
  }

  Future<void> hideNotification(String notificationId) async {
    await _apiClient.patch(
      '/notifications/${Uri.encodeComponent(notificationId)}/hide',
    );
  }

  Future<void> markAllNotificationsRead() async {
    await _apiClient.patch('/notifications/read-all');
  }

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

  Future<void> deleteStorageDocument(String documentId) async {
    await _apiClient.delete(
      '/student/documents/${Uri.encodeComponent(documentId)}',
    );
  }

  Future<void> reportDocument({
    required String documentId,
    required String reason,
  }) async {
    await _apiClient.post(
      '/student/documents/${Uri.encodeComponent(documentId)}/report',
      body: {'lyDo': reason.trim()},
    );
  }

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

  Future<StudentFlashcardDeckData> listFlashcardDecks({
    String? courseId,
  }) async {
    final data = await _apiClient.get(
      '/flashcard-decks',
      query: _query({'maMonHoc': courseId}),
    );
    return StudentFlashcardDeckData.fromJson(data);
  }

  Future<StudentFlashcardStatisticsData> getFlashcardStatistics() async {
    final data = await _apiClient.get('/flashcards/statistics');
    return StudentFlashcardStatisticsData.fromJson(data);
  }

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

  Future<void> deleteFlashcardDeck(String deckId) async {
    await _apiClient.delete(
      '/flashcard-decks/${Uri.encodeComponent(deckId)}',
    );
  }

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

  Future<void> deleteFlashcard(String cardId) async {
    await _apiClient.delete('/flashcards/${Uri.encodeComponent(cardId)}');
  }

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

  Future<StudentFlashcardReviewData> listAllFlashcards(String deckId) async {
    return startFlashcardReview(deckId, hocLai: true);
  }

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

  Future<StudentGradeTranscriptData> getGradeTranscript({
    String? maHocKy,
  }) async {
    final data = await _apiClient.get(
      '/diem-so/bang-diem',
      query: maHocKy == null ? null : {'maHocKy': maHocKy},
    );
    return StudentGradeTranscriptData.fromJson(data);
  }

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

  Future<StudentKanbanBoardData> getKanbanBoard(String groupId) async {
    final data = await _apiClient.get(
      '/kanban/groups/${Uri.encodeComponent(groupId)}/board',
    );
    return StudentKanbanBoardData.fromJson(data);
  }

  Future<String> getKanbanChatLink(String groupId) async {
    final data = await _apiClient.get(
      '/kanban/groups/${Uri.encodeComponent(groupId)}/chat-link',
    );
    final map = data as Map<String, dynamic>;
    return map['linkNhomChat'] as String? ?? '';
  }

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

  Future<void> deleteKanbanTask(String taskId) async {
    await _apiClient.delete('/kanban/tasks/${Uri.encodeComponent(taskId)}');
  }

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

  Future<StudentStudyGroupData> listStudyGroups() async {
    final data = await _apiClient.get('/study-groups');
    return StudentStudyGroupData.fromJson(data);
  }

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

  Future<StudentStudyGroup> joinStudyGroup(String inviteCode) async {
    final data = await _apiClient.post(
      '/study-groups/join',
      body: {'maThamGia': inviteCode.trim().toUpperCase()},
    );
    return _studyGroupFromMutation(data);
  }

  Future<void> leaveStudyGroup(String groupId) async {
    await _apiClient.post(
      '/study-groups/${Uri.encodeComponent(groupId)}/leave',
    );
  }

  Future<void> deleteStudyGroup({
    required String groupId,
    required String password,
  }) async {
    await _apiClient.delete(
      '/study-groups/${Uri.encodeComponent(groupId)}',
      body: {'matKhauXacNhan': password},
    );
  }

  Map<String, String>? _query(Map<String, String?> input) {
    final output = Map.fromEntries(
      input.entries
          .where((entry) => entry.value != null && entry.value!.isNotEmpty)
          .map((entry) => MapEntry(entry.key, entry.value!)),
    );
    return output.isEmpty ? null : output;
  }

  Future<T> _fallback<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
    }
  }

  StudentNote _noteFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawNote = map['ghiChu'];
    return StudentNote.fromJson(rawNote as Map<String, dynamic>);
  }

  StudentCourseItem _courseFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawCourse = map['monHoc'] ?? data;
    return StudentCourseItem.fromJson(rawCourse as Map<String, dynamic>);
  }

  StudentKanbanTask _kanbanTaskFromMutation(Object? data) {
    final map = data as Map<String, dynamic>;
    final rawTask = map['congViec'] ?? data;
    return StudentKanbanTask.fromJson(rawTask as Map<String, dynamic>);
  }

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

  String? _nullableTrim(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
