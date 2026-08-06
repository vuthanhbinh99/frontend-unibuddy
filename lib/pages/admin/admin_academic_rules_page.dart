import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/modules/admin_api_service.dart';
import 'widgets/admin_common.dart';

/// Trang cấu hình quy chế học lực và thang điểm cho một trường.
///
/// Được mở từ danh mục trường. Admin có thể chỉnh sửa trực tiếp trên form
/// thay vì phải sửa dữ liệu trong DB.
class AdminAcademicRulesPage extends StatefulWidget {
  const AdminAcademicRulesPage({
    super.key,
    required this.api,
    required this.schoolCode,
    required this.schoolName,
  });

  final AdminApiService api;
  final String schoolCode;
  final String schoolName;

  @override
  State<AdminAcademicRulesPage> createState() => _AdminAcademicRulesPageState();
}

class _AdminAcademicRulesPageState extends State<AdminAcademicRulesPage> {
  late Future<AdminAcademicRules> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getAcademicRules(widget.schoolCode);
  }

  Future<void> _refresh() async {
    final rules = await widget.api.getAcademicRules(widget.schoolCode);
    if (!mounted) {
      return;
    }
    setState(() => _future = Future.value(rules));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAdminLightTheme(),
      child: Scaffold(
        backgroundColor: adminBackground,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cấu hình học thuật',
                style: TextStyle(
                  color: adminText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${widget.schoolName} · ${widget.schoolCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: adminMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        body: FutureBuilder<AdminAcademicRules>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AdminLoading();
            }

            if (snapshot.hasError) {
              return AdminErrorState(
                message: _formatError(snapshot.error!),
                onRetry: _refresh,
              );
            }

            final rules = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: adminPagePadding(context),
                children: [
                  _ScoreScaleSection(
                    api: widget.api,
                    schoolCode: widget.schoolCode,
                    initial: rules.scoreScale,
                  ),
                  const SizedBox(height: 20),
                  _AcademicStandingSection(
                    api: widget.api,
                    schoolCode: widget.schoolCode,
                    initial: rules.academicStandings,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Không thể tải cấu hình học thuật.';
  }
}

// ---------------------------------------------------------------------------
// Thang điểm
// ---------------------------------------------------------------------------

class _ScoreScaleSection extends StatefulWidget {
  const _ScoreScaleSection({
    required this.api,
    required this.schoolCode,
    required this.initial,
  });

  final AdminApiService api;
  final String schoolCode;
  final List<AdminScoreScaleLevel> initial;

  @override
  State<_ScoreScaleSection> createState() => _ScoreScaleSectionState();
}

class _ScoreScaleSectionState extends State<_ScoreScaleSection> {
  late List<_ScoreScaleRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.initial.map(_ScoreScaleRow.fromModel).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_ScoreScaleRow.empty()));
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    final levels = <AdminScoreScaleLevel>[];

    for (final row in _rows) {
      final parsed = row.toModel();
      if (parsed == null) {
        _showError('Vui lòng nhập đầy đủ và đúng định dạng các mức thang điểm.');
        return;
      }
      levels.add(parsed);
    }

    if (levels.isEmpty) {
      _showError('Cần ít nhất một mức thang điểm.');
      return;
    }

    final validationError = _validateScoreScale(levels);
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.updateScoreScale(
        code: widget.schoolCode,
        levels: levels,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Đã lưu thang điểm.');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể lưu thang điểm.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.grading,
            title: 'Thang điểm chữ',
            subtitle: 'Ánh xạ khoảng điểm số sang điểm chữ và hệ 4.',
          ),
          const SizedBox(height: 14),
          const _ScoreScaleHeaderRow(),
          const Divider(height: 18, color: adminBorder),
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có mức nào. Nhấn "Thêm mức" để bắt đầu.',
                style: TextStyle(color: adminMuted),
              ),
            )
          else
            ...List.generate(_rows.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScoreScaleRowEditor(
                  row: _rows[index],
                  onRemove: () => _removeRow(index),
                ),
              );
            }),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Thêm mức'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Lưu thang điểm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: adminDanger),
    );
  }
}

