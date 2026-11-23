import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/auth/sovereign_password_policy.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';

/// Modal sheet for Sovereign Creator authentication, registration, and
/// debug/QA seeded studio identity switching (`Phase 61`, hardened `Phase 76`).
class SovereignAuthSheet extends ConsumerStatefulWidget {
  @visibleForTesting
  final bool? enableDemoQuickSwitchOverride;

  const SovereignAuthSheet({super.key, this.enableDemoQuickSwitchOverride});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SovereignAuthSheet(),
    );
  }

  @override
  ConsumerState<SovereignAuthSheet> createState() => _SovereignAuthSheetState();
}

class _SovereignAuthSheetState extends ConsumerState<SovereignAuthSheet> {
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  final _identifierController = TextEditingController();
  final _handleController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _handleController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickSwitch(String handle, String displayName) async {
    if (_isSubmitting) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authSessionProvider.notifier)
          .switchToSeededCreator(handle: handle, displayName: displayName);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on SovereignAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    HapticFeedback.lightImpact();

    final password = _passwordController.text;
    if (_isRegisterMode) {
      final handle = _handleController.text.trim();
      final email = _emailController.text.trim();
      if (handle.isEmpty || email.isEmpty || !email.contains('@')) {
        setState(() {
          _errorMessage =
              'Enter handle, valid email, and password (at least 8 characters).';
        });
        return;
      }
      final pwdEval = SovereignPasswordPolicy.evaluate(password);
      if (!pwdEval.isValid) {
        setState(() {
          _errorMessage = pwdEval.firstFailureMessage;
        });
        return;
      }
    } else {
      final identifier = _identifierController.text.trim();
      if (identifier.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Enter your handle/email and password to continue.';
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(authSessionProvider.notifier);
      if (_isRegisterMode) {
        await notifier.signUp(
          handle: _handleController.text.trim(),
          email: _emailController.text.trim(),
          password: password,
          displayName: _displayNameController.text.trim(),
        );
      } else {
        await notifier.signIn(
          identifier: _identifierController.text.trim(),
          password: password,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on SovereignAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to authenticate: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final activeCreatorId = ref.watch(currentCreatorIdProvider);
    final showDemoQuickSwitch =
        widget.enableDemoQuickSwitchOverride ?? kEnableDemoCreatorQuickSwitch;

    return VhunambiGlassSurface(
      key: const Key('sovereign_auth_glass_surface'),
      variant: VhunambiGlassVariant.chrome,
      borderRadius: AppRadius.modalBorder,
      enableLiveBlur: false,
      borderColorOverride: AppColors.borderSubtleOf(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondaryOf(context).withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsFill.shieldCheck,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sovereign Creator Identity',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('auth_close_btn'),
                    tooltip: 'Close',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: PhosphorIcon(
                      AppIcons.close,
                      size: 20,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2-Way Segmented Mode Selector
              VhunambiGlassSurface(
                variant: VhunambiGlassVariant.pill,
                height: 44,
                padding: const EdgeInsets.all(4),
                enableLiveBlur: false,
                borderColorOverride: AppColors.borderSubtleOf(context),
                child: Row(
                  children: [
                    _buildModeTab(
                      context: context,
                      key: const Key('auth_tab_signin'),
                      label: 'Sign In',
                      selected: !_isRegisterMode,
                      onTap: () => setState(() {
                        _isRegisterMode = false;
                        _errorMessage = null;
                      }),
                    ),
                    _buildModeTab(
                      context: context,
                      key: const Key('auth_tab_register'),
                      label: 'Create Account',
                      selected: _isRegisterMode,
                      onTap: () => setState(() {
                        _isRegisterMode = true;
                        _errorMessage = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (showDemoQuickSwitch) ...[
                Text(
                  'QUICK STUDIO CREATORS',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildQuickChip(
                      context: context,
                      key: const Key('auth_quick_chip_cern'),
                      handle: '@cern',
                      displayName: 'cern',
                      isActive: activeCreatorId == 'creator_cern',
                    ),
                    _buildQuickChip(
                      context: context,
                      key: const Key('auth_quick_chip_makhadzi'),
                      handle: '@makhadzi',
                      displayName: 'Makhadzi',
                      isActive: activeCreatorId == 'creator_makhadzi',
                    ),
                    _buildQuickChip(
                      context: context,
                      key: const Key('auth_quick_chip_sigwa'),
                      handle: '@sigwa',
                      displayName: 'Sigwa Inaf',
                      isActive: activeCreatorId == 'creator_sigwa',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              if (!_isRegisterMode) ...[
                _buildField(
                  context: context,
                  fieldKey: const Key('auth_identifier_input'),
                  controller: _identifierController,
                  label: 'Handle or Email',
                  hint: '@cern or creator@vhunambi.za',
                  icon: PhosphorIconsRegular.at,
                ),
              ] else ...[
                _buildField(
                  context: context,
                  fieldKey: const Key('auth_handle_input'),
                  controller: _handleController,
                  label: 'Creator Handle',
                  hint: '@your_handle',
                  icon: PhosphorIconsRegular.at,
                ),
                const SizedBox(height: 10),
                _buildField(
                  context: context,
                  fieldKey: const Key('auth_display_name_input'),
                  controller: _displayNameController,
                  label: 'Display Name',
                  hint: 'Artist or Producer Name',
                  icon: PhosphorIconsRegular.user,
                ),
                const SizedBox(height: 10),
                _buildField(
                  context: context,
                  fieldKey: const Key('auth_email_input'),
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'studio@vhunambi.za',
                  icon: PhosphorIconsRegular.envelopeSimple,
                ),
              ],
              const SizedBox(height: 10),
              _buildField(
                context: context,
                fieldKey: const Key('auth_password_input'),
                controller: _passwordController,
                label: _isRegisterMode
                    ? 'Password (min 8 chars, strong)'
                    : 'Password',
                hint: 'Enter password',
                icon: PhosphorIconsRegular.lockKey,
                obscureText: _obscurePassword,
                onChanged: _isRegisterMode ? (_) => setState(() {}) : null,
                suffixIcon: IconButton(
                  key: const Key('auth_password_visibility_btn'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: PhosphorIcon(
                    _obscurePassword
                        ? PhosphorIconsRegular.eye
                        : PhosphorIconsRegular.eyeSlash,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              if (_isRegisterMode) ...[
                const SizedBox(height: 8),
                _buildPasswordRequirementsRow(context),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                VhunambiGlassSurface(
                  key: const Key('auth_error_banner'),
                  variant: VhunambiGlassVariant.card,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  borderRadius: AppRadius.inputBorder,
                  enableLiveBlur: false,
                  tintAccent: AppColors.error,
                  borderColorOverride: AppColors.error.withValues(alpha: 0.45),
                  child: Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsFill.warningCircle,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('auth_submit_btn'),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.brandContrast,
                          ),
                        )
                      : PhosphorIcon(
                          _isRegisterMode
                              ? PhosphorIconsFill.userPlus
                              : PhosphorIconsFill.signIn,
                          size: 16,
                          color: AppColors.brandContrast,
                        ),
                  label: Text(
                    _isRegisterMode
                        ? 'Create Sovereign Account'
                        : 'Sign In to Studio',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    minimumSize: const Size.fromHeight(46),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
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

  Widget _buildModeTab({
    required BuildContext context,
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.brandContrast
                  : AppColors.textPrimaryOf(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required BuildContext context,
    required Key key,
    required String handle,
    required String displayName,
    required bool isActive,
  }) {
    return ActionChip(
      key: key,
      onPressed: _isSubmitting
          ? null
          : () => _handleQuickSwitch(handle, displayName),
      backgroundColor: isActive
          ? AppColors.brandPrimary.withAlpha(32)
          : AppColors.surfaceElevatedOf(context),
      side: BorderSide(
        color: isActive
            ? AppColors.brandPrimary
            : AppColors.borderSubtleOf(context),
      ),
      avatar: PhosphorIcon(
        isActive
            ? PhosphorIconsFill.checkCircle
            : PhosphorIconsRegular.userCircle,
        size: 14,
        color: isActive
            ? AppColors.brandPrimary
            : AppColors.textSecondaryOf(context),
      ),
      label: Text(
        handle,
        style: AppTypography.caption.copyWith(
          color: isActive
              ? AppColors.brandPrimary
              : AppColors.textPrimaryOf(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPasswordRequirementsRow(BuildContext context) {
    final eval = SovereignPasswordPolicy.evaluate(_passwordController.text);
    final items = <({Key key, String label, bool met})>[
      (
        key: const Key('auth_pwd_req_len'),
        label: '8+ chars',
        met: eval.hasMinLength,
      ),
      (
        key: const Key('auth_pwd_req_upper'),
        label: 'A-Z',
        met: eval.hasUppercase,
      ),
      (
        key: const Key('auth_pwd_req_lower'),
        label: 'a-z',
        met: eval.hasLowercase,
      ),
      (key: const Key('auth_pwd_req_digit'), label: '0-9', met: eval.hasDigit),
      (
        key: const Key('auth_pwd_req_symbol'),
        label: 'Symbol',
        met: eval.hasSymbol,
      ),
    ];

    return Wrap(
      key: const Key('auth_password_requirements_wrap'),
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            key: item.key,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.met
                  ? AppColors.brandPrimary.withAlpha(28)
                  : AppColors.surfaceElevatedOf(context),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: item.met
                    ? AppColors.brandPrimary
                    : AppColors.borderSubtleOf(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  item.met
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsRegular.circle,
                  size: 12,
                  color: item.met
                      ? AppColors.brandPrimary
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: item.met ? FontWeight.w700 : FontWeight.w500,
                    color: item.met
                        ? AppColors.brandPrimary
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildField({
    required BuildContext context,
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.textPrimaryOf(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTypography.caption.copyWith(
          color: AppColors.textSecondaryOf(context),
        ),
        hintStyle: AppTypography.caption.copyWith(
          color: AppColors.textSecondaryOf(context).withAlpha(140),
        ),
        prefixIcon: PhosphorIcon(
          icon,
          size: 16,
          color: AppColors.textSecondaryOf(context),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceElevatedOf(context),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: AppColors.borderSubtleOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(color: AppColors.borderSubtleOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(
            color: AppColors.textPrimaryOf(context).withValues(alpha: 0.22),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}
