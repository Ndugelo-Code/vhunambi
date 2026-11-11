import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explore/presentation/widgets/genre_glyph.dart';
import '../../../home/presentation/widgets/subscription_upgrade_modal.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/models/marketplace_models.dart';
import '../providers/beat_checkout_provider.dart';
import 'license_certificate_sheet.dart';

/// Multi-tier commercial licensing, Coin reconciliation & Vault unlock sheet (Phase 58).
Future<void> showBeatLicenseModal(
  BuildContext context,
  BeatListingEntity beat, {
  VoidCallback? onNavigateToLibrary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceModalOf(context),
    barrierColor: AppColors.surfaceCanvasOf(context).withValues(alpha: 0.72),
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.modalBorder,
      side: BorderSide(color: AppColors.borderSubtleOf(context)),
    ),
    builder: (_) => _BeatLicenseModalBody(
      beat: beat,
      hostContext: context,
      onNavigateToLibrary: onNavigateToLibrary,
    ),
  );
}

class _BeatLicenseModalBody extends ConsumerStatefulWidget {
  final BeatListingEntity beat;
  final BuildContext hostContext;
  final VoidCallback? onNavigateToLibrary;

  const _BeatLicenseModalBody({
    required this.beat,
    required this.hostContext,
    this.onNavigateToLibrary,
  });

  @override
  ConsumerState<_BeatLicenseModalBody> createState() =>
      _BeatLicenseModalBodyState();
}

