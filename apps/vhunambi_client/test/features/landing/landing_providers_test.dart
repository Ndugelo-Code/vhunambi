import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/landing/domain/models/landing_models.dart';
import 'package:vhunambi_client/features/landing/presentation/providers/landing_providers.dart';

void main() {
  group('Landing pricing matrix', () {
    test('exposes four tiers with the blueprint pricing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final tiers = container.read(pricingTiersProvider);
      expect(tiers.length, 4);
      expect(tiers.map((tier) => tier.name), ['Free', 'Creator', 'Pro', 'Studio']);
      expect(tiers.map((tier) => tier.monthlyPrice), [0, 9, 29, 119]);
      expect(tiers.map((tier) => tier.yearlyPrice), [0, 7, 23, 95]);
      expect(tiers.where((tier) => tier.isPopular).single.name, 'Pro');
      expect(tiers.every((tier) => tier.features.isNotEmpty), isTrue);
      expect(tiers.every((tier) => tier.ctaLabel.isNotEmpty), isTrue);
    });

    test('priceFor honours the active billing cycle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final creator =
          container.read(pricingTiersProvider).firstWhere((t) => t.id == 'creator');
      final studio =
          container.read(pricingTiersProvider).firstWhere((t) => t.id == 'studio');

      expect(creator.priceFor(BillingCycle.monthly), 9);
      expect(creator.priceFor(BillingCycle.yearly), 7);
      expect(studio.priceFor(BillingCycle.yearly), 95);
    });

    test('billing cycle provider defaults to monthly and toggles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pricingBillingCycleProvider), BillingCycle.monthly);

      container.read(pricingBillingCycleProvider.notifier).state =
          BillingCycle.yearly;
      expect(container.read(pricingBillingCycleProvider), BillingCycle.yearly);

      expect(BillingCycle.values.length, 2);
    });

    test('PricingTier equality covers every field', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final tier = container.read(pricingTiersProvider).first;
      expect(tier, tier);
      expect(tier == container.read(pricingTiersProvider).last, isFalse);
      expect(tier.hashCode, tier.hashCode);
    });
  });

  group('Landing content providers', () {
    test('seeds four regional creator testimonials', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testimonials = container.read(creatorTestimonialsProvider);
      expect(testimonials.length, 4);
      expect(
        testimonials.map((item) => item.location),
        [
          'Thohoyandou, Limpopo',
          'Johannesburg, Gauteng',
          'Nairobi, Kenya',
          'Lagos, Nigeria',
        ],
      );
      expect(testimonials.every((item) => item.rating == 5), isTrue);
      expect(testimonials.first.initials, 'TM');
      expect(testimonials[1].initials, 'SK');
    });

    test('seeds six core value pillars', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pillars = container.read(valuePillarsProvider);
      expect(pillars.length, 6);
      expect(
        pillars.map((pillar) => pillar.title),
        containsAll([
          'AI-Powered Generation',
          'Multilingual Linguistic Engine',
          'African Genres First',
          'Collaborate in Real Time',
          'Download & Full Ownership',
          'Direct WhatsApp & Social Sharing',
        ]),
      );
    });

    test('social proof metrics match the blueprint counters', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final metrics = container.read(landingMetricsProvider);
      expect(metrics.length, 3);
      expect(metrics.map((metric) => metric.value), ['210+', '27+', '1,008']);
    });

    test('heritage showcase covers 20+ genres across five regional tabs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(landingRegionCatalog.length, 5);
      expect(landingRegionCatalog.first, 'All');
      expect(landingGenreCatalog.length, greaterThanOrEqualTo(20));
      expect(
        container.read(filteredLandingGenresProvider).length,
        landingGenreCatalog.length,
      );

      container.read(landingRegionProvider.notifier).state = 'South Africa';
      final southAfrican = container.read(filteredLandingGenresProvider);
      expect(southAfrican.length, 10);
      expect(southAfrican.first.name, 'Amapiano');
      expect(southAfrican.every((genre) => genre.region == 'South Africa'),
          isTrue);
    });

    test('hero prompt + showcase track defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(landingHeroPromptProvider), '');
      expect(container.read(landingShowcaseGenreProvider), 'Amapiano');

      final showcase = container.read(landingShowcaseTrackProvider);
      expect(showcase.title, 'Limpopo Sunset');
      expect(showcase.genre, 'Amapiano');
      expect(showcase.language, 'Tshivenḓa');
    });
  });
}
