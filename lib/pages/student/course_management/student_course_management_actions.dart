part of 'student_course_management_page.dart';

extension _StudentCourseManagementActions on _StudentCourseManagementPageState {
  Future<void> _openSemesterModal({StudentSemester? semester}) async {
    if (_isSavingSemester) {
      return;
    }

    final isEditing = semester != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: _semesterNumberFromName(semester?.name),
    );
    final startYearController = TextEditingController(
      text: _yearFromSemesterValue(semester?.startDate),
    );
    final endYearController = TextEditingController(
      text: _yearFromSemesterValue(semester?.endDate),
    );
    final colors = StudentThemeScope.colorsOf(context);

    try {
      final draft = await showDialog<_SemesterDraft>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: colors.surface,
            title: Text(
              isEditing ? 'Sửa học kỳ' : 'Thêm học kỳ',
              style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: colors.text),
                      decoration: _semesterInputDecoration('Học kỳ', colors),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final semesterNumber = int.tryParse(
                          (value ?? '').trim(),
                        );
                        if (semesterNumber == null ||
                            semesterNumber < 1 ||
                            semesterNumber > 3) {
                          return 'Học kỳ chỉ được nhập 1, 2 hoặc 3';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: startYearController,
                      style: TextStyle(color: colors.text),
                      decoration: _semesterInputDecoration(
                        'Năm bắt đầu',
                        colors,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final year = int.tryParse((value ?? '').trim());
                        if (year == null || year < 1900 || year > 2100) {
                          return 'Vui lòng nhập năm bắt đầu hợp lệ';
                        }
                        final endYear = int.tryParse(
                          endYearController.text.trim(),
                        );
                        if (endYear != null && endYear != year + 1) {
                          return 'Năm kết thúc phải bằng năm bắt đầu + 1';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: endYearController,
                      style: TextStyle(color: colors.text),
                      decoration: _semesterInputDecoration(
                        'Năm kết thúc',
                        colors,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final year = int.tryParse((value ?? '').trim());
                        if (year == null || year < 1900 || year > 2100) {
                          return 'Vui lòng nhập năm kết thúc hợp lệ';
                        }
                        final startYear = int.tryParse(
                          startYearController.text.trim(),
                        );
                        if (startYear != null && year != startYear + 1) {
                          return 'Năm kết thúc phải bằng năm bắt đầu + 1';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() != true) {
                    return;
                  }
                  FocusManager.instance.primaryFocus?.unfocus();
                  final semesterNumber = int.parse(nameController.text.trim());
                  final draft = _SemesterDraft(
                    name: 'Học kì $semesterNumber',
                    startYear: startYearController.text.trim(),
                    endYear: endYearController.text.trim(),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                  if (context.mounted) {
                    Navigator.pop(context, draft);
                  }
                },
                child: Text(isEditing ? 'Lưu thay đổi' : 'Lưu học kỳ'),
              ),
            ],
          );
        },
      );

      if (!mounted || draft == null) {
        return;
      }

