import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/auth/sovereign_hive_account_sanitizer.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

/// Optional HTTP client override for [SovereignAuthRepository] and [SovereignApiClient].
final sovereignAuthHttpClientProvider = Provider<http.Client?>((ref) => null);

/// Optional API root URL override (e.g., `http://127.0.0.1:<port>` in integration tests).
final sovereignAuthApiRootUrlProvider = Provider<String?>((ref) => null);

/// Persists & fetches Sovereign creator sessions via `vhunambi_tokens` + `/api/auth/*`.
final sovereignAuthRepositoryProvider = Provider<SovereignAuthRepository>((
  ref,
) {
  return SovereignAuthRepository(
    httpClient: ref.watch(sovereignAuthHttpClientProvider),
    apiRootUrl: ref.watch(sovereignAuthApiRootUrlProvider),
  );
});

/// Global multi-tenant creator identity & JWT session state (`Phase 61`).
final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, SovereignAuthSession>((ref) {
      final repo = ref.watch(sovereignAuthRepositoryProvider);
      return AuthSessionNotifier(repo);
    });

/// Single canonical `creator_<slug>` tenant ID projected across all 6 app domains.
final currentCreatorIdProvider = Provider<String>((ref) {
  return ref.watch(authSessionProvider).canonicalCreatorId;
});

/// Active creator `@handle` projected into UI surfaces, comments & certificates.
final currentCreatorHandleProvider = Provider<String>((ref) {
  return ref.watch(authSessionProvider).handle;
});

/// Active HTTP auth + canonical `X-Vhunambi-Creator-Id` headers map.
final authHeadersProvider = Provider<Map<String, String>>((ref) {
  return ref.watch(authSessionProvider).authHeaders;
});

/// Coordinated HTTP client with Bearer injection + single-flight `401` refresh.
final sovereignApiClientProvider = Provider<SovereignApiClient>((ref) {
  return SovereignApiClient(
    httpClient: ref.watch(sovereignAuthHttpClientProvider),
    readSession: () => ref.read(authSessionProvider),
    refreshSession: () =>
        ref.read(authSessionProvider.notifier).refreshSession(),
    onRefreshFailure: () => ref.read(authSessionProvider.notifier).signOut(),
  );
});

/// Shared [Dio] interceptor attaching Bearer JWT & `X-Vhunambi-Creator-Id` + `401` refresh.
final authDioInterceptorProvider = Provider<Interceptor>((ref) {
  return ref.watch(sovereignApiClientProvider).buildDioInterceptor();
});

/// StateNotifier managing sign-in, registration, seeded creator switching,
/// token refresh, and fail-closed multi-tenant Hive cache sanitization.
class AuthSessionNotifier extends StateNotifier<SovereignAuthSession> {
  static const String defaultSeededPassword = 'VhunambiSovereign!2026';

  static const Map<String, ({String creatorId, String displayName})>
  seededStudioCreators = <String, ({String creatorId, String displayName})>{
    'cern': (creatorId: 'creator_cern', displayName: 'cern'),
    'makhadzi': (creatorId: 'creator_makhadzi', displayName: 'Makhadzi'),
    'sigwa': (creatorId: 'creator_sigwa', displayName: 'Sigwa Inaf'),
    'kabza': (creatorId: 'creator_kabza', displayName: 'Kabza De Venda'),
    'focalistic': (creatorId: 'creator_focalistic', displayName: 'Focalistic'),
    'tyla': (creatorId: 'creator_tyla', displayName: 'Tyla'),
    'blackcoffee': (
      creatorId: 'creator_black_coffee',
      displayName: 'Black Coffee',
    ),
    'black_coffee': (
      creatorId: 'creator_black_coffee',
      displayName: 'Black Coffee',
    ),
  };

  final SovereignAuthRepository _repo;
  Completer<SovereignAuthSession?>? _refreshLock;

  AuthSessionNotifier(this._repo) : super(_repo.loadSession());

  /// Reloads session directly from `vhunambi_tokens` (used after DB/Hive restart).
  void hydrateFromVault() {
    state = _repo.loadSession();
  }

  /// Signs in with handle or email + password via `POST /api/auth/login`.
  Future<SovereignAuthSession> signIn({
    required String identifier,
    required String password,
    String deviceLabel = 'vhunambi_client',
  }) async {
    final prevCreatorId = state.canonicalCreatorId;
    final nextSession = await _repo.login(
      identifier: identifier,
      password: password,
      deviceLabel: deviceLabel,
    );
    await _applyAuthenticatedSession(
      prevCreatorId: prevCreatorId,
      nextSession: nextSession,
    );
    return nextSession;
  }