class _BeatLicenseModalBodyState extends ConsumerState<_BeatLicenseModalBody> {
  bool _showLegalDeed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(beatCheckoutProvider.notifier).resetForBeat(widget.beat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(beatCheckoutProvider);
    final wallet = ref.watch(creatorWalletProvider);
    final ownerProfile = ref.watch(ownerProfileProvider);
    final engine = ref.read(licenseAgreementEngineProvider);

    final tiers = widget.beat.availableTiers.isNotEmpty
        ? widget.beat.availableTiers
        : BeatCheckoutTier.values;
    final tier = tiers.contains(checkout.selectedTier)
        ? checkout.selectedTier
        : tiers.first;
    final pricing = engine.calculateTierPricing(
      baseCredits: widget.beat.priceInCredits,
      tier: tier,
    );
    final affordability = engine.evaluateAffordability(
      walletCoins: wallet.userCoinsBalance,
      pricing: pricing,
    );
    final buyerHandle = ownerProfile.handle.isNotEmpty
        ? ownerProfile.handle
        : '@vhunambi_creator';
    final rights = engine.buildRightsProfile(
      beatTitle: widget.beat.title,
      producerName: widget.beat.producerName,
      producerHandle: widget.beat.producerHandle,
      buyerHandle: buyerHandle,
      genre: widget.beat.genre,
      bpm: widget.beat.bpm,
      musicalKey: widget.beat.musicalKey,
      pricing: pricing,
      issuedAtIso8601: DateTime.now().toUtc().toIso8601String(),
    );

    if (checkout.phase == CheckoutPhase.completed &&
        checkout.certificate != null) {
      return _CompletedReceiptView(
        beat: widget.beat,
        certificate: checkout.certificate!,
        package: checkout.package,
        onOpenCertificate: () {
          final cert = checkout.certificate!;
          Navigator.of(context).pop();
          if (widget.hostContext.mounted) {
            showLicenseCertificateSheet(widget.hostContext, certificate: cert);
          }
        },
        onOpenVault: () {
          Navigator.of(context).pop();
          widget.onNavigateToLibrary?.call();
        },
      );
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderActive,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppGradients.forGenre(widget.beat.genre),
                      borderRadius: AppRadius.squircleBorder,
                    ),
                    child: Icon(
                      exploreGenreGlyph(widget.beat.genre),
                      size: 24,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.beat.title,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${widget.beat.producerHandle} • ${widget.beat.bpmLabel} • ${widget.beat.musicalKey}',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Wallet Balance: ${wallet.userCoinsBalance} Coins',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.coinGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'SELECT LICENSE TIER',
                style: AppTypography.badge.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final option in tiers) ...[
                _TierOptionCard(
                  tier: option,
                  pricing: engine.calculateTierPricing(
                    baseCredits: widget.beat.priceInCredits,
                    tier: option,
                  ),
                  isSelected: option == tier,
                  isLockedExclusive: widget.beat.isExclusiveSold,
                  onTap: checkout.isBusy || widget.beat.isExclusiveSold
                      ? null
                      : () => ref
                          .read(beatCheckoutProvider.notifier)
                          .selectTier(option),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              const SizedBox(height: AppSpacing.xs),
              for (final bullet in rights.bulletRights)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: PhosphorIcon(
                          AppIcons.checkCircle,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(bullet, style: AppTypography.bodySmall),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('license_expand_terms_btn'),
                  onPressed: () =>
                      setState(() => _showLegalDeed = !_showLegalDeed),
                  icon: PhosphorIcon(
                    _showLegalDeed ? AppIcons.caretUp : AppIcons.caretDown,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    _showLegalDeed
                        ? 'Hide Legal Agreement Text'
                        : 'Read Full Legal Agreement',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_showLegalDeed)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.inputBorder,
                    border: Border.all(
                      color: AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Text(
                    rights.fullLegalText,
                    style: AppTypography.caption.copyWith(height: 1.45),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: affordability.canAfford
                      ? AppColors.surfaceSecondaryOf(context)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(
                    color: affordability.canAfford
                        ? AppColors.borderSubtleOf(context)
                        : AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      affordability.canAfford
                          ? 'Remaining balance after checkout: ${wallet.userCoinsBalance - pricing.grossCoins} Coins'
                          : 'Insufficient Coins: Short by ${affordability.deficitCoins} Coins (R${affordability.deficitZar.toStringAsFixed(2)})',
                      style: AppTypography.bodySmall.copyWith(
                        color: affordability.canAfford
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Royalty split: ${pricing.producerRoyaltyCoins} Coins (85%) to ${widget.beat.producerHandle} • ${pricing.platformFeeCoins} Coins platform fee',
                      style: AppTypography.caption,
                    ),
                    if (!affordability.canAfford) ...[
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('checkout_topup_btn'),
                          onPressed: () => SubscriptionUpgradeModal.show(context),
                          icon: const PhosphorIcon(
                            AppIcons.coins,
                            size: 16,
                            color: AppColors.coinGold,
                          ),
                          label: Text(
                            'Top Up Coins (ZAR)',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.coinGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            side: const BorderSide(color: AppColors.coinGold),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.pillBorder,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (checkout.errorMessage != null &&
                  checkout.phase == CheckoutPhase.failed) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  checkout.errorMessage!,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: checkout.isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('checkout_confirm_btn'),
                      onPressed: (!affordability.canAfford ||
                              checkout.isBusy ||
                              widget.beat.isExclusiveSold)
                          ? null
                          : () => ref
                              .read(beatCheckoutProvider.notifier)
                              .purchaseBeat(
                                beat: widget.beat,
                                tierOverride: tier,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        minimumSize: const Size(44, 46),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      child: checkout.isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brandContrast,
                              ),
                            )
                          : Text(
                              widget.beat.isExclusiveSold
                                  ? 'Sold Exclusive'
                                  : 'License • ${pricing.coinsLabel}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.brandContrast,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierOptionCard extends StatelessWidget {
  final BeatCheckoutTier tier;
  final LicenseTierPricing pricing;
  final bool isSelected;
  final bool isLockedExclusive;
  final VoidCallback? onTap;

  const _TierOptionCard({
    required this.tier,
    required this.pricing,
    required this.isSelected,
    required this.isLockedExclusive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.amberGlow
          : AppColors.surfaceElevatedOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(
          color: isSelected
              ? AppColors.brandPrimary
              : AppColors.borderSubtleOf(context),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        key: Key('license_tier_card_${tier.name}'),
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              isSelected
                  ? const PhosphorIcon(
                      AppIcons.checkCircle,
                      size: 20,
                      color: AppColors.brandPrimary,
                    )
                  : Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderActive,
                          width: 1.5,
                        ),
                      ),
                    ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tier.displayName,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tier.grantsExclusivity
                                ? AppColors.badgeCyanBg
                                : AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                          ),
                          child: Text(
                            isLockedExclusive ? 'SOLD' : tier.badgeLabel,
                            style: AppTypography.badge.copyWith(
                              color: tier.grantsExclusivity
                                  ? AppColors.badgeCyan
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tier.streamCapLabel} • ${tier.deliveryFormatLabel}',
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    pricing.coinsLabel,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    pricing.zarLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedReceiptView extends StatelessWidget {
  final BeatListingEntity beat;
  final SovereignLicenseCertificate certificate;
  final UnpackedBeatPackage? package;
  final VoidCallback onOpenCertificate;
  final VoidCallback onOpenVault;

  const _CompletedReceiptView({
    required this.beat,
    required this.certificate,
    required this.package,
    required this.onOpenCertificate,
    required this.onOpenVault,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: PhosphorIcon(
                PhosphorIconsFill.shieldCheck,
                size: 40,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'License Verified & Unpacked',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '"${beat.title}" (${certificate.tier.displayName}) and its local 44.1 kHz assets are now unlocked in your Library Vault.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certificate: ${certificate.certificateId}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SHA-256: ${certificate.shortHash}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.badgeCyan,
                    ),
                  ),
                  if (package != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      package!.hasStems
                          ? 'Delivered: Master 44.1 kHz WAV + 4 Isolated Stems'
                          : 'Delivered: Un-Tagged 44.1 kHz Studio Master',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('checkout_view_cert_btn'),
                    onPressed: onOpenCertificate,
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.fileText,
                      size: 16,
                    ),
                    label: const Text('View Certificate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('checkout_open_vault_btn'),
                    onPressed: onOpenVault,
                    icon: const PhosphorIcon(
                      AppIcons.navLibrary,
                      size: 16,
                      color: AppColors.brandContrast,
                    ),
                    label: const Text('Open Vault'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.brandContrast,
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
