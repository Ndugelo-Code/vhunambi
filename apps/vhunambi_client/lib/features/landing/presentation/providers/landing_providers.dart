import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/track.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../domain/models/landing_models.dart';

/// Active pricing cadence (REQ-MKT-11).
final pricingBillingCycleProvider =
    StateProvider<BillingCycle>((ref) => BillingCycle.monthly);

/// The four subscription tiers (design.md §2.2).
final pricingTiersProvider = Provider<List<PricingTier>>((ref) {
  return const [
    PricingTier(
      id: 'free',
      name: 'Free',
      monthlyPrice: 0,
      yearlyPrice: 0,
      songAllowance: '10 songs/mo',
      audioQuality: 'Standard MP3',
      licenseScope: 'Community Public Feed',
      features: [
        '10 songs per month',
        'Standard MP3 bitrate',
        'Community generation feed',
        'Basic genre selection',
      ],
      ctaLabel: 'Get Started',
    ),
    PricingTier(
      id: 'creator',
      name: 'Creator',
      monthlyPrice: 9,
      yearlyPrice: 7,
      songAllowance: '400 songs/mo',
      audioQuality: 'High Quality MP3',
      licenseScope: 'Commercial Sync',
      features: [
        '400 songs per month',
        'High Quality 320kbps MP3',
        'Priority generation queue',
        '100% Commercial rights',
        'Private generation mode',
      ],
      ctaLabel: 'Subscribe',
    ),
    PricingTier(
      id: 'pro',
      name: 'Pro',
      monthlyPrice: 29,
      yearlyPrice: 23,
      songAllowance: '2,000 songs/mo',
      audioQuality: 'Lossless WAV',
      licenseScope: 'Full Commercial & Stems',
      features: [
        '2,000 songs per month',
        'Lossless 24-bit WAV',
        '4-Stem isolation (Vocals, Drums, Bass, Instruments)',
        'Full commercial license + split sheets',
        'Beat marketplace listing privileges',
      ],
      isPopular: true,
      ctaLabel: 'Go Pro ★',
    ),
    PricingTier(
      id: 'studio',
      name: 'Studio',
      monthlyPrice: 119,
      yearlyPrice: 95,
      songAllowance: '20,000 songs/mo',
      audioQuality: 'Lossless WAV + MIDI',
      licenseScope: 'Team API & White-label',
      features: [
        '20,000 songs per month',
        'Lossless WAV + MIDI stems',
        'Multi-seat team workspace',
        'Dedicated audio synthesis API',
        'Enterprise licensing support',
      ],
      ctaLabel: 'Contact Us',
    ),
  ];
});

/// Verified creator testimonials (REQ-MKT-10).
final creatorTestimonialsProvider = Provider<List<CreatorTestimonial>>((ref) {
  return const [
    CreatorTestimonial(
      id: 't1',
      authorName: 'Thabo M.',
      handle: '@thabo_thohoyandou',
      location: 'Thohoyandou, Limpopo',
      quote:
          'Finally, an AI that understands Tshivenḓa phonetics and authentic African meters without robotic artifacts.',
    ),
    CreatorTestimonial(
      id: 't2',
      authorName: 'Sipho Khumalo',
      handle: '@sipho_beats',
      location: 'Johannesburg, Gauteng',
      quote:
          'The log drum synthesis in Amapiano mode is indistinguishable from my custom FL Studio templates.',
    ),
    CreatorTestimonial(
      id: 't3',
      authorName: 'Amina Osei',
      handle: '@amina_music',
      location: 'Nairobi, Kenya',
      quote:
          'A revelation for Gengetone and Bongo Flava rhythm production. The speed of workflow is incredible.',
    ),
    CreatorTestimonial(
      id: 't4',
      authorName: 'Adeola Balogun',
      handle: '@adeola_sound',
      location: 'Lagos, Nigeria',
      quote:
          'Afrobeats brass syncopation and Pidgin cadence are dead-on. High quality output every time.',
    ),
  ];
});

