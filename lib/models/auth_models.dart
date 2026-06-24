enum UserRoleCode {
  student('SINH_VIEN'),
  admin('ADMIN'),
  systemAdmin('QUAN_TRI_VIEN');

  const UserRoleCode(this.value);

  final String value;

  static UserRoleCode? from(String code) {
    for (final role in UserRoleCode.values) {
      if (role.value == code) {
        return role;
      }
    }
    return null;
  }
}

class UserRole {
  const UserRole({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

extension UserRoleMatching on UserRole {
  UserRoleCode? get roleCode => UserRoleCode.from(code);

  bool get isAdminOrSystemAdmin {
    return roleCode == UserRoleCode.admin ||
        roleCode == UserRoleCode.systemAdmin;
  }
}

class PublicUser {
  const PublicUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final String status;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    return PublicUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String,
      role: UserRole.fromJson(json['role'] as Map<String, dynamic>),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  final PublicUser user;
  final String accessToken;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        json['refreshTokenExpiresAt'] as String,
      ),
    );
  }
}

sealed class AuthLoginResult {
  const AuthLoginResult();
}

class AuthenticatedLoginResult extends AuthLoginResult {
  const AuthenticatedLoginResult(this.session);

  final AuthSession session;
}

class PasswordChangeRequiredLoginResult extends AuthLoginResult {
  const PasswordChangeRequiredLoginResult({
    required this.user,
    this.temporaryPasswordExpiresAt,
  });

  final PublicUser user;
  final DateTime? temporaryPasswordExpiresAt;

  factory PasswordChangeRequiredLoginResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return PasswordChangeRequiredLoginResult(
      user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
      temporaryPasswordExpiresAt: _parseDate(
        json['temporaryPasswordExpiresAt'],
      ),
    );
  }
}

class StudentProfile {
  const StudentProfile({
    required this.maNguoiDung,
    required this.maSinhVien,
    this.maTruong,
    this.maTruongCode,
    this.nganhHoc,
    this.khoaHoc,
  });

  final String maNguoiDung;
  final String maSinhVien;
  final int? maTruong;
  final String? maTruongCode;
  final String? nganhHoc;
  final String? khoaHoc;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      maNguoiDung: json['maNguoiDung'] as String,
      maSinhVien: json['maSinhVien'] as String,
      maTruong: json['maTruong'] as int?,
      maTruongCode: json['maTruongCode'] as String?,
      nganhHoc: json['nganhHoc'] as String?,
      khoaHoc: json['khoaHoc'] as String?,
    );
  }
}

class RegisterStudentResult {
  const RegisterStudentResult({
    required this.message,
    required this.user,
    required this.studentProfile,
  });

  final String message;
  final PublicUser user;
  final StudentProfile studentProfile;

  factory RegisterStudentResult.fromJson(Map<String, dynamic> json) {
    return RegisterStudentResult(
      message: json['message'] as String? ?? 'Đăng ký thành công',
      user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
      studentProfile: StudentProfile.fromJson(
        json['studentProfile'] as Map<String, dynamic>,
      ),
    );
  }
}

class ResetPasswordToken {
  const ResetPasswordToken({required this.resetToken, required this.expiresAt});

  final String resetToken;
  final DateTime expiresAt;

  factory ResetPasswordToken.fromJson(Map<String, dynamic> json) {
    return ResetPasswordToken(
      resetToken: json['resetToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