class _ScoreScaleHeaderRow extends StatelessWidget {
  const _ScoreScaleHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: adminMuted,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    return const Row(
      children: [
        Expanded(flex: 3, child: Text('Điểm từ', style: style)),
        SizedBox(width: 8),
        Expanded(flex: 3, child: Text('Điểm đến', style: style)),
        SizedBox(width: 8),
        Expanded(flex: 3, child: Text('Điểm chữ', style: style)),
        SizedBox(width: 8),
        Expanded(flex: 3, child: Text('Hệ 4', style: style)),
        SizedBox(width: 40),
      ],
    );
  }
}

class _ScoreScaleRowEditor extends StatelessWidget {
  const _ScoreScaleRowEditor({required this.row, required this.onRemove});

  final _ScoreScaleRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 3, child: _CompactField(controller: row.diemTu)),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _CompactField(controller: row.diemDen)),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: _CompactField(
            controller: row.diemChu,
            capitalize: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _CompactField(controller: row.he4)),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: 'Xóa mức',
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: adminDanger, size: 20),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quy chế học lực
// ---------------------------------------------------------------------------

class _AcademicStandingSection extends StatefulWidget {
  const _AcademicStandingSection({
    required this.api,
    required this.schoolCode,
    required this.initial,
  });

  final AdminApiService api;
  final String schoolCode;
  final List<AdminAcademicStanding> initial;

  @override
  State<_AcademicStandingSection> createState() =>
      _AcademicStandingSectionState();
}

class _AcademicStandingSectionState extends State<_AcademicStandingSection> {
  late List<_StandingRow> _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.initial.map(_StandingRow.fromModel).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_StandingRow.empty()));
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    final standings = <AdminAcademicStanding>[];

    for (final row in _rows) {
      final parsed = row.toModel();
      if (parsed == null) {
        _showError('Vui lòng nhập đầy đủ và đúng định dạng các mức quy chế.');
        return;
      }
      standings.add(parsed);
    }

    if (standings.isEmpty) {
      _showError('Cần ít nhất một mức quy chế học lực.');
      return;
    }

    final validationError = _validateAcademicStandings(standings);
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.updateAcademicStandings(
        code: widget.schoolCode,
        standings: standings,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Đã lưu quy chế học lực.');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể lưu quy chế học lực.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.workspace_premium_outlined,
            title: 'Quy chế học lực',
            subtitle: 'Xếp loại học lực theo khoảng GPA (hệ 4).',
          ),
          const SizedBox(height: 14),
          const _StandingHeaderRow(),
          const Divider(height: 18, color: adminBorder),
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có mức nào. Nhấn "Thêm mức" để bắt đầu.',
                style: TextStyle(color: adminMuted),
              ),
            )
          else
            ...List.generate(_rows.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StandingRowEditor(
                  row: _rows[index],
                  onRemove: () => _removeRow(index),
                ),
              );
            }),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Thêm mức'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Lưu quy chế'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: adminDanger),
    );
  }
}

class _StandingHeaderRow extends StatelessWidget {
  const _StandingHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: adminMuted,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    return const Row(
      children: [
        Expanded(flex: 5, child: Text('Xếp loại', style: style)),
        SizedBox(width: 8),
        Expanded(flex: 3, child: Text('GPA từ', style: style)),
        SizedBox(width: 8),
        Expanded(flex: 3, child: Text('GPA đến', style: style)),
        SizedBox(width: 40),
      ],
    );
  }
}

class _StandingRowEditor extends StatelessWidget {
  const _StandingRowEditor({required this.row, required this.onRemove});

