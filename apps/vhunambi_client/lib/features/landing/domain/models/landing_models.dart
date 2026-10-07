import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Subscription billing cadence driving the pricing matrix (REQ-MKT-11).
enum BillingCycle {
  monthly,
  yearly,
}

/// Subscription tier card record (design.md §1.2).
@immutable
class PricingTier {
  final String id;
  final String name;
  final int monthlyPrice;
  final int yearlyPrice;
  final String songAllowance;
  final String audioQuality;
  final String licenseScope;
  final List<String> features;
  final bool isPopular;
  final String ctaLabel;

  const PricingTier({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.songAllowance,
    required this.audioQuality,
    required this.licenseScope,
    required this.features,
    this.isPopular = false,
    required this.ctaLabel,
  });

  int priceFor(BillingCycle cycle) =>
      cycle == BillingCycle.yearly ? yearlyPrice : monthlyPrice;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PricingTier &&
        other.id == id &&
        other.name == name &&
        other.monthlyPrice == monthlyPrice &&
        other.yearlyPrice == yearlyPrice &&
        other.songAllowance == songAllowance &&
        other.audioQuality == audioQuality &&
        other.licenseScope == licenseScope &&
        listEquals(other.features, features) &&
        other.isPopular == isPopular &&
        other.ctaLabel == ctaLabel;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        monthlyPrice,
        yearlyPrice,
        songAllowance,
        audioQuality,
        licenseScope,
        Object.hashAll(features),
        isPopular,
        ctaLabel,
      );
}

/// Verified creator review card record (REQ-MKT-10).
@immutable
class CreatorTestimonial {
  final String id;
  final String authorName;
  final String handle;
  final String location;
  final String quote;
  final int rating;
  final String? avatarUrl;

  const CreatorTestimonial({
    required this.id,
    required this.authorName,
    required this.handle,
    required this.location,
    required this.quote,
    this.rating = 5,
    this.avatarUrl,
  });

  String get initials {
    final parts = authorName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'V';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final last = parts.last;
    return (parts.first.substring(0, 1) +
            (last.isEmpty ? '' : last.substring(0, 1)))
        .toUpperCase();
  }
}

/// Core platform capability card (REQ-MKT-09).
@immutable
class ValuePillar {
  final String title;
  final String description;
  final IconData iconData;

  const ValuePillar({
    required this.title,
    required this.description,
    required this.iconData,
  });
}

/// Social-proof metric banner entry (REQ-MKT-08).
@immutable
class LandingMetric {
  final String value;
  final String label;

  const LandingMetric({required this.value, required this.label});
}

/// African heritage genre tile with its regional grouping (REQ-MKT-09).
@immutable
class LandingGenre {
  final String name;
  final String region;

  const LandingGenre(this.name, this.region);
}

/// Regional tab selector for the heritage showcase.
const List<String> landingRegionCatalog = [
  'All',
  'South Africa',
  'West Africa',
  'East Africa',
  'Central Africa',
];

/// 20+ African musical heritage genres grouped by region.
const List<LandingGenre> landingGenreCatalog = [
  LandingGenre('Amapiano', 'South Africa'),
  LandingGenre('Kwaito', 'South Africa'),
  LandingGenre('Gqom', 'South Africa'),
  LandingGenre('Maskandi', 'South Africa'),
  LandingGenre('Mbaqanga', 'South Africa'),
  LandingGenre('Marabi', 'South Africa'),
  LandingGenre('Bubblegum', 'South Africa'),
  LandingGenre('Afro House', 'South Africa'),
  LandingGenre('Afro Soul', 'South Africa'),
  LandingGenre('Afro Jazz', 'South Africa'),
  LandingGenre('Afrobeats', 'West Africa'),
  LandingGenre('Highlife', 'West Africa'),
  LandingGenre('Fuji', 'West Africa'),
  LandingGenre('Hiplife', 'West Africa'),
  LandingGenre('Apala', 'West Africa'),
  LandingGenre('Afro-Fusion', 'West Africa'),
  LandingGenre('Bongo Flava', 'East Africa'),
  LandingGenre('Gengetone', 'East Africa'),
  LandingGenre('Taarab', 'East Africa'),
  LandingGenre('Benga', 'East Africa'),
  LandingGenre('Singeli', 'East Africa'),
  LandingGenre('Afro-Arabic', 'East Africa'),
  LandingGenre('Soukous', 'Central Africa'),
  LandingGenre('Makossa', 'Central Africa'),
  LandingGenre('Ndombolo', 'Central Africa'),
  LandingGenre('Kwassa Kwassa', 'Central Africa'),
  LandingGenre('Zouk', 'Central Africa'),
];
