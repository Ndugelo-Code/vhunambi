import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/features/home/domain/models/creator_allowance_state.dart';

/// Synchronizes creator free-monthly song quota with `GET /api/wallet/allowance`
/// and isolates cached snapshots by `canonicalCreatorId`.
class CreatorAllowanceNotifier extends StateNotifier<CreatorAllowanceState>
    with SafeNotifierMixin<CreatorAllowanceState> {
  static const String _cachePrefix = 'creator_allowance_cache_';

  final String _creatorId;
  final SovereignApiClient apiClient;
  final bool Function() isAuthenticated;
  final String _apiRestBaseUrl;

  CreatorAllowanceNotifier({
    required String creatorId,
    required this.apiClient,
    required this.isAuthenticated,
    String? apiRestBaseUrl,
    bool autoSync = true,
  })  : _creatorId = creatorId,
        _apiRestBaseUrl = apiRestBaseUrl ?? AppConstants.apiRestBaseUrl,
        super(_hydrateCachedOrDefault(creatorId)) {
    if (autoSync) {
      unawaited(refreshFromServer());
    }
  }

  /// Test-only constructor bypassing Hive and remote HTTP sync.
  CreatorAllowanceNotifier.withInitial(super.initial)
      : _creatorId = '',
        apiClient = SovereignApiClient(
          readSession: () => SovereignAuthSession.guestDefault(),
          refreshSession: () async => null,
        ),
        isAuthenticated = (() => false),
        _apiRestBaseUrl = AppConstants.apiRestBaseUrl;

  static String cacheKeyForCreator(String creatorId) =>
      '$_cachePrefix${creatorId.trim().isEmpty ? 'guest' : creatorId.trim()}';

  static CreatorAllowanceState _hydrateCachedOrDefault(String creatorId) {
    try {
      if (!SovereignDomainStorageMode.canHydrateFromStorage(
        AppConstants.prefsBoxKey,
      )) {
        return CreatorAllowanceState(creatorId: creatorId);
      }
      if (!Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        return CreatorAllowanceState(creatorId: creatorId);
      }
      final box = Hive.box<dynamic>(AppConstants.prefsBoxKey);
      final raw = box.get(cacheKeyForCreator(creatorId));
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return CreatorAllowanceState.fromJson(
            decoded,
            fallbackCreatorId: creatorId,
            isFromCache: true,
          );
        }
      } else if (raw is Map) {
        return CreatorAllowanceState.fromJson(
          Map<String, dynamic>.from(raw),
          fallbackCreatorId: creatorId,
          isFromCache: true,
        );
      }
    } catch (_) {
      // Preserve clean default quota on corrupted or headless test storage.
    }
    return CreatorAllowanceState(creatorId: creatorId);
  }

  Future<void> _persistCache(CreatorAllowanceState snapshot) async {
    try {
      if (!SovereignDomainStorageMode.canHydrateFromStorage(
        AppConstants.prefsBoxKey,
      )) {
        return;
      }
      if (!Hive.isBoxOpen(AppConstants.prefsBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.prefsBoxKey);
      await box.put(
        cacheKeyForCreator(_creatorId),
        jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // Persistence errors must never crash UI quota display.
    }
  }

  /// Fetches live quota from `GET /api/wallet/allowance`. Silently preserves
  /// cached or starter counts when offline or unauthenticated.
  Future<void> refreshFromServer() async {
    if (!isAuthenticated()) return;
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/wallet/allowance');
      final response = await apiClient.send(
        (headers) => http.Request('GET', uri)..headers.addAll(headers),
        timeout: const Duration(seconds: 6),
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final next = CreatorAllowanceState.fromJson(
            decoded,
            fallbackCreatorId: _creatorId,
            isFromCache: false,
          );
          state = next;
          await _persistCache(next);
          return;
        }
      }
      state = state.copyWith(isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Optimistically decrements local remaining allowance after confirmed Studio
  /// generation dispatch while scheduling server reconciliation.
  void consumeOneSongOptimistically() {
    if (state.isPaidUnlimited) return;
    final nextRemaining = (state.freeMonthlySongsRemaining - 1)
        .clamp(0, state.freeMonthlySongsLimit);
    final nextUsed = state.freeMonthlySongsUsed + 1;
    final updated = state.copyWith(
      freeMonthlySongsUsed: nextUsed,
      freeMonthlySongsRemaining: nextRemaining,
      isFromCache: false,
    );
    state = updated;
    unawaited(_persistCache(updated));
    unawaited(refreshFromServer());
  }
}

final creatorAllowanceProvider =
    StateNotifierProvider<CreatorAllowanceNotifier, CreatorAllowanceState>((ref) {
  final creatorId = ref.watch(currentCreatorIdProvider);
  final apiClient = ref.watch(sovereignApiClientProvider);
  final overrideRoot = ref.watch(sovereignAuthApiRootUrlProvider);
  final restBase = overrideRoot != null
      ? '${AppConstants.normalizeOriginUrl(overrideRoot)}/api'
      : AppConstants.apiRestBaseUrl;
  return CreatorAllowanceNotifier(
    creatorId: creatorId,
    apiClient: apiClient,
    isAuthenticated: () => ref.read(authSessionProvider).isAuthenticated,
    apiRestBaseUrl: restBase,
  );
});
