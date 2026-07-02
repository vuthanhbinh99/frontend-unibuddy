import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

const _kCommonPasswords = <String>{
  '12345678',
  'password',
  '123456789',
  '11111111',
  'qwertyui',
};

class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.password,
    required this.requiresPersonalInfoCheck,
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialCharacter,
    required this.hasNoPersonalInfo,
    required this.isNotCommon,
  });

  final String password;
  final bool requiresPersonalInfoCheck;
  final bool hasMinimumLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialCharacter;
  final bool hasNoPersonalInfo;
  final bool isNotCommon;

  int get metCriteriaCount => [
    hasMinimumLength,
    hasUppercase,
    hasLowercase,
    hasDigit,
    hasSpecialCharacter,
    hasNoPersonalInfo,
    isNotCommon,
  ].where((item) => item).length;

  int get score => metCriteriaCount <= 3
      ? 0
      : metCriteriaCount >= 7
      ? 4
      : metCriteriaCount - 3;

  bool get isStrong =>
      hasMinimumLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSpecialCharacter &&
      hasNoPersonalInfo &&
      isNotCommon;

  PasswordStrengthLevel get level {
    if (password.isEmpty) {
      return PasswordStrengthLevel.empty;
    }
    if (!hasMinimumLength || score <= 1) {
      return PasswordStrengthLevel.weak;
    }
    if (score == 2) {
      return PasswordStrengthLevel.medium;
    }
    return PasswordStrengthLevel.strong;
  }

  int get filledBars {
    switch (level) {
      case PasswordStrengthLevel.empty:
        return 0;
      case PasswordStrengthLevel.weak:
        return 1;
      case PasswordStrengthLevel.medium:
        return 2;
      case PasswordStrengthLevel.strong:
        return 4;
    }
  }

  List<PasswordRuleCheck> get visibleRules => [
    PasswordRuleCheck(
      labelVi: 'Ít nhất 8 ký tự',
      labelEn: 'At least 8 characters',
      passed: hasMinimumLength,
    ),
    PasswordRuleCheck(
      labelVi: 'Có chữ hoa',
      labelEn: 'Contains an uppercase letter',
      passed: hasUppercase,
    ),
    PasswordRuleCheck(
      labelVi: 'Có chữ thường',
      labelEn: 'Contains a lowercase letter',
      passed: hasLowercase,
    ),
    PasswordRuleCheck(
      labelVi: 'Có chữ số',
      labelEn: 'Contains a number',
      passed: hasDigit,
    ),
    PasswordRuleCheck(
      labelVi: 'Có ký tự đặc biệt',
      labelEn: 'Contains a special character',
      passed: hasSpecialCharacter,
    ),
    if (requiresPersonalInfoCheck)
      PasswordRuleCheck(
        labelVi: 'Không chứa email, tên hoặc mã sinh viên',
        labelEn: 'Does not include email, name, or student ID',
        passed: hasNoPersonalInfo,
      ),
    PasswordRuleCheck(
      labelVi: 'Không dùng mật khẩu phổ biến',
      labelEn: 'Not a common password',
      passed: isNotCommon,
    ),
  ];

  static PasswordStrengthResult evaluate(
    String password, {
    List<String> relatedValues = const [],
  }) {
    final normalized = password;
    final normalizedLower = normalized.toLowerCase();
    final sanitizedRelated = relatedValues
        .map((value) => value.trim())
        .where((value) => value.length >= 3)
        .toList(growable: false);

    return PasswordStrengthResult(
      password: normalized,
      requiresPersonalInfoCheck: sanitizedRelated.isNotEmpty,
      hasMinimumLength: normalized.length >= 8,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(normalized),
      hasLowercase: RegExp(r'[a-z]').hasMatch(normalized),
      hasDigit: RegExp(r'\d').hasMatch(normalized),
      hasSpecialCharacter: RegExp(r'[^A-Za-z0-9]').hasMatch(normalized),
      hasNoPersonalInfo: sanitizedRelated.every(
        (value) => !normalizedLower.contains(value.toLowerCase()),
      ),
      isNotCommon: !_kCommonPasswords.contains(normalizedLower),
    );
  }
}