  /// Creates a new creator account via `POST /api/auth/register`.
  Future<SovereignAuthSession> signUp({
    required String handle,
    required String email,
    required String password,
    String? displayName,
    String deviceLabel = 'vhunambi_client',
  }) async {
    final prevCreatorId = state.canonicalCreatorId;
    final nextSession = await _repo.register(
      handle: handle,
      email: email,
      password: password,
      displayName: displayName,
      deviceLabel: deviceLabel,
    );
    await _applyAuthenticatedSession(
      prevCreatorId: prevCreatorId,
      nextSession: nextSession,
    );
    return nextSession;
  }

  /// Switches to one of the seeded studio demo creators (`@cern`, `@makhadzi`, `@sigwa`, ...).
  ///
  /// Uses live `/api/auth/login` first; falls back deterministically when offline
  /// or running inside a headless unit test without a live API server.
  Future<SovereignAuthSession> switchToSeededCreator({
    required String handle,
    String? displayName,
    String password = defaultSeededPassword,
  }) async {
    final prevCreatorId = state.canonicalCreatorId;
    try {
      return await signIn(identifier: handle, password: password);
    } on SovereignAuthException catch (e) {
      if (e.code != 'AUTH_OFFLINE' && e.statusCode != 503) {
        rethrow;
      }
    } catch (_) {
      // Network unreachable: continue with local studio profile switch below.
    }

    final canonical = canonicalizeCreatorId(handle);
    final raw = extractRawCreatorId(canonical);
    final seeded = seededStudioCreators[raw];
    final resolvedDisplay =
        (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (seeded?.displayName ?? raw);
    final localSession = SovereignAuthSession(
      userId: 'usr_studio_$raw',
      creatorId: seeded?.creatorId ?? canonical,
      handle: handleFromCreatorId(canonical),
      displayName: resolvedDisplay,
      email: '$raw@vhunambi.za',
      role: 'creator',
      sessionId: 'studio_local_$raw',
      accessToken: '',
      refreshToken: '',
      expiresAt: null,
      isGuest: false,
    );

    if (prevCreatorId != localSession.canonicalCreatorId) {
      await SovereignHiveAccountSanitizer.purgeTenantPrivateBoxes(
        clearAuthSession: false,
      );
    }
    await _repo.saveSession(localSession);
    if (mounted) {
      state = localSession;
    }
    return localSession;
  }

  /// Rotates JWT + refresh token once via `POST /api/auth/refresh` (single-flight).
  Future<SovereignAuthSession?> refreshSession() async {
    final existing = _refreshLock;
    if (existing != null && !existing.isCompleted) {
      return existing.future;
    }

    final refreshToken = state.refreshToken;
    if (refreshToken.isEmpty) return null;

    final completer = Completer<SovereignAuthSession?>();
    _refreshLock = completer;

    try {
      final refreshed = await _repo.refresh(refreshToken);
      if (refreshed != null && mounted) {
        state = refreshed;
      }
      if (!completer.isCompleted) {
        completer.complete(refreshed);
      }
      return refreshed;
    } on SovereignAuthException {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    } finally {
      if (identical(_refreshLock, completer)) {
        _refreshLock = null;
      }
    }
  }

  /// Revokes remote session, sanitizes all 20 tenant-private Hive boxes + L1
  /// caches, and reverts to the default guest `@cern` profile.
  Future<void> signOut() async {
    final current = state;
    await _repo.logout(
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
    );
    await SovereignHiveAccountSanitizer.purgeTenantPrivateBoxes(
      clearAuthSession: true,
    );
    if (mounted) {
      state = SovereignAuthSession.guestDefault();
    }
  }

  Future<void> _applyAuthenticatedSession({
    required String prevCreatorId,
    required SovereignAuthSession nextSession,
  }) async {
    if (prevCreatorId != nextSession.canonicalCreatorId) {
      await SovereignHiveAccountSanitizer.purgeTenantPrivateBoxes(
        clearAuthSession: false,
      );
      // Re-save after purge so both Hive token box and L1 session remain intact.
      await _repo.saveSession(nextSession);
    }
    if (mounted) {
      state = nextSession;
    }
  }
}
