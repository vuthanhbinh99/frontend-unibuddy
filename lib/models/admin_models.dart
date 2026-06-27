enum AdminReportStatus {
  pending('CHO_XU_LY'),
  approved('DA_DUYET'),
  rejected('DA_TU_CHOI');

  const AdminReportStatus(this.value);

  final String value;

  static AdminReportStatus from(String value) {
    return AdminReportStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AdminReportStatus.pending,
    );
  }
}

enum AdminDocumentStatus {
  available('KHA_DUNG'),
  deleted('DA_XOA'),
  pendingModeration('CHO_KIEM_DUYET');

  const AdminDocumentStatus(this.value);

  final String value;

  static AdminDocumentStatus from(String value) {
    return AdminDocumentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AdminDocumentStatus.available,
    );
  }
}

class AdminSchool {
  const AdminSchool({
    required this.code,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  final String code;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminSchool.fromJson(Map<String, dynamic> json) {
    return AdminSchool(
      code: json['maTruongCode'] as String,
      name: json['tenTruong'] as String,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class AdminDocumentReport {
  const AdminDocumentReport({
    required this.id,
    required this.documentId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.documentName,
    required this.documentStatus,
    this.reporterEmail,
    this.reporterName,
    this.moderatorId,
    this.moderatorEmail,
    this.moderatorName,
    this.moderationResult,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String documentId;
  final String reporterId;
  final String reason;
  final AdminReportStatus status;
  final String documentName;
  final AdminDocumentStatus documentStatus;
  final String? reporterEmail;
  final String? reporterName;
  final String? moderatorId;
  final String? moderatorEmail;
  final String? moderatorName;
  final String? moderationResult;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminDocumentReport.fromJson(Map<String, dynamic> json) {
    return AdminDocumentReport(
      id: json['maBaoCao'] as String,
      documentId: json['maTaiLieu'] as String,
      reporterId: json['nguoiBaoCao'] as String,
      reporterEmail: json['nguoiBaoCaoEmail'] as String?,
      reporterName: json['nguoiBaoCaoHoTen'] as String?,
      reason: json['lyDo'] as String,
      status: AdminReportStatus.from(json['trangThai'] as String),
      moderatorId: json['nguoiKiemDuyet'] as String?,
      moderatorEmail: json['nguoiKiemDuyetEmail'] as String?,
      moderatorName: json['nguoiKiemDuyetHoTen'] as String?,
      moderationResult: json['ketQuaKiemDuyet'] as String?,
      documentName: json['tenFile'] as String? ?? 'Tài liệu chưa đặt tên',
      documentStatus: AdminDocumentStatus.from(
        json['trangThaiTaiLieu'] as String? ?? 'KHA_DUNG',
      ),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.schools,
    required this.pendingReports,
    required this.approvedReports,
    required this.rejectedReports,
  });

  final List<AdminSchool> schools;
  final List<AdminDocumentReport> pendingReports;
  final List<AdminDocumentReport> approvedReports;
  final List<AdminDocumentReport> rejectedReports;

  int get processedReportCount =>
      approvedReports.length + rejectedReports.length;

  List<AdminDocumentReport> get recentReports {
    final allReports = [
      ...pendingReports,
      ...approvedReports,
      ...rejectedReports,
    ];
    allReports.sort((a, b) {
      final aTime =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return allReports.take(6).toList();
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
