import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/http_social_repository.dart';
import '../../domain/repositories/i_social_repository.dart';

/// Provides the active [ISocialRepository] instance (production HTTP with offline fallback).
final socialRepositoryProvider = Provider<ISocialRepository>((ref) {
  return HttpSocialRepository();
});

