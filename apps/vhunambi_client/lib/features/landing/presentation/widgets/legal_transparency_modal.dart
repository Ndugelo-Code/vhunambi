import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Interactive modal outlining Vhunambi's Creator Sovereignty, 85% Royalties,
/// Commercial Licensing, and Ethical Heritage IP Attribution (REQ-LEGAL-01 & 02).
class LegalTransparencyModal extends StatelessWidget {
  final String initialTitle;

  const LegalTransparencyModal({
    super.key,
    this.initialTitle = 'Creator Sovereignty & Legal Transparency',
  });

  static Future<void> show(
    BuildContext context, {
    String initialTitle = 'Creator Sovereignty & Legal Transparency',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LegalTransparencyModal(initialTitle: initialTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      key: const Key('legal_transparency_modal'),
      height: mediaQuery.size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtleOf(context), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtleOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsFill.shieldCheck,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        initialTitle,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      Text(
                        'Vhunambi African Music Protocol · Version 2026.1',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.x,
                    size: 20,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  context,
                  icon: PhosphorIconsFill.currencyCircleDollar,
                  iconColor: AppColors.coinGold,
                  title: '1. 85% Creator Sovereign Royalties',
                  content:
                      'All commercial track licensing, open-verse tips, and sound pack royalties credit 85% of gross revenue directly to the creator\'s Sovereign Wallet. Vhunambi retains 15% exclusively to fund GPU inference clusters, mobile mastering servers, and global Bantu catalog preservation.',
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: PhosphorIconsFill.musicNotesSimple,
                  iconColor: AppColors.brandPrimary,
                  title: '2. Commercial Licensing & Stem Rights',
                  content:
                      'Buyers receive an irrevocable, non-exclusive commercial sync license for digital streaming, live performance, broadcasting, and video game synchronization. Originating creators retain master attribution and credit across all derivative remixes.',
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: PhosphorIconsFill.fingerprint,
                  iconColor: AppColors.accentElectric,
                  title: '3. Bantu Heritage & Voice Attribution Protections',
                  content:
                      'AI LoRAs and Voice DNA models trained on cultural vocal roots (Tshivenḓa, isiZulu, Sepedi, Xitsonga, etc.) maintain cryptographic lineage hashing. Traditional singers and cultural elders maintain perpetual royalty rights to their sampled vocal signatures.',
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  icon: PhosphorIconsFill.bank,
                  iconColor: AppColors.success,
                  title: '4. Direct South African Banking (SARB Compliant)',
                  content:
                      'Creator payouts are settled in South African Rand (ZAR) via South African Reserve Bank (SARB) compliant EFT clearing to Capitec, Standard Bank, FNB, Nedbank, Absa, and TymeBank with zero hidden foreign exchange fees.',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('legal_modal_acknowledge_btn'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'I Understand & Agree',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandContrast,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderSubtleOf(context),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