  final _StandingRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 5, child: _CompactField(controller: row.xepLoai)),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _CompactField(controller: row.gpaTu)),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _CompactField(controller: row.gpaDen)),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: 'Xóa mức',
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: adminDanger, size: 20),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widget dùng chung
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: adminPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: adminPrimary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: adminText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: adminMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({required this.controller, this.capitalize = false});

  final TextEditingController controller;
  final bool capitalize;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: capitalize
          ? TextCapitalization.characters
          : TextCapitalization.none,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row state holders
// ---------------------------------------------------------------------------

class _ScoreScaleRow {
  _ScoreScaleRow({
    required this.diemTu,
    required this.diemDen,
    required this.diemChu,
    required this.he4,
  });

  factory _ScoreScaleRow.empty() {
    return _ScoreScaleRow(
      diemTu: TextEditingController(),
      diemDen: TextEditingController(),
      diemChu: TextEditingController(),
      he4: TextEditingController(),
    );
  }

  factory _ScoreScaleRow.fromModel(AdminScoreScaleLevel level) {
    return _ScoreScaleRow(
      diemTu: TextEditingController(text: _fmt(level.diemTu)),
      diemDen: TextEditingController(text: _fmt(level.diemDen)),
      diemChu: TextEditingController(text: level.diemChu),
      he4: TextEditingController(text: _fmt(level.he4)),
    );
  }

  final TextEditingController diemTu;
  final TextEditingController diemDen;
  final TextEditingController diemChu;
  final TextEditingController he4;

  AdminScoreScaleLevel? toModel() {
    final tu = double.tryParse(diemTu.text.trim().replaceAll(',', '.'));
    final den = double.tryParse(diemDen.text.trim().replaceAll(',', '.'));
    final chu = diemChu.text.trim();
    final h4 = double.tryParse(he4.text.trim().replaceAll(',', '.'));

    if (tu == null || den == null || h4 == null || chu.isEmpty) {
      return null;
    }

    return AdminScoreScaleLevel(
      diemTu: tu,
      diemDen: den,
      diemChu: chu.toUpperCase(),
      he4: h4,
    );
  }

  void dispose() {
    diemTu.dispose();
    diemDen.dispose();
    diemChu.dispose();
    he4.dispose();
  }
}

class _StandingRow {
  _StandingRow({
    required this.xepLoai,
    required this.gpaTu,
    required this.gpaDen,
  });

  factory _StandingRow.empty() {
    return _StandingRow(
      xepLoai: TextEditingController(),
      gpaTu: TextEditingController(),
      gpaDen: TextEditingController(),
    );
  }

  factory _StandingRow.fromModel(AdminAcademicStanding standing) {
    return _StandingRow(
      xepLoai: TextEditingController(text: standing.xepLoai),
      gpaTu: TextEditingController(text: _fmt(standing.gpaTu)),
      gpaDen: TextEditingController(text: _fmt(standing.gpaDen)),
    );
  }

  final TextEditingController xepLoai;
  final TextEditingController gpaTu;
  final TextEditingController gpaDen;

  AdminAcademicStanding? toModel() {
    final loai = xepLoai.text.trim();
    final tu = double.tryParse(gpaTu.text.trim().replaceAll(',', '.'));
    final den = double.tryParse(gpaDen.text.trim().replaceAll(',', '.'));

    if (loai.isEmpty || tu == null || den == null) {
      return null;
    }

    return AdminAcademicStanding(xepLoai: loai, gpaTu: tu, gpaDen: den);
  }

