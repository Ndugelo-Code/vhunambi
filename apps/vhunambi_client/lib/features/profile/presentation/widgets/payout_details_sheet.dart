import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

/// Sovereign creator royalty payout modal collecting and validating South African banking KYC (Phase 41 REQ-PAYOUT-UI-01).
class PayoutDetailsSheet extends ConsumerStatefulWidget {
  const PayoutDetailsSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PayoutDetailsSheet(),
    );
  }

  @override
  ConsumerState<PayoutDetailsSheet> createState() => _PayoutDetailsSheetState();
}

class _PayoutDetailsSheetState extends ConsumerState<PayoutDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedBank;
  PayoutGatewayRail _selectedRail = PayoutGatewayRail.capitecPay;
  late final TextEditingController _holderController;
  late final TextEditingController _accountController;
  late final TextEditingController _branchController;
  late final TextEditingController _amountController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedBank = 'Capitec Bank';
    _selectedRail = PayoutGatewayRail.capitecPay;
    _holderController = TextEditingController(text: 'Ndugelo Musician');
    _accountController = TextEditingController(text: '1092837465');
    _branchController = TextEditingController(
      text: SaBankRegistry.universalBranchCodeFor(_selectedBank),
    );

    final currentEarned = ref.read(creatorWalletProvider).creatorEarnedZar;
    _amountController = TextEditingController(
      text: currentEarned.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _branchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onBankChanged(String newBank) {
    setState(() {
      _selectedBank = newBank;
      _branchController.text = SaBankRegistry.universalBranchCodeFor(newBank);
      if (!SaBankRegistry.supportsRail(newBank, _selectedRail)) {
        _selectedRail = PayoutGatewayRail.ozow;
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final wallet = ref.read(creatorWalletProvider);

    if (amount < 50.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum withdrawal threshold is R50.00'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (amount > wallet.creatorEarnedZar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Requested amount exceeds available balance.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final details = CreatorBankingDetails(
      bankName: _selectedBank,
      accountHolder: _holderController.text.trim(),
      accountNumber: _accountController.text.trim(),
      branchCode: _branchController.text.trim(),
      payoutMethod: '${_selectedRail.displayName} ($_selectedBank)',
      paymentRail: _selectedRail,
    );

    final success = await ref
        .read(creatorWalletProvider.notifier)
        .requestBankingPayout(amountZar: amount, bankingDetails: details);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payout of R${amount.toStringAsFixed(2)} to $_selectedBank via ${_selectedRail.shortLabel} initiated!',
          ),
          backgroundColor: AppColors.brandPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final wallet = ref.watch(creatorWalletProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtleOf(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const PhosphorIcon(
                        PhosphorIconsRegular.bank,
                        color: AppColors.brandPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Out Creator Royalties',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          Text(
                            'Direct South African EFT & Instant Clearance',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Balance summary pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Royalties:',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      Text(
                        'R${wallet.creatorEarnedZar.toStringAsFixed(2)}',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Bank Selection
                Text(
                  'Select Bank',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  key: const Key('payout_bank_dropdown'),
                  initialValue: _selectedBank,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondaryOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                  ),
                  items: SaBankRegistry.banks.map((bank) {
                    return DropdownMenuItem<String>(
                      value: bank.canonicalName,
                      child: Text(
                        bank.canonicalName,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) _onBankChanged(val);
                  },
                ),
                const SizedBox(height: 8),

                // Settlement Rail Selector (Phase 59)
                Text(
                  'Settlement Rail (${_selectedRail.estimatedSettlement})',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: PayoutGatewayRail.values.map((rail) {
                    final supported = SaBankRegistry.supportsRail(
                      _selectedBank,
                      rail,
                    );
                    final isSelected = _selectedRail == rail;
                    return InkWell(
                      key: Key('payout_rail_${rail.wireId}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: supported
                          ? () => setState(() => _selectedRail = rail)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.surfaceSecondaryOf(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.borderSubtleOf(context),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              rail.isInstant
                                  ? PhosphorIconsRegular.lightning
                                  : PhosphorIconsRegular.clock,
                              size: 13,
                              color: isSelected
                                  ? AppColors.brandContrast
                                  : (supported
                                        ? AppColors.brandPrimary
                                        : AppColors.textTertiary),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rail.shortLabel,
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.brandContrast
                                    : (supported
                                          ? AppColors.textPrimaryOf(context)
                                          : AppColors.textTertiary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Account Holder Input
                Text(
                  'Account Holder Name',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  key: const Key('payout_account_holder_input'),
                  controller: _holderController,
                  style: TextStyle(color: AppColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'e.g. Ndugelo Musician',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondaryOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Enter a valid account holder name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Account Number & Branch Code row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Number',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            key: const Key('payout_account_number_input'),
                            controller: _accountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '9-11 Digits',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceSecondaryOf(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.borderSubtleOf(context),
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().length < 8) {
                                return 'Enter 8-11 digits';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Branch Code',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            key: const Key('payout_branch_code_input'),
                            controller: _branchController,
                            readOnly: true,
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceSecondaryOf(
                                context,
                              ).withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppColors.borderSubtleOf(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Withdrawal Amount
                Text(
                  'Withdrawal Amount (ZAR)',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  key: const Key('payout_amount_input'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: AppColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: 'R ',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceSecondaryOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Submit Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    key: const Key('payout_confirm_btn'),
                    onPressed: _isSubmitting ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandContrast,
                            ),
                          )
                        : const Text(
                            'Confirm Payout',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
