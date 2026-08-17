import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../services/api/core/api_exception.dart';
import '../../services/api/modules/auth/auth_api_service.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_strength_indicator.dart';

String textOrFallback(
  BuildContext context, {
  required String key,
  required String fallbackVi,
  required String fallbackEn,
}) {
  final value = context.l10n.t(key);
  if (value != key) {
    return value;
  }

  return context.l10n.languageCode == 'en' ? fallbackEn : fallbackVi;
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.authApi});

  final AuthApiService authApi;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _maSinhVienController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nganhHocController = TextEditingController();
  final _khoaHocController = TextEditingController();

  List<PublicSchool> _schools = const [];
  PublicSchool? _selectedSchool;
  bool _loadingSchools = true;
  String? _schoolsError;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _maSinhVienController.dispose();
    _phoneController.dispose();
    _nganhHocController.dispose();
    _khoaHocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final schoolLabel = textOrFallback(
      context,
      key: 'auth.register.school',
      fallbackVi: 'Trường học (tùy chọn)',
      fallbackEn: 'School (optional)',
    );
    final schoolHint = textOrFallback(
      context,
      key: 'auth.register.schoolHint',
      fallbackVi: 'Chọn từ danh sách trường học',
      fallbackEn: 'Choose from the school list',
    );
    final schoolRetry = textOrFallback(
      context,
      key: 'auth.register.schoolRetry',
      fallbackVi: 'Thử lại',
      fallbackEn: 'Retry',
    );

    return AuthScaffold(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              showBackButton: true,
              title: l10n.t('auth.register.title'),
              subtitle: l10n.t('auth.register.subtitle'),
            ),
            const SizedBox(height: 26),
            TextFormField(
              controller: _fullNameController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline),
                labelText: l10n.t('auth.register.fullName'),
              ),
              validator: _required(l10n.t('auth.register.requiredName')),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.mail_outline),
                labelText: l10n.t('auth.fields.email'),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _maSinhVienController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined),
                labelText: l10n.t('auth.register.studentId'),
              ),
              validator: _required(l10n.t('auth.register.requiredStudentId')),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_outlined),
                labelText: l10n.t('auth.register.phone'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nganhHocController,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.menu_book_outlined),
                      labelText: l10n.t('auth.register.major'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _khoaHocController,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      labelText: l10n.t('auth.register.cohort'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SchoolAutocompleteField(
              labelText: schoolLabel,
              hintText: schoolHint,
              schools: _schools,
              loadingSchools: _loadingSchools,
              selectedSchool: _selectedSchool,
              onSelected: (school) {
                setState(() {
                  _selectedSchool = school;
                });
              },
              onCleared: () {
                setState(() {
                  _selectedSchool = null;
                });
              },
              onOpenFullList: _openSchoolPicker,
            ),
            if (_schoolsError != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadSchools,
                icon: const Icon(Icons.refresh),
                label: Text(schoolRetry),
              ),
              Text(
                _schoolsError!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              onChanged: (_) => setState(() {}),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                labelText: l10n.t('auth.fields.password'),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 10),
            PasswordStrengthGuidance(
              password: _passwordController.text,
              relatedValues: [
                _fullNameController.text,
                _emailController.text,
                _maSinhVienController.text,
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                labelText: l10n.t('auth.passwordChange.confirmPassword'),
              ),
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              AuthMessage(message: _errorMessage!, kind: AuthMessageKind.error),
              const SizedBox(height: 14),
            ],
            if (_successMessage != null) ...[
              AuthMessage(
                message: _successMessage!,
                kind: AuthMessageKind.success,
              ),
              const SizedBox(height: 14),
            ],
            AuthActionButton(
              label: l10n.t('auth.register.button'),
              loading: _loading,
              icon: Icons.person_add_alt_1,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await widget.authApi.registerStudent(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        maSinhVien: _maSinhVienController.text,
        phoneNumber: _phoneController.text,
        maTruongCode: _selectedSchool?.code,
        nganhHoc: _nganhHocController.text,
        khoaHoc: _khoaHocController.text,
      );

      setState(
        () => _successMessage = context.l10n.t(
          'auth.register.success',
          arguments: {'message': result.message},
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() => _errorMessage = context.l10n.t('auth.register.error'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  FormFieldValidator<String> _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }

  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return context.l10n.t('auth.validation.emailRequired');
    }
    if (!emailRegex.hasMatch(text)) {
      return context.l10n.t('auth.validation.emailInvalid');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return context.l10n.t('auth.register.requiredPassword');
    }

    final message = passwordStrengthValidationMessage(
      context,
      password,
      relatedValues: [
        _fullNameController.text,
        _emailController.text,
        _maSinhVienController.text,
      ],
    );
    if (message != null) {
      return message;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return context.l10n.t('auth.register.passwordMismatch');
    }
    return null;
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loadingSchools = true;
      _schoolsError = null;
    });

    try {
      final schools = await widget.authApi.listSchools();
      if (!mounted) {
        return;
      }
      setState(() {
        _schools = schools;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _schoolsError = context.l10n.t('auth.register.schoolLoadFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSchools = false;
        });
      }
    }
  }

  Future<void> _openSchoolPicker() async {
    if (_schools.isEmpty) {
      return;
    }

    final selectedSchool = await showModalBottomSheet<PublicSchool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _SchoolPickerSheet(
          schools: _schools,
          selectedSchool: _selectedSchool,
        );
      },
    );

    if (selectedSchool == null || !mounted) {
      return;
    }

    setState(() {
      _selectedSchool = selectedSchool;
    });
  }
}

