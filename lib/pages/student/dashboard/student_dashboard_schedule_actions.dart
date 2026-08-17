part of 'student_dashboard_page.dart';

extension _StudentDashboardScheduleActions on _StudentDashboardPageState {
  Future<void> _importSchedule() async {
    final l10n = context.l10n;
    if (_isImportingSchedule) {
      return;
    }

    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
      withData: true,
    );
    if (!mounted || pickedFile == null || pickedFile.files.isEmpty) {
      return;
    }

    final file = pickedFile.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.importReadError')),
        ),
      );
      return;
    }

    _updateDashboardState(() => _isImportingSchedule = true);
    try {
      final courses = await _fallback(
        () => widget.studentApi.listCourses(tatCa: true),
        StudentCourseData(
          message: l10n.t('student.dashboard.schedule.importNoCourses'),
          selectedSemesterId: null,
          semesters: [],
          items: [],
        ),
      );
      if (courses.semesters.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.tOr(
                'student.dashboard.schedule.importNoSemesters',
                fallbackVi: 'Bạn cần tạo học kỳ trước khi import TKB.',
                fallbackEn: 'Please create a semester before importing TKB.',
              ),
            ),
          ),
        );
        return;
      }

      final schedules = await widget.studentApi.listSchedules();
      if (!mounted) {
        return;
      }
      final semesterChoice = await _showScheduleImportSemesterDialog(
        courses: courses,
        schedules: schedules,
      );
      if (!mounted || semesterChoice == null) {
        return;
      }

      final headers = await widget.studentApi.extractScheduleImportHeaders(
        bytes: bytes,
        fileName: file.name,
      );
      var mapping = headers.suggestedMapping;
      try {
        mapping = await widget.studentApi.suggestScheduleImportMappingWithAi(
          headers: headers.headers,
          sampleRows: headers.rows.take(12).toList(),
        );
      } catch (error, stackTrace) {
        debugPrint('Schedule AI mapping fallback: $error\n$stackTrace');
        mapping = headers.suggestedMapping;
      }

      final preview = await widget.studentApi.previewScheduleImport(
        maHocKy: semesterChoice.semester.id,
        rows: headers.rows,
        mapping: mapping,
        replaceExistingCourseSchedules:
            semesterChoice.replaceExistingCourseSchedules,
      );

      if (!mounted) {
        return;
      }

      final confirmedPreview = await _showImportPreviewDialog(
        headers,
        preview,
        mapping: mapping,
        maHocKy: semesterChoice.semester.id,
        replaceExistingCourseSchedules:
            semesterChoice.replaceExistingCourseSchedules,
      );
      if (!mounted || confirmedPreview == null) {
        return;
      }

      final validItems = confirmedPreview.validItems;
      if (validItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.t('student.dashboard.schedule.importNoValidRows'),
            ),
          ),
        );
        return;
      }

      final result = await widget.studentApi.confirmScheduleImport(
        maHocKy: semesterChoice.semester.id,
        items: validItems,
        replaceExistingCourseSchedules:
            semesterChoice.replaceExistingCourseSchedules,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _refreshAfterScheduleImport();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Schedule import failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.importError')),
        ),
      );
    } finally {
      if (mounted) {
        _updateDashboardState(() => _isImportingSchedule = false);
      }
    }
  }

  Future<_ScheduleImportSemesterChoice?> _showScheduleImportSemesterDialog({
    required StudentCourseData courses,
    required StudentScheduleData schedules,
  }) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;
    var selectedSemester = courses.semesters.firstWhere(
      (semester) => semester.id == courses.selectedSemesterId,
      orElse: () => courses.semesters.first,
    );

    int courseCount(String semesterId) {
      return courses.items
          .where((course) => course.semesterId == semesterId)
          .length;
    }

    int scheduleCount(String semesterId) {
      return schedules.items
          .where((schedule) => schedule.semesterId == semesterId)
          .length;
    }

    return showDialog<_ScheduleImportSemesterChoice>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCourseCount = courseCount(selectedSemester.id);
            final selectedScheduleCount = scheduleCount(selectedSemester.id);
            final hasExistingAcademicData =
                selectedCourseCount > 0 || selectedScheduleCount > 0;

            return AlertDialog(
              backgroundColor: colors.surface,
              title: Text(
                l10n.tOr(
                  'student.dashboard.schedule.importSemesterTitle',
                  fallbackVi: 'Chọn học kỳ import',
                  fallbackEn: 'Choose import semester',
                ),
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedSemester.id,
                    isExpanded: true,
                    dropdownColor: colors.surface,
                    iconEnabledColor: colors.textMuted,
                    iconDisabledColor: colors.textSubtle,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _manualInputDecoration(
                      l10n.tOr(
                        'student.dashboard.schedule.importSemesterLabel',
                        fallbackVi: 'Học kỳ',
                        fallbackEn: 'Semester',
                      ),
                      colors,
                    ),
                    items: courses.semesters
                        .map(
                          (semester) => DropdownMenuItem(
                            value: semester.id,
                            child: Text(
                              semester.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final next = courses.semesters.firstWhere(
                        (semester) => semester.id == value,
                        orElse: () => selectedSemester,
                      );
                      setDialogState(() => selectedSemester = next);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.tOr(
                      'student.dashboard.schedule.importSemesterSummary',
                      fallbackVi:
                          'Đang có {courses} môn học và {schedules} lịch học.',
                      fallbackEn:
                          'Currently has {courses} courses and {schedules} schedules.',
                      arguments: {
                        'courses': selectedCourseCount,
                        'schedules': selectedScheduleCount,
                      },
                    ),
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  if (hasExistingAcademicData) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.tOr(
                        'student.dashboard.schedule.importSemesterHasData',
                        fallbackVi:
                            'Học kỳ {semester} đã có môn học và lịch học cụ thể, bạn có muốn tiếp tục không?',
                        fallbackEn:
                            'Semester {semester} already has courses and detailed schedules. Do you want to continue?',
                        arguments: {'semester': selectedSemester.name},
                      ),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.t('common.cancel'),
                    style: TextStyle(
                      color: colors.primaryStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    _ScheduleImportSemesterChoice(
                      semester: selectedSemester,
                      replaceExistingCourseSchedules: hasExistingAcademicData,
                    ),
                  ),
                  child: Text(
                    hasExistingAcademicData
                        ? l10n.tOr(
                            'student.dashboard.schedule.importSemesterContinueWithReplace',
                            fallbackVi: 'Có, tiếp tục',
                            fallbackEn: 'Yes, continue',
                          )
                        : l10n.tOr(
                            'student.dashboard.schedule.importSemesterContinue',
                            fallbackVi: 'Tiếp tục',
                            fallbackEn: 'Continue',
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<StudentScheduleImportPreviewData?> _showImportPreviewDialog(
    StudentScheduleImportHeadersData headers,
    StudentScheduleImportPreviewData preview, {
    required StudentScheduleImportMapping mapping,
    required String? maHocKy,
    required bool replaceExistingCourseSchedules,
  }) async {
    var currentPreview = preview;
    var currentMapping = mapping;

    while (mounted) {
      final result = await _showImportPreviewDialogStep(
        headers,
        currentPreview,
        mapping: currentMapping,
      );
      if (result is StudentScheduleImportPreviewData) {
        return result;
      }
      if (result is! _ScheduleImportMappingRefresh) {
        return null;
      }

      try {
        currentPreview = await widget.studentApi.previewScheduleImport(
          maHocKy: maHocKy,
          rows: headers.rows,
          mapping: result.mapping,
          replaceExistingCourseSchedules: replaceExistingCourseSchedules,
        );
        currentMapping = result.mapping;
      } on ApiException catch (error) {
        if (!mounted) {
          return null;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error, stackTrace) {
        debugPrint(
          'Schedule manual mapping preview failed: $error\n$stackTrace',
        );
        if (!mounted) {
          return null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.t(
                'student.dashboard.schedule.importMappingPreviewError',
              ),
            ),
          ),
        );
      }
    }

    return null;
  }

  Future<Object?> _showImportPreviewDialogStep(
    StudentScheduleImportHeadersData headers,
    StudentScheduleImportPreviewData preview, {
    required StudentScheduleImportMapping mapping,
  }) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;
    final currentPreview = preview;
    final selectedColumns = _scheduleMappingToSelections(mapping);

    final headerOptions = <String>[];
    for (final header in headers.headers) {
      if (!headerOptions.contains(header)) {
        headerOptions.add(header);
      }
    }
    for (final value in selectedColumns.values) {
      if (value != null && !headerOptions.contains(value)) {
        headerOptions.add(value);
      }
    }
    final invalidSamples = currentPreview.items
        .where((item) => !item.isValid && item.errors.isNotEmpty)
        .take(3)
        .toList();
    final canImport = currentPreview.validItems.isNotEmpty;

    return showDialog<Object?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            l10n.t('student.dashboard.schedule.importTitle'),
            style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${headers.sourceType} • ${headers.rows.length} dòng • ${headers.headers.length} cột',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ImportPreviewStat(
                    label: l10n.t('student.dashboard.schedule.importValidRows'),
                    value: currentPreview.validRows.toString(),
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _ImportPreviewStat(
                    label: l10n.t(
                      'student.dashboard.schedule.importRowsToCheck',
                    ),
                    value: currentPreview.invalidRows.toString(),
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 8),
                  _ImportPreviewStat(
                    label: l10n.t(
                      'student.dashboard.schedule.importAutoCreatedCourses',
                    ),
                    value: currentPreview.autoCreateCourseRows.toString(),
                    color: const Color(0xFF818CF8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t(
                      'student.dashboard.schedule.importMappedColumnsTitle',
                    ),
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t(
                      'student.dashboard.schedule.importMappedColumnsSubtitle',
                    ),
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  for (final field in _scheduleImportMappingFields(l10n))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ImportMappingSelector(
                        field: field,
                        headers: headerOptions,
                        selectedColumn: selectedColumns[field.key],
                        colors: colors,
                        onChanged: (value) {
                          selectedColumns[field.key] = value;
                        },
                      ),
                    ),
                  if (invalidSamples.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('student.dashboard.schedule.importSampleErrors'),
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...invalidSamples.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l10n.t(
                            'student.dashboard.schedule.importRowError',
                            arguments: {
                              'row': item.rowIndex,
                              'errors': item.errors.join(', '),
                            },
                          ),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.t('common.cancel'),
                style: TextStyle(
                  color: colors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                _ScheduleImportMappingRefresh(
                  _scheduleMappingFromSelections(selectedColumns),
                ),
              ),
              child: Text(
                l10n.t('student.dashboard.schedule.importMappingRefresh'),
                style: TextStyle(
                  color: colors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryStrong,
                disabledBackgroundColor: colors.surfaceAlt,
                foregroundColor: colors.onPrimary,
                disabledForegroundColor: colors.textMuted,
              ),
              onPressed: canImport
                  ? () {
                      final selectedMapping = _scheduleMappingFromSelections(
                        selectedColumns,
                      );
                      if (!_scheduleMappingsEqual(mapping, selectedMapping)) {
                        Navigator.of(
                          context,
                        ).pop(_ScheduleImportMappingRefresh(selectedMapping));
                        return;
                      }
                      Navigator.of(context).pop(currentPreview);
                    }
                  : null,
              child: Text(
                l10n.t(
                  'student.dashboard.schedule.importDialogImport',
                  arguments: {'count': currentPreview.validItems.length},
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addScheduleManually() async {
    final l10n = context.l10n;
    if (_isSavingManualSchedule) {
      return;
    }

    try {
      final courses = await widget.studentApi.listCourses();
      if (!mounted) {
        return;
      }

      if (courses.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('student.dashboard.schedule.manualNoCourses')),
          ),
        );
        return;
      }

      final input = await _showManualScheduleDialog(courses.items);
      if (!mounted || input == null) {
        return;
      }

      _updateDashboardState(() => _isSavingManualSchedule = true);
      await widget.studentApi.createSchedule(
        courseId: input.courseId,
        dayOfWeek: input.dayOfWeek,
        startPeriod: input.startPeriod,
        periodCount: input.periodCount,
        room: input.room,
        startDate: input.startDate,
        endDate: input.endDate,
      );
      await _refreshSchedule();
      await _refreshHome();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.manualSuccess')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.manualError')),
        ),
      );
    } finally {
      if (mounted) {
        _updateDashboardState(() => _isSavingManualSchedule = false);
      }
    }
  }

  Future<void> _editSchedule(StudentScheduleItem item) async {
    final l10n = context.l10n;
    if (_isSavingManualSchedule) {
      return;
    }

    try {
      final courses = await widget.studentApi.listCourses();
      if (!mounted) {
        return;
      }

      if (courses.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('student.dashboard.schedule.manualNoCourses')),
          ),
        );
        return;
      }

      final input = await _showManualScheduleDialog(
        courses.items,
        initial: item,
      );
      if (!mounted || input == null) {
        return;
      }

      _updateDashboardState(() => _isSavingManualSchedule = true);
      await widget.studentApi.updateSchedule(
        scheduleId: item.id,
        courseId: input.courseId,
        dayOfWeek: input.dayOfWeek,
        startPeriod: input.startPeriod,
        periodCount: input.periodCount,
        room: input.room,
        startDate: input.startDate,
        endDate: input.endDate,
      );
      unawaited(_refreshSchedule());
      unawaited(_refreshHome());

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.editSuccess')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('student.dashboard.schedule.editError'))),
      );
    } finally {
      if (mounted) {
        _updateDashboardState(() => _isSavingManualSchedule = false);
      }
    }
  }

  Future<void> _deleteSchedule(StudentScheduleItem item) async {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            l10n.t('student.dashboard.schedule.deleteTitle'),
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.t(
              'student.dashboard.schedule.deleteConfirm',
              arguments: {'course': item.courseName},
            ),
            style: TextStyle(color: colors.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('common.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF809F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.t('student.dashboard.schedule.deleteConfirmAction'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.studentApi.deleteSchedule(scheduleId: item.id);
      await _refreshSchedule();
      await _refreshHome();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.deleteSuccess')),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('student.dashboard.schedule.deleteError')),
        ),
      );
    }
  }

  Future<_ManualScheduleInput?> _showManualScheduleDialog(
    List<StudentCourseItem> courses, {
    StudentScheduleItem? initial,
  }) {
    final l10n = context.l10n;
    final colors = _studentThemeController.colors;

    return showDialog<_ManualScheduleInput>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => _ManualScheduleDialog(
        courses: courses,
        initial: initial,
        l10n: l10n,
        colors: colors,
      ),
    );
  }
}
