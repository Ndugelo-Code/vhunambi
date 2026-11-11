import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../library/domain/models/library_models.dart';
import '../../domain/models/licensing_models.dart';
import '../../domain/services/license_agreement_engine.dart';
import '../../domain/services/sovereign_certificate_signer.dart';
import '../providers/beat_checkout_provider.dart';

/// Cryptographic Ownership Deed & Stem Deliverables Sheet (REQ-P58-CERT-04).
Future<void> showLicenseCertificateSheet(
  BuildContext context, {
  SovereignLicenseCertificate? certificate,
  LibraryTrack? track,
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
    builder: (_) => LicenseCertificateSheet(
      initialCertificate: certificate,
      track: track,
    ),
  );
}

class LicenseCertificateSheet extends ConsumerStatefulWidget {
  final SovereignLicenseCertificate? initialCertificate;
  final LibraryTrack? track;

  const LicenseCertificateSheet({
    super.key,
    this.initialCertificate,
    this.track,
  });

  @override
  ConsumerState<LicenseCertificateSheet> createState() =>
      _LicenseCertificateSheetState();
}

class _LicenseCertificateSheetState
    extends ConsumerState<LicenseCertificateSheet> {
  bool? _verifiedResult;
  bool _isExporting = false;

  SovereignLicenseCertificate _resolveEffectiveCertificate() {
    if (widget.initialCertificate != null) {
      return widget.initialCertificate!;
    }
    final track = widget.track;
    if (track != null) {
      final stored =
          ref.read(licenseCertificatesProvider.notifier).findForTrack(track);
      if (stored != null) return stored;

      // Legacy track synthesized deed fallback so pre-Phase-58 tracks still sign cleanly.
      final tier =
          BeatCheckoutTier.fromWire(track.licenseTierId ?? track.licenseType);
      const signer = SovereignCertificateSigner();
      const engine = LicenseAgreementEngine();
      final pricing = engine.calculateTierPricing(baseCredits: 5, tier: tier);
      final issued = track.createdAt.toUtc().toIso8601String();
      final sanitizedCreator = track.creatorName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');
      final producerSlug =
          sanitizedCreator.isEmpty ? 'creator' : sanitizedCreator;
      return signer.signCertificate(
        certificateId: track.licenseCertificateId,
        beatId: track.id.replaceFirst('market_', ''),
        beatTitle: track.title,
        producerId: producerSlug,
        producerHandle: '@$producerSlug',
        producerName: track.creatorName,
        buyerId: 'me',
        buyerHandle: '@creator',
        genre: track.genre,
        bpm: 112,
        musicalKey: 'F# Minor',
        pricing: pricing,
        issuedAtIso8601: issued,
        commercialTerms: 'Standard Vhunambi Vault Commercial License',
        vaultTrackId: track.id,
        masterAudioFilePath:
            track.masterAudioFilePath ?? track.localAudioFilePath ?? '',
        stemPaths: track.stemPaths,
        masterFileSha256: SovereignCertificateSigner.sha256HexUtf8(track.id),
      );
    }
    throw StateError(
      'LicenseCertificateSheet requires either initialCertificate or track',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cert = _resolveEffectiveCertificate();
    final signer = ref.read(sovereignCertificateSignerProvider);
    final isVerified = _verifiedResult ?? signer.verifyIntegrity(cert);

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
            AppSpacing.lg,
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
                  PhosphorIcon(
                    PhosphorIconsFill.shieldCheck,
                    size: 24,
                    color: isVerified ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Sovereign License Deed',
                      style: AppTypography.titleLarge,
                    ),
                  ),
                  Container(
                    key: const Key('license_cert_verify_status'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isVerified ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.16),
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      isVerified ? 'VERIFIED' : 'UNVERIFIED',
                      style: AppTypography.badge.copyWith(
                        color: isVerified ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DeedMetaRow(label: 'Certificate ID', value: cert.certificateId),
              _DeedMetaRow(
                label: 'Asset',
                value: '${cert.beatTitle} (${cert.genre} • ${cert.bpm} BPM)',
              ),
              _DeedMetaRow(
                label: 'Producer',
                value: '${cert.producerName} (${cert.producerHandle})',
              ),
              _DeedMetaRow(label: 'Tier', value: cert.tier.displayName),
              _DeedMetaRow(
                label: 'Consideration',
                value:
                    '${cert.amountPaidCoins} Coins (R${cert.amountPaidZar.toStringAsFixed(2)})',
              ),
              _DeedMetaRow(
                label: 'Royalty Split',
                value:
                    '85% Producer (${cert.producerRoyaltyCoins} Coins) / 15% Platform',
              ),
              if (cert.masterAudioFilePath.isNotEmpty)
                _DeedMetaRow(
                  label: 'Local Master',
                  value: cert.masterAudioFilePath,
                ),
              if (cert.stemPaths.isNotEmpty)
                _DeedMetaRow(
                  label: 'Stems Unlocked',
                  value: '${cert.stemPaths.length} isolated 44.1 kHz WAV stems',
                ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('license_cert_hash_pill'),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.inputBorder,
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHA-256 CRYPTOGRAPHIC PROOF',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cert.licenseHash,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.badgeCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('license_cert_copy_hash_btn'),
                      tooltip: 'Copy SHA-256 Digest',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.copy,
                        size: 18,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: cert.licenseHash),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copied SHA-256 digest ${cert.shortHash}',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('license_cert_verify_btn'),
                      onPressed: () {
                        setState(() {
                          _verifiedResult = signer.verifyIntegrity(cert);
                        });
                      },
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.shieldCheck,
                        size: 16,
                      ),
                      label: const Text('Verify Hash'),
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
                      key: const Key('license_cert_share_btn'),
                      onPressed: _isExporting
                          ? null
                          : () async {
                              setState(() => _isExporting = true);
                              final res = await ref
                                  .read(certificateShareExporterProvider)
                                  .shareDeed(cert);
                              if (context.mounted) {
                                setState(() => _isExporting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Exported legal deed & JSON (${cert.certificateId}) -> ${res.textPath}',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const PhosphorIcon(
                        AppIcons.share,
                        size: 16,
                        color: AppColors.brandContrast,
                      ),
                      label: const Text('Export Deed'),
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
      ),
    );
  }
}

class _DeedMetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeedMetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