/// Six core capability pillars (REQ-MKT-09).
final valuePillarsProvider = Provider<List<ValuePillar>>((ref) {
  return const [
    ValuePillar(
      title: 'AI-Powered Generation',
      description:
          'Turn a single sentence into a finished master with studio-grade mixing.',
      iconData: Icons.auto_awesome,
    ),
    ValuePillar(
      title: 'Multilingual Linguistic Engine',
      description:
          '25+ indigenous African languages with authentic pronunciation and cadence.',
      iconData: Icons.translate_rounded,
    ),
    ValuePillar(
      title: 'African Genres First',
      description:
          'Amapiano, Gqom, Kwaito, Maskandi and 20+ regional styles tuned by producers.',
      iconData: Icons.public_rounded,
    ),
    ValuePillar(
      title: 'Collaborate in Real Time',
      description:
          'Invite vocalists and producers into a shared session workspace.',
      iconData: Icons.groups_rounded,
    ),
    ValuePillar(
      title: 'Download & Full Ownership',
      description:
          'Export lossless WAV and stems with 100% commercial rights retained.',
      iconData: Icons.download_rounded,
    ),
    ValuePillar(
      title: 'Direct WhatsApp & Social Sharing',
      description: 'Share previews straight into WhatsApp, TikTok and Instagram.',
      iconData: Icons.share_rounded,
    ),
  ];
});

/// Social proof metrics banner (REQ-MKT-08).
final landingMetricsProvider = Provider<List<LandingMetric>>((ref) {
  return const [
    LandingMetric(value: '210+', label: 'Songs Created'),
    LandingMetric(value: '27+', label: 'Active Musicians & Producers'),
    LandingMetric(value: '1,008', label: 'Total Community Likes'),
  ];
});

/// Active regional tab of the heritage genre showcase (REQ-MKT-09).
final landingRegionProvider = StateProvider<String>((ref) => 'All');

/// Heritage genres matching the active regional tab.
final filteredLandingGenresProvider = Provider<List<LandingGenre>>((ref) {
  final region = ref.watch(landingRegionProvider);
  if (region == 'All') return landingGenreCatalog;
  return List.unmodifiable(
    landingGenreCatalog.where((genre) => genre.region == region),
  );
});

/// Hero quick-prompt draft bound to the landing input bar (REQ-MKT-07).
final landingHeroPromptProvider = StateProvider<String>((ref) => '');

/// Currently auditioned heritage genre chip (REQ-MKT-09).
final landingShowcaseGenreProvider =
    StateProvider<String>((ref) => 'Amapiano');

/// Cinematic hero sample track (REQ-MKT-07).
final landingShowcaseTrackProvider = Provider<Track>((ref) {
  return const Track(
    id: 'landing_showcase_limpopo_sunset',
    title: 'Limpopo Sunset',
    creatorName: 'Vhunambi Studio',
    creatorHandle: '@vhunambi',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    duration: Duration(minutes: 3, seconds: 24),
    audioUrl: 'https://cdn.vhunambi.com/audio/limpopo-sunset.mp3',
    likeCount: 2108,
    playCount: 9042,
    mood: 'Uplifting',
  );
});

/// Auditions the hero showcase track in the persistent player dock.
void auditionLandingShowcase(WidgetRef ref) {
  ref
      .read(playerStateProvider.notifier)
      .playTrack(ref.read(landingShowcaseTrackProvider));
}

/// Auditions the first marketplace listing matching [genre] and returns its
/// title, or `null` when no preview exists for that genre yet (REQ-MKT-09).
String? auditionGenrePreview(WidgetRef ref, String genre) {
  final match = ref
      .read(marketplaceBeatsProvider)
      .where((beat) => beat.genre.toLowerCase() == genre.toLowerCase());

  if (match.isEmpty) return null;

  final beat = match.first;
  auditionBeat(ref, beat);
  return beat.title;
}

/// Pushes the hero prompt into the Studio cockpit and returns the draft.
/// Returns `null` when the field is empty (REQ-MKT-07).
String? submitLandingPrompt(WidgetRef ref) {
  final draft = ref.read(landingHeroPromptProvider).trim();
  if (draft.isEmpty) return null;

  ref.read(studioFormProvider.notifier).updatePrompt(draft);
  return draft;
}