      _updateCourseState(() => _isSavingSemester = true);
      try {
        final startDate = draft.startYear.isEmpty
            ? null
            : '${draft.startYear.trim()}-01-01';
        final endDate = draft.endYear.isEmpty
            ? null
            : '${draft.endYear.trim()}-12-31';
        if (isEditing) {
          await widget.studentApi.updateSemester(
            semesterId: semester.id,
            name: draft.name,
            startDate: startDate,
            endDate: endDate,
          );
          await _afterMutation('Cập nhật học kỳ thành công.');
        } else {
          final createdSemester = await widget.studentApi.createSemester(
            name: draft.name,
            startDate: startDate,
            endDate: endDate,
          );
          _selectedSemesterId = createdSemester.id;
          await _afterMutation('Tạo học kỳ thành công.');
        }
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } finally {
        if (mounted) {
          _updateCourseState(() => _isSavingSemester = false);
        }
      }
    } finally {
      nameController.dispose();
      startYearController.dispose();
      endYearController.dispose();
    }
  }

  Future<void> _deleteSemester(
    StudentSemester semester, {
    bool force = false,
  }) async {
    if (!force) {
      final confirmed = await _confirmDeleteSemester(
        'Bạn có chắc muốn xóa học kỳ "${semester.name}"?',
      );
      if (confirmed != true) {
        return;
      }
    }

    _updateCourseState(() => _isSavingSemester = true);
    try {
      await widget.studentApi.deleteSemester(semester.id, force: force);
      if (mounted && semester.id == _selectedSemesterId) {
        _updateCourseState(() => _selectedSemesterId = null);
      }
      await _afterMutation('Xóa học kỳ thành công.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final details = error.details;
      final canForceDelete =
          details is Map<String, dynamic> &&
          details['canForceDelete'] == true &&
          !force;

      if (canForceDelete) {
        final confirmed = await _confirmForceDelete(
          details['messageForUser'] as String? ?? error.message,
        );
        if (confirmed == true && mounted) {
          await _deleteSemester(semester, force: true);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        _updateCourseState(() => _isSavingSemester = false);
      }
    }
  }

  Future<bool?> _confirmDeleteSemester(String message) {
    final colors = StudentThemeScope.colorsOf(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Xóa học kỳ?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCourse(
    _ManagedCourse? course,
    _CourseDraft draft, {
    bool showErrorSnack = true,
  }) async {
    final semesterId = course?.semesterId ?? _selectedSemesterId;
    if (semesterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần có học kỳ trước khi thêm học phần.'),
        ),
      );
      return;
    }

    _updateCourseState(() => _isSaving = true);
    try {
      final savedCourse = course == null
          ? await widget.studentApi.createCourse(
              semesterId: semesterId,
              name: draft.name,
              credits: draft.credits,
              code: draft.code,
            )
          : await widget.studentApi.updateCourse(
              courseId: course.id,
              semesterId: semesterId,
              name: draft.name,
              credits: draft.credits,
              code: draft.code,
            );

      await widget.studentApi.configureGradeWeights(
        courseId: savedCourse.id,
        components: [
          StudentGradeWeightInput(
            name: course?.attendanceComponentName ?? 'Chuyên cần',
            weight: draft.attendanceWeight,
          ),
          StudentGradeWeightInput(
            name: course?.midtermComponentName ?? 'Giữa kỳ',
            weight: draft.midtermWeight,
          ),
          StudentGradeWeightInput(
            name: course?.finalComponentName ?? 'Cuối kỳ',
            weight: draft.finalWeight,
          ),
        ],
      );

      await _afterMutation(
        course == null
            ? 'Thêm học phần thành công.'
            : 'Cập nhật học phần thành công.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (showErrorSnack) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      rethrow;
    } finally {
      if (mounted) {
        _updateCourseState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteCourse(
    _ManagedCourse course, {
    bool force = false,
  }) async {
    _updateCourseState(() => _isSaving = true);
    try {
      await widget.studentApi.deleteCourse(course.id, force: force);
      await _afterMutation('Xóa học phần thành công.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final details = error.details;
      final canForceDelete =
          details is Map<String, dynamic> &&
          details['canForceDelete'] == true &&
          !force;

      if (canForceDelete) {
        final confirmed = await _confirmForceDelete(
          details['messageForUser'] as String? ?? error.message,
        );
        if (confirmed == true && mounted) {
          await _deleteCourse(course, force: true);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        _updateCourseState(() => _isSaving = false);
      }
    }
  }

  Future<void> _afterMutation(String message) async {
    await _reload(showLoader: false);
    await widget.onChanged?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmForceDelete(String message) {
    final colors = StudentThemeScope.colorsOf(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Xóa học phần?',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: TextStyle(color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Vẫn xóa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdviceDialog() {
    final fallbackAdvice =
        'Để duy trì GPA tốt và đạt mục tiêu, hãy tập trung rèn luyện chuyên cần và gỡ điểm các môn học trọng số thi cuối kỳ cao nhé.';
    final colors = StudentThemeScope.colorsOf(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Trung tâm tư vấn học tập',
          style: TextStyle(color: colors.text),
        ),
        content: Text(
          _projectionAdvice ?? fallbackAdvice,
          style: TextStyle(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: TextStyle(color: colors.primaryStrong)),
          ),
        ],
      ),
    );
  }
}