  void dispose() {
    xepLoai.dispose();
    gpaTu.dispose();
    gpaDen.dispose();
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

const double _academicRuleTolerance = 0.001;

bool _nearlyEqual(double a, double b) {
  return (a - b).abs() <= _academicRuleTolerance;
}

String? _validateScoreScale(List<AdminScoreScaleLevel> levels) {
  final sorted = levels.asMap().entries.toList()
    ..sort((a, b) => a.value.diemTu.compareTo(b.value.diemTu));
  final usedLetters = <String>{};

  for (var index = 0; index < sorted.length; index++) {
    final entry = sorted[index];
    final level = entry.value;
    final rowNumber = entry.key + 1;
    final letter = level.diemChu.trim().toUpperCase();

    if (level.diemTu < 0 || level.diemDen > 10) {
      return 'Dòng $rowNumber: điểm phải nằm trong khoảng 0 đến 10.';
    }

    if (level.diemTu >= level.diemDen) {
      return 'Dòng $rowNumber: Điểm từ phải nhỏ hơn Điểm đến.';
    }

    if (letter.isEmpty) {
      return 'Dòng $rowNumber: Điểm chữ không được để trống.';
    }

    if (usedLetters.contains(letter)) {
      return 'Dòng $rowNumber: Điểm chữ $letter bị trùng.';
    }
    usedLetters.add(letter);

    if (level.he4 < 0 || level.he4 > 4) {
      return 'Dòng $rowNumber: Hệ 4 phải nằm trong khoảng 0 đến 4.';
    }

    if (index == 0) {
      if (!_nearlyEqual(level.diemTu, 0)) {
        return 'Thang điểm phải bắt đầu từ 0.';
      }
      continue;
    }

    final previous = sorted[index - 1].value;
    if (level.diemTu <= previous.diemDen) {
      return 'Dòng $rowNumber: khoảng điểm bị chồng lấn với dòng trước.';
    }

    if (!_nearlyEqual(level.diemTu, previous.diemDen + 0.01)) {
      return 'Dòng $rowNumber: thang điểm phải phủ liên tục, không được hở khoảng.';
    }

    if (level.he4 < previous.he4) {
      return 'Dòng $rowNumber: Hệ 4 phải tăng dần theo điểm.';
    }
  }

  if (!_nearlyEqual(sorted.last.value.diemDen, 10)) {
    return 'Thang điểm phải kết thúc ở 10.';
  }

  return null;
}

String? _validateAcademicStandings(List<AdminAcademicStanding> standings) {
  final sorted = standings.asMap().entries.toList()
    ..sort((a, b) => a.value.gpaTu.compareTo(b.value.gpaTu));
  final usedNames = <String>{};

  for (var index = 0; index < sorted.length; index++) {
    final entry = sorted[index];
    final standing = entry.value;
    final rowNumber = entry.key + 1;
    final name = standing.xepLoai.trim().toLowerCase();

    if (standing.gpaTu < 0 || standing.gpaDen > 4) {
      return 'Dòng $rowNumber: GPA phải nằm trong khoảng 0 đến 4.';
    }

    if (standing.gpaTu >= standing.gpaDen) {
      return 'Dòng $rowNumber: GPA từ phải nhỏ hơn GPA đến.';
    }

    if (name.isEmpty) {
      return 'Dòng $rowNumber: Xếp loại không được để trống.';
    }

    if (usedNames.contains(name)) {
      return 'Dòng $rowNumber: Xếp loại ${standing.xepLoai} bị trùng.';
    }
    usedNames.add(name);

    if (index == 0) {
      if (!_nearlyEqual(standing.gpaTu, 0)) {
        return 'Quy chế học lực phải bắt đầu từ GPA 0.';
      }
      continue;
    }

    final previous = sorted[index - 1].value;
    if (standing.gpaTu <= previous.gpaDen) {
      return 'Dòng $rowNumber: khoảng GPA bị chồng lấn với dòng trước.';
    }

    if (!_nearlyEqual(standing.gpaTu, previous.gpaDen + 0.01)) {
      return 'Dòng $rowNumber: quy chế học lực phải phủ liên tục, không được hở khoảng.';
    }
  }

  if (!_nearlyEqual(sorted.last.value.gpaDen, 4)) {
    return 'Quy chế học lực phải kết thúc ở GPA 4.';
  }

  return null;
}