class _SchoolAutocompleteField extends StatefulWidget {
  const _SchoolAutocompleteField({
    required this.labelText,
    required this.hintText,
    required this.schools,
    required this.loadingSchools,
    required this.selectedSchool,
    required this.onSelected,
    required this.onCleared,
    required this.onOpenFullList,
  });

  final String labelText;
  final String hintText;
  final List<PublicSchool> schools;
  final bool loadingSchools;
  final PublicSchool? selectedSchool;
  final ValueChanged<PublicSchool> onSelected;
  final VoidCallback onCleared;
  final VoidCallback onOpenFullList;

  @override
  State<_SchoolAutocompleteField> createState() =>
      _SchoolAutocompleteFieldState();
}

class _SchoolAutocompleteFieldState extends State<_SchoolAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncWithSelection();
  }

  @override
  void didUpdateWidget(covariant _SchoolAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSchool?.code != widget.selectedSchool?.code) {
      _syncWithSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = textOrFallback(
      context,
      key: 'auth.register.schoolPickerTitle',
      fallbackVi: 'Chọn trường học',
      fallbackEn: 'Choose a school',
    );
    final emptyLabel = textOrFallback(
      context,
      key: 'auth.register.schoolEmpty',
      fallbackVi: 'Không tìm thấy trường phù hợp.',
      fallbackEn: 'No matching school found.',
    );

    return RawAutocomplete<PublicSchool>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: _displaySchool,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return widget.schools;
        }

        return widget.schools.where((school) {
          return school.code.toLowerCase().contains(query) ||
              school.name.toLowerCase().contains(query);
        });
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) {
            if (widget.selectedSchool != null &&
                value != _displaySchool(widget.selectedSchool!)) {
              widget.onCleared();
            }
            setState(() {});
          },
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.apartment_outlined),
            labelText: widget.labelText,
            hintText: widget.hintText,
            suffixIcon: widget.loadingSchools
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            controller.clear();
                            widget.onCleared();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        onPressed: widget.onOpenFullList,
                        icon: const Icon(Icons.list_alt_outlined),
                        tooltip: title,
                      ),
                    ],
                  ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();
        final width = MediaQuery.of(context).size.width - 40;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
                maxWidth: width,
                minWidth: width,
              ),
              child: optionList.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(emptyLabel, textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: optionList.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final school = optionList[index];
                        final isSelected =
                            widget.selectedSchool?.code == school.code;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.school_outlined),
                          title: Text(school.name),
                          subtitle: Text(school.code),
                          trailing: isSelected ? const Icon(Icons.check) : null,
                          onTap: () {
                            onSelected(school);
                            _controller.text = _displaySchool(school);
                            _controller.selection = TextSelection.collapsed(
                              offset: _controller.text.length,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  void _syncWithSelection() {
    final selectedSchool = widget.selectedSchool;
    if (selectedSchool == null) {
      _controller.clear();
      return;
    }

    _controller.text = _displaySchool(selectedSchool);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  String _displaySchool(PublicSchool school) {
    return '${school.code} - ${school.name}';
  }
}

class _SchoolPickerSheet extends StatefulWidget {
  const _SchoolPickerSheet({
    required this.schools,
    required this.selectedSchool,
  });

  final List<PublicSchool> schools;
  final PublicSchool? selectedSchool;

  @override
  State<_SchoolPickerSheet> createState() => _SchoolPickerSheetState();
}

class _SchoolPickerSheetState extends State<_SchoolPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = textOrFallback(
      context,
      key: 'auth.register.schoolPickerTitle',
      fallbackVi: 'Chọn trường học',
      fallbackEn: 'Choose a school',
    );
    final searchHint = textOrFallback(
      context,
      key: 'auth.register.schoolSearchHint',
      fallbackVi: 'Tìm theo tên hoặc mã trường',
      fallbackEn: 'Search by school name or code',
    );
    final emptyLabel = textOrFallback(
      context,
      key: 'auth.register.schoolEmpty',
      fallbackVi: 'Không tìm thấy trường phù hợp.',
      fallbackEn: 'No matching school found.',
    );
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredSchools = widget.schools.where((school) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return school.code.toLowerCase().contains(normalizedQuery) ||
          school.name.toLowerCase().contains(normalizedQuery);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: searchHint,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredSchools.isEmpty
                    ? Center(
                        child: Text(emptyLabel, textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        itemCount: filteredSchools.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final school = filteredSchools[index];
                          final isSelected =
                              widget.selectedSchool?.code == school.code;
                          return ListTile(
                            leading: const Icon(Icons.school_outlined),
                            title: Text(school.name),
                            subtitle: Text(school.code),
                            trailing: isSelected
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.of(context).pop(school),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
