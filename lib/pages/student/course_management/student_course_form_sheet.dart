part of 'student_course_management_page.dart';

class _CourseModal extends StatefulWidget {
  const _CourseModal({this.course, required this.onSave});

  final _ManagedCourse? course;
  final Future<void> Function(_CourseDraft draft) onSave;

  @override
  State<_CourseModal> createState() => _CourseModalState();
}

class _CourseModalState extends State<_CourseModal> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _code;
  late int _credits;
  late double _attendanceWeight;
  late double _midtermWeight;
  late double _finalWeight;
  String? _weightError;
  bool _saving = false;

  /// Khởi tạo state ban đầu và đăng ký dữ liệu/listener cần thiết cho màn hình.
  @override
  void initState() {
    super.initState();
    _name = widget.course?.name ?? '';
    _code = widget.course?.code ?? '';
    _credits = widget.course?.credits ?? 3;
    _attendanceWeight = widget.course?.attendanceWeight ?? 10;
    _midtermWeight = widget.course?.midtermWeight ?? 30;
    _finalWeight = widget.course?.finalWeight ?? 60;
  }

  /// Dựng giao diện cho widget hoặc màn hình hiện tại.
  @override
  Widget build(BuildContext context) {
    final colors = StudentThemeScope.colorsOf(context);
    final totalWeight = _attendanceWeight + _midtermWeight + _finalWeight;

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
                    widget.course != null
                        ? 'Cập nhật trọng số học phần'
                        : 'Thêm môn học mới',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryStrong,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tint(colors.primaryStrong, lightAlpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng trọng số',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalWeight.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: colors.danger,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Cơ cấu trọng số hiện tại',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_attendanceWeight.toStringAsFixed(0)}% - ${_midtermWeight.toStringAsFixed(0)}% - ${_finalWeight.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_weightError != null) ...[
                const SizedBox(height: 12),
                _InlineModalError(message: _weightError!),
              ],
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _name,
                style: TextStyle(color: colors.text),
                decoration: _modalInputDecoration('Tên học phần'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên học phần';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!.trim(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _code,
                      style: TextStyle(color: colors.text),
                      decoration: _modalInputDecoration('Mã môn học'),
                      onSaved: (value) =>
                          _code = (value ?? '').trim().toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _credits.toString(),
                      style: TextStyle(color: colors.text),
                      keyboardType: TextInputType.number,
                      decoration: _modalInputDecoration('Số tín chỉ'),
                      validator: (value) {
                        final credits = int.tryParse(value ?? '');
                        if (credits == null || credits <= 0 || credits > 30) {
                          return 'Tín chỉ 1-30';
                        }
                        return null;
                      },
                      onSaved: (value) =>
                          _credits = int.tryParse(value ?? '') ?? 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Trọng số thành phần',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryStrong,
                ),
              ),
              const SizedBox(height: 12),
              _buildSliderRow('Chuyên cần (%)', _attendanceWeight, (value) {
                setState(() {
                  _attendanceWeight = value;
                  _weightError = null;
                });
              }),
              const SizedBox(height: 12),
              _buildSliderRow('Giữa kỳ (%)', _midtermWeight, (value) {
                setState(() {
                  _midtermWeight = value;
                  _weightError = null;
                });
              }),
              const SizedBox(height: 12),
              _buildSliderRow('Cuối kỳ (%)', _finalWeight, (value) {
                setState(() {
                  _finalWeight = value;
                  _weightError = null;
                });
              }),
              const SizedBox(height: 8),
              Text(
                'Tổng hiện tại: ${totalWeight.toStringAsFixed(1)}%',
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
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
                    _saving ? 'Đang lưu...' : 'Lưu học phần',
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
              if (widget.course != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(
                            context,
                            _CourseModalResult.delete(widget.course!.id),
                          ),
                    icon: Icon(Icons.delete_outline, color: colors.danger),
                    label: Text(
                      'Xóa môn học này',
                      style: TextStyle(color: colors.danger),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.danger, width: 0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Hàm hỗ trợ modal input decoration cho màn hình trong file này.
  InputDecoration _modalInputDecoration(String label) {
    final colors = StudentThemeScope.colorsOf(context);
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

  /// Dựng phần giao diện build slider row cho màn hình hiện tại.
  Widget _buildSliderRow(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final colors = StudentThemeScope.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.info,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.info,
            thumbColor: colors.info,
            trackHeight: 2,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// Xử lý thao tác save và đồng bộ kết quả với UI.
  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final totalWeight = _attendanceWeight + _midtermWeight + _finalWeight;
    if ((totalWeight - 100).abs() > 0.01) {
      setState(() {
        _weightError =
            'Cấu hình trọng số thất bại. Tổng trọng số phải bằng 100%.';
      });
      return;
    }
    _formKey.currentState!.save();
    final draft = _CourseDraft(
      code: _code,
      name: _name,
      credits: _credits,
      attendanceWeight: _attendanceWeight,
      midtermWeight: _midtermWeight,
      finalWeight: _finalWeight,
    );

    setState(() {
      _saving = true;
      _weightError = null;
    });
    try {
      await widget.onSave(draft);
      if (mounted) {
        Navigator.pop(context);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _weightError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _weightError = 'Không thể lưu học phần lúc này.';
      });
    }
  }
}
