part of 'student_course_management_page.dart';

class _GradeEntryModal extends StatefulWidget {
  const _GradeEntryModal({required this.course, required this.studentApi});

  final _ManagedCourse course;
  final StudentApiService studentApi;

  @override
  State<_GradeEntryModal> createState() => _GradeEntryModalState();
}

class _GradeEntryModalState extends State<_GradeEntryModal> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final component in _sortedComponents(widget.course.components)) {
      _controllers[component.id] = TextEditingController(
        text: component.score?.toStringAsFixed(1) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final components = _sortedComponents(widget.course.components);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nhập điểm thành phần',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryStrong,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chỉ nhập điểm, trọng số đã được cấu hình riêng.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineModalError(message: _errorMessage!),
              ],
              const SizedBox(height: 16),
              ...components.map((component) {
                final controller = _controllers[component.id]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              component.name,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Trọng số: ${component.weight.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          enabled: !_isSaving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: colors.text),
                          decoration: _gradeInputDecoration('Điểm', colors),
                          validator: (value) {
                            final parsed = double.tryParse(
                              (value ?? '').trim(),
                            );
                            if (parsed == null || parsed < 0 || parsed > 10) {
                              return '0-10';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu điểm',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryStrong,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<StudentGradeComponent> _sortedComponents(
    List<StudentGradeComponent> components,
  ) {
    final priority = <String, int>{'Chuyên cần': 0, 'Giữa kỳ': 1, 'Cuối kỳ': 2};

    final sorted = [...components];
    sorted.sort((left, right) {
      final leftPriority = priority[left.name.trim()] ?? 99;
      final rightPriority = priority[right.name.trim()] ?? 99;

      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }

      return left.name.compareTo(right.name);
    });

    return sorted;
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      for (final component in widget.course.components) {
        final value = double.parse(_controllers[component.id]!.text.trim());
        if (component.id.isNotEmpty) {
          await widget.studentApi.updateGradeComponent(
            componentId: component.id,
            score: value,
          );
        } else {
          await widget.studentApi.createGradeComponent(
            courseId: widget.course.id,
            name: component.name,
            weight: component.weight,
            score: value,
          );
        }
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _gradeInputDecoration(
    String label,
    StudentThemeColors colors,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textMuted),
      filled: true,
      fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primaryStrong, width: 1.2),
      ),
      errorStyle: TextStyle(color: colors.danger, fontSize: 11),
    );
  }
}

InputDecoration _semesterInputDecoration(
  String label,
  StudentThemeColors colors,
) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colors.textMuted),
    filled: true,
    fillColor: colors.surfaceAlt.withValues(alpha: 0.75),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.primaryStrong, width: 1.2),
    ),
    errorStyle: TextStyle(color: colors.danger, fontSize: 11),
  );
}
