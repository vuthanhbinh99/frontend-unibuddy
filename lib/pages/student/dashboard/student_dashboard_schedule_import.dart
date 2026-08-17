part of 'student_dashboard_page.dart';

class _ManualScheduleInput {
  const _ManualScheduleInput({
    required this.courseId,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.periodCount,
    required this.room,
    required this.startDate,
    required this.endDate,
  });

  final String courseId;
  final int dayOfWeek;
  final int startPeriod;
  final int periodCount;
  final String room;
  final String? startDate;
  final String? endDate;
}

class _ManualScheduleDialog extends StatefulWidget {
  const _ManualScheduleDialog({
    required this.courses,
    required this.l10n,
    required this.colors,
    this.initial,
  });

  final List<StudentCourseItem> courses;
  final StudentScheduleItem? initial;
  final AppLocalizationController l10n;
  final StudentThemeColors colors;

  @override
  State<_ManualScheduleDialog> createState() => _ManualScheduleDialogState();
}

class _ManualScheduleDialogState extends State<_ManualScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late String _selectedCourseId;
  late int _selectedDay;
  late int _selectedStartPeriod;
  late int _selectedPeriodCount;

  bool get _isEditing => widget.initial != null;

  bool get _periodIsValid =>
      _selectedStartPeriod + _selectedPeriodCount - 1 <= 12;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final hasInitialCourse =
        initial != null &&
        widget.courses.any((course) => course.id == initial.courseId);
    _selectedCourseId = hasInitialCourse
        ? initial.courseId
        : widget.courses.first.id;
    _selectedDay = initial?.dayOfWeek ?? 2;
    _selectedStartPeriod = initial?.startPeriod ?? 1;
    _selectedPeriodCount = initial?.periodCount ?? 3;
    _roomController = TextEditingController(text: initial?.room ?? '');
    _startDateController = TextEditingController(
      text: _dateInputValue(initial?.startDate),
    );
    _endDateController = TextEditingController(
      text: _dateInputValue(initial?.endDate),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _close([_ManualScheduleInput? input]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(input);
    }
  }

  void _submit() {
    if (!_periodIsValid || _formKey.currentState?.validate() != true) {
      return;
    }

    unawaited(
      _close(
        _ManualScheduleInput(
          courseId: _selectedCourseId,
          dayOfWeek: _selectedDay,
          startPeriod: _selectedStartPeriod,
          periodCount: _selectedPeriodCount,
          room: _roomController.text,
          startDate: _normalizedDateOrNull(_startDateController.text),
          endDate: _normalizedDateOrNull(_endDateController.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final colors = widget.colors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
            color: colors.primaryStrong,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.t(
              _isEditing
                  ? 'student.dashboard.schedule.editTitle'
                  : 'student.dashboard.schedule.manualTitle',
            ),
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                dropdownColor: colors.surface,
                iconEnabledColor: colors.textMuted,
                iconDisabledColor: colors.textSubtle,
                isExpanded: true,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _manualInputDecoration(
                  l10n.t('student.dashboard.schedule.manualCourse'),
                  colors,
                ),
                items: widget.courses.map((course) {
                  return DropdownMenuItem(
                    value: course.id,
                    child: Text(
                      course.code == null
                          ? course.name
                          : '${course.code} - ${course.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCourseId = value);
                  }
                },
                validator: (value) => value == null
                    ? l10n.t('student.dashboard.schedule.manualChooseCourse')
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedDay,
                dropdownColor: colors.surface,
                iconEnabledColor: colors.textMuted,
                iconDisabledColor: colors.textSubtle,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _manualInputDecoration(
                  l10n.t('student.dashboard.schedule.manualDay'),
                  colors,
                ),
                items: _manualDayOptions(l10n).map((day) {
                  return DropdownMenuItem(
                    value: day.value,
                    child: Text(day.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedDay = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedStartPeriod,
                      dropdownColor: colors.surface,
                      iconEnabledColor: colors.textMuted,
                      iconDisabledColor: colors.textSubtle,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _manualInputDecoration(
                        l10n.t('student.dashboard.schedule.manualStartPeriod'),
                        colors,
                      ),
                      items: List.generate(12, (index) => index + 1)
                          .map(
                            (period) => DropdownMenuItem(
                              value: period,
                              child: Text('$period'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStartPeriod = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedPeriodCount,
                      dropdownColor: colors.surface,
                      iconEnabledColor: colors.textMuted,
                      iconDisabledColor: colors.textSubtle,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _manualInputDecoration(
                        l10n.t('student.dashboard.schedule.manualPeriodCount'),
                        colors,
                      ),
                      items: List.generate(12, (index) => index + 1)
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPeriodCount = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (!_periodIsValid) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.t('student.dashboard.schedule.manualPeriodOverflow'),
                    style: TextStyle(color: colors.danger, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      style: TextStyle(color: colors.text),
                      keyboardType: TextInputType.datetime,
                      decoration: _manualInputDecoration(
                        'Ngày bắt đầu',
                        colors,
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (value) =>
                          _manualScheduleDateValidator(value, 'Ngày bắt đầu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      style: TextStyle(color: colors.text),
                      keyboardType: TextInputType.datetime,
                      decoration: _manualInputDecoration(
                        'Ngày kết thúc',
                        colors,
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (value) {
                        final message = _manualScheduleDateValidator(
                          value,
                          'Ngày kết thúc',
                        );
                        if (message != null) {
                          return message;
                        }
                        final start = _normalizedDateOrNull(
                          _startDateController.text,
                        );
                        final end = _normalizedDateOrNull(value);
                        if (start != null &&
                            end != null &&
                            start.compareTo(end) > 0) {
                          return 'Ngày kết thúc phải sau ngày bắt đầu';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomController,
                style: TextStyle(color: colors.text),
                decoration: _manualInputDecoration(
                  l10n.t('student.dashboard.schedule.manualRoom'),
                  colors,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(_close()),
          child: Text(
            l10n.t('common.cancel'),
            style: TextStyle(
              color: colors.primaryStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryStrong,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _periodIsValid ? _submit : null,
          child: Text(
            l10n.t(
              _isEditing
                  ? 'student.dashboard.schedule.editSave'
                  : 'student.dashboard.schedule.manualSave',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ScheduleImportSemesterChoice {
  const _ScheduleImportSemesterChoice({
    required this.semester,
    required this.replaceExistingCourseSchedules,
  });

  final StudentSemester semester;
  final bool replaceExistingCourseSchedules;
}

class _ManualDayOption {
  const _ManualDayOption({required this.value, required this.label});

  final int value;
  final String label;
}

class _ImportMappingField {
  const _ImportMappingField({required this.key, required this.label});

  final String key;
  final String label;
}

class _ScheduleImportMappingRefresh {
  const _ScheduleImportMappingRefresh(this.mapping);

  final StudentScheduleImportMapping mapping;
}

const _unmappedScheduleColumnValue = '__unmapped__';

List<_ImportMappingField> _scheduleImportMappingFields(
  AppLocalizationController l10n,
) {
  return [
    _ImportMappingField(
      key: 'maMonHoc',
      label: l10n.t('student.dashboard.schedule.importMappingMaMonHoc'),
    ),
    _ImportMappingField(
      key: 'maMon',
      label: l10n.t('student.dashboard.schedule.importMappingMaMon'),
    ),
    _ImportMappingField(
      key: 'tenMon',
      label: l10n.t('student.dashboard.schedule.importMappingTenMon'),
    ),
    _ImportMappingField(
      key: 'thu',
      label: l10n.t('student.dashboard.schedule.importMappingThu'),
    ),
    _ImportMappingField(
      key: 'tietBatDau',
      label: l10n.t('student.dashboard.schedule.importMappingTietBatDau'),
    ),
    _ImportMappingField(
      key: 'soTiet',
      label: l10n.t('student.dashboard.schedule.importMappingSoTiet'),
    ),
    _ImportMappingField(
      key: 'soTinChi',
      label: l10n.t('student.dashboard.schedule.importMappingSoTinChi'),
    ),
    _ImportMappingField(
      key: 'phongHoc',
      label: l10n.t('student.dashboard.schedule.importMappingPhongHoc'),
    ),
    _ImportMappingField(
      key: 'ngayBatDau',
      label: l10n.t('student.dashboard.schedule.importMappingNgayBatDau'),
    ),
    _ImportMappingField(
      key: 'ngayKetThuc',
      label: l10n.t('student.dashboard.schedule.importMappingNgayKetThuc'),
    ),
  ];
}

Map<String, String?> _scheduleMappingToSelections(
  StudentScheduleImportMapping mapping,
) {
  return {
    'maMonHoc': mapping.maMonHoc,
    'maMon': mapping.maMon,
    'tenMon': mapping.tenMon,
    'thu': mapping.thu,
    'tietBatDau': mapping.tietBatDau,
    'soTiet': mapping.soTiet,
    'soTinChi': mapping.soTinChi,
    'phongHoc': mapping.phongHoc,
    'ngayBatDau': mapping.ngayBatDau,
    'ngayKetThuc': mapping.ngayKetThuc,
  };
}

StudentScheduleImportMapping _scheduleMappingFromSelections(
  Map<String, String?> selections,
) {
  return StudentScheduleImportMapping(
    maMonHoc: selections['maMonHoc'],
    maMon: selections['maMon'],
    tenMon: selections['tenMon'],
    thu: selections['thu'],
    tietBatDau: selections['tietBatDau'],
    soTiet: selections['soTiet'],
    soTinChi: selections['soTinChi'],
    phongHoc: selections['phongHoc'],
    ngayBatDau: selections['ngayBatDau'],
    ngayKetThuc: selections['ngayKetThuc'],
  );
}

bool _scheduleMappingsEqual(
  StudentScheduleImportMapping first,
  StudentScheduleImportMapping second,
) {
  return first.toJson().toString() == second.toJson().toString();
}

List<_ManualDayOption> _manualDayOptions(AppLocalizationController l10n) {
  return [
    _ManualDayOption(
      value: 2,
      label: l10n.t('student.dashboard.schedule.day.mon'),
    ),
    _ManualDayOption(
      value: 3,
      label: l10n.t('student.dashboard.schedule.day.tue'),
    ),
    _ManualDayOption(
      value: 4,
      label: l10n.t('student.dashboard.schedule.day.wed'),
    ),
    _ManualDayOption(
      value: 5,
      label: l10n.t('student.dashboard.schedule.day.thu'),
    ),
    _ManualDayOption(
      value: 6,
      label: l10n.t('student.dashboard.schedule.day.fri'),
    ),
    _ManualDayOption(
      value: 7,
      label: l10n.t('student.dashboard.schedule.day.sat'),
    ),
    _ManualDayOption(
      value: 8,
      label: l10n.t('student.dashboard.schedule.day.sun'),
    ),
  ];
}

String _dateInputValue(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length >= 10) {
    return trimmed.substring(0, 10);
  }
  return trimmed;
}

String? _normalizedDateOrNull(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) {
    return null;
  }

  final year = parsed.year.toString().padLeft(4, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _manualScheduleDateValidator(String? value, String label) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (_normalizedDateOrNull(trimmed) == null) {
    return '$label phải đúng định dạng YYYY-MM-DD';
  }
  return null;
}

InputDecoration _manualInputDecoration(
  String label,
  StudentThemeColors colors, {
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    labelStyle: TextStyle(
      color: colors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: TextStyle(
      color: colors.primaryStrong,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: TextStyle(
      color: colors.isLight ? colors.textMuted : colors.textSubtle,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: colors.surfaceAlt,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.primaryStrong, width: 1.4),
    ),
  );
}

class _ImportMappingSelector extends StatelessWidget {
  const _ImportMappingSelector({
    required this.field,
    required this.headers,
    required this.selectedColumn,
    required this.colors,
    required this.onChanged,
  });

  final _ImportMappingField field;
  final List<String> headers;
  final String? selectedColumn;
  final StudentThemeColors colors;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedValue = selectedColumn ?? _unmappedScheduleColumnValue;
    return DropdownButtonFormField<String>(
      key: ValueKey('${field.key}-$selectedValue'),
      initialValue: selectedValue,
      isExpanded: true,
      dropdownColor: colors.surface,
      iconEnabledColor: colors.textMuted,
      iconDisabledColor: colors.textSubtle,
      style: TextStyle(
        color: colors.text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: field.label,
        labelStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: colors.primaryStrong,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: colors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primaryStrong, width: 1.3),
        ),
      ),
      items: [
        DropdownMenuItem(
          value: _unmappedScheduleColumnValue,
          child: Text(
            l10n.t('student.dashboard.schedule.importMappingUnmapped'),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textMuted),
          ),
        ),
        for (final header in headers)
          DropdownMenuItem(
            value: header,
            child: Text(
              header,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.text),
            ),
          ),
      ],
      onChanged: (value) {
        onChanged(value == _unmappedScheduleColumnValue ? null : value);
      },
    );
  }
}

class _ImportPreviewStat extends StatelessWidget {
  const _ImportPreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StudentBottomBar extends StatelessWidget {
  const _StudentBottomBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = StudentThemeScope.colorsOf(context);
    final menuItems = [
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.home'),
        Icons.home_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.schedule'),
        Icons.calendar_today_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.catalog'),
        Icons.grid_view_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.notifications'),
        Icons.notifications_rounded,
      ),
      _StudentMenuItem(
        l10n.t('student.dashboard.menu.settings'),
        Icons.settings_rounded,
      ),
    ];

    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bottomBar,
        border: Border(top: BorderSide(color: colors.border, width: 1.5)),
        boxShadow: [
          if (colors.isLight)
            BoxShadow(
              color: colors.shadow,
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var index = 0; index < menuItems.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: currentIndex == index
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.primaryStrong,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primaryStrong.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              menuItems[index].icon,
                              size: 20,
                              color: colors.onPrimary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              menuItems[index].label,
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            menuItems[index].icon,
                            size: 20,
                            color: colors.textSubtle,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            menuItems[index].label,
                            style: TextStyle(
                              color: colors.textSubtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentMenuItem {
  const _StudentMenuItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ScheduleBundle {
  const _ScheduleBundle({required this.schedules, required this.deadlines});

  final StudentScheduleData schedules;
  final StudentDeadlineData deadlines;

  factory _ScheduleBundle.empty() {
    return _ScheduleBundle(
      schedules: const StudentScheduleData(
        message: 'Đang tải lịch học...',
        warning: null,
        items: [],
      ),
      deadlines: StudentDeadlineData.fromJson(const <dynamic>[]),
    );
  }
}

class _CatalogBundle {
  const _CatalogBundle({required this.courses, required this.grades});

  final StudentCourseData courses;
  final StudentGradeTranscriptData grades;

  factory _CatalogBundle.empty() {
    return _CatalogBundle(
      courses: const StudentCourseData(
        message: 'Đang tải danh mục...',
        selectedSemesterId: null,
        semesters: [],
        items: [],
      ),
      grades: StudentGradeTranscriptData.empty(),
    );
  }
}
