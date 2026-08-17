/// Lỗi API đã được chuẩn hóa để các màn hình UI có thể hiển thị message an toàn.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  final String code;
  final String message;
  final Object? details;
  final int? statusCode;

  @override
  String toString() => message;
}