enum PasswordStrengthLevel { empty, weak, medium, strong }

class PasswordStrengthGuidance extends StatelessWidget {
  const PasswordStrengthGuidance({
    super.key,
    required this.password,
    this.relatedValues = const [],
  });

  final String password;
  final List<String> relatedValues;

  @override
  Widget build(BuildContext context) {
    final isVietnamese = context.l10n.languageCode == 'vi';
    final colors = Theme.of(context).colorScheme;
    final result = PasswordStrengthResult.evaluate(
      password,
      relatedValues: relatedValues,
    );

    final levelColor = switch (result.level) {
      PasswordStrengthLevel.empty => colors.outline,
      PasswordStrengthLevel.weak => const Color(0xFFEF4444),
      PasswordStrengthLevel.medium => const Color(0xFFF59E0B),
      PasswordStrengthLevel.strong => const Color(0xFF22C55E),
    };

    final levelLabel = switch (result.level) {
      PasswordStrengthLevel.empty => isVietnamese ? 'Chưa nhập' : 'Not started',
      PasswordStrengthLevel.weak => isVietnamese ? 'Yếu' : 'Weak',
      PasswordStrengthLevel.medium => isVietnamese ? 'Trung bình' : 'Medium',
      PasswordStrengthLevel.strong => isVietnamese ? 'Mạnh' : 'Strong',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(4, (index) {
            final isFilled = index < result.filledBars;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 8,
                  decoration: BoxDecoration(
                    color: isFilled
                        ? levelColor
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isFilled ? levelColor : colors.outlineVariant,
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isVietnamese ? 'Độ mạnh mật khẩu' : 'Password strength',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              levelLabel,
              style: TextStyle(
                color: levelColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final rules = result.visibleRules;
            if (constraints.maxWidth >= 420 && rules.length > 1) {
              final split = (rules.length / 2).ceil();
              final left = rules.take(split).toList(growable: false);
              final right = rules.skip(split).toList(growable: false);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRuleColumn(context, left)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildRuleColumn(context, right)),
                ],
              );
            }

            return _buildRuleColumn(context, rules);
          },
        ),
      ],
    );
  }

  Widget _buildRuleColumn(BuildContext context, List<PasswordRuleCheck> rules) {
    final isVietnamese = context.l10n.languageCode == 'vi';
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var index = 0; index < rules.length; index++) ...[
          _PasswordRuleTile(
            label: isVietnamese ? rules[index].labelVi : rules[index].labelEn,
            passed: rules[index].passed,
            colors: colors,
          ),
          if (index != rules.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class PasswordRuleCheck {
  const PasswordRuleCheck({
    required this.labelVi,
    required this.labelEn,
    required this.passed,
  });

  final String labelVi;
  final String labelEn;
  final bool passed;
}

class _PasswordRuleTile extends StatelessWidget {
  const _PasswordRuleTile({
    required this.label,
    required this.passed,
    required this.colors,
  });

  final String label;
  final bool passed;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final activeColor = passed ? const Color(0xFF22C55E) : colors.outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: passed
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.35,
              fontWeight: passed ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

String? passwordStrengthValidationMessage(
  BuildContext context,
  String password, {
  List<String> relatedValues = const [],
}) {
  final isVietnamese = context.l10n.languageCode == 'vi';
  final result = PasswordStrengthResult.evaluate(
    password,
    relatedValues: relatedValues,
  );

  if (result.isStrong) {
    return null;
  }

  return isVietnamese
      ? 'Mật khẩu chưa đủ mạnh. Hãy xem checklist bên dưới.'
      : 'Password is not strong enough. Please follow the checklist below.';
}
