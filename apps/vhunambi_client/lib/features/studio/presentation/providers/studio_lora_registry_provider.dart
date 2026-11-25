import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/utils/json_safe.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';

@immutable
class StudioLoraRegistryState {
  final List<AfricanLoraPackOption> packs;
  final bool isLoading;
  final String? activeDispatchLoraId;
  final String activeFilter; // 'all' | 'ready' | 'active'
  final int totalSourceTracks;
  final String? errorMessage;
  final String? noticeMessage;

  const StudioLoraRegistryState({
    this.packs = kAllSovereignLoraPacks,
    this.isLoading = false,
    this.activeDispatchLoraId,
    this.activeFilter = 'all',
    this.totalSourceTracks = 0,
    this.errorMessage,
    this.noticeMessage,
  });

  List<AfricanLoraPackOption> get filteredPacks {
    return switch (activeFilter) {
      'ready' => packs
          .where((p) => p.hasEnoughSourceTracks && !p.isActive)
          .toList(growable: false),
      'active' => packs.where((p) => p.isActive).toList(growable: false),
      _ => packs,
    };
  }

  StudioLoraRegistryState copyWith({
    List<AfricanLoraPackOption>? packs,
    bool? isLoading,
    String? activeDispatchLoraId,
    bool clearActiveDispatch = false,
    String? activeFilter,
    int? totalSourceTracks,
    String? errorMessage,
    bool clearError = false,
    String? noticeMessage,
    bool clearNotice = false,
  }) {
    return StudioLoraRegistryState(
      packs: packs ?? this.packs,
      isLoading: isLoading ?? this.isLoading,
      activeDispatchLoraId: clearActiveDispatch
          ? null
          : (activeDispatchLoraId ?? this.activeDispatchLoraId),
      activeFilter: activeFilter ?? this.activeFilter,
      totalSourceTracks: totalSourceTracks ?? this.totalSourceTracks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNotice ? null : (noticeMessage ?? this.noticeMessage),
    );
  }
}

class StudioLoraRegistryNotifier extends StateNotifier<StudioLoraRegistryState>
    with SafeNotifierMixin<StudioLoraRegistryState> {
  final Ref _ref;
  final http.Client? _injectedClient;
  final String _apiBaseUrl;

  StudioLoraRegistryNotifier(
    this._ref, {
    http.Client? client,
    String? apiBaseUrl,
  }) : _injectedClient = client,
       _apiBaseUrl = (apiBaseUrl ?? AppConstants.apiBaseUrl).replaceAll(
         RegExp(r'/+$'),
         '',
       ),
       super(const StudioLoraRegistryState());

  void setFilter(String filter) {
    setStateIfMounted(
      state.copyWith(activeFilter: filter, clearError: true),
    );
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      headers.addAll(_ref.read(authHeadersProvider));
    } catch (_) {}
    return headers;
  }

  Future<void> refreshFactory() async {
    setStateIfMounted(
      state.copyWith(isLoading: true, clearError: true),
    );
    final httpClient = _injectedClient ?? http.Client();
    final ownsClient = _injectedClient == null;
    try {
      final resp = await httpClient
          .get(
            Uri.parse('$_apiBaseUrl/v1/studio/loras/factory'),
            headers: _buildHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        setStateIfMounted(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Factory sync returned HTTP ${resp.statusCode}',
          ),
        );
        return;
      }

      final payload = JsonSafe.decodeMap(resp.body) ?? <String, dynamic>{};
      final rawPacks = payload['packs'];
      final parsedPacks = <AfricanLoraPackOption>[];
      if (rawPacks is List) {
        for (final item in rawPacks) {
          if (item is Map) {
            final opt = AfricanLoraPackOption.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (opt.loraId.isNotEmpty) {
              parsedPacks.add(opt);
            }
          }
        }
      }
      setStateIfMounted(
        state.copyWith(
          packs: parsedPacks.isEmpty ? kAllSovereignLoraPacks : parsedPacks,
          isLoading: false,
          totalSourceTracks: (payload['totalSourceTracks'] as num?)?.toInt() ?? 0,
          clearError: true,
        ),
      );
    } catch (_) {
      setStateIfMounted(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to reach LoRA Factory registry.',
        ),
      );
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  Future<String?> triggerDatasetPrep(String loraId) async {
    setStateIfMounted(
      state.copyWith(
        activeDispatchLoraId: loraId,
        clearError: true,
        clearNotice: true,
      ),
    );
    final httpClient = _injectedClient ?? http.Client();
    final ownsClient = _injectedClient == null;
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$_apiBaseUrl/v1/studio/loras/datasets/prep'),
            headers: _buildHeaders(),
            body: jsonEncode(<String, dynamic>{'loraId': loraId}),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return null;
      final body = JsonSafe.decodeMap(resp.body) ?? <String, dynamic>{};
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final msg = (body['message'] ?? 'Dataset prep failed (${resp.statusCode}).').toString();
        setStateIfMounted(
          state.copyWith(clearActiveDispatch: true, errorMessage: msg),
        );
        return msg;
      }

      final updated = state.packs
          .map(
            (p) => p.loraId == loraId
                ? p.copyWith(registryStatus: 'preparing')
                : p,
          )
          .toList(growable: false);
      setStateIfMounted(
        state.copyWith(
          packs: updated,
          clearActiveDispatch: true,
          noticeMessage: 'Cloud dataset prep queued for $loraId.',
        ),
      );
      return null;
    } catch (_) {
      const msg = 'Network error dispatching cloud dataset prep.';
      setStateIfMounted(
        state.copyWith(clearActiveDispatch: true, errorMessage: msg),
      );
      return msg;
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  Future<String?> triggerCloudTraining(String loraId) async {
    setStateIfMounted(
      state.copyWith(
        activeDispatchLoraId: loraId,
        clearError: true,
        clearNotice: true,
      ),
    );
    final httpClient = _injectedClient ?? http.Client();
    final ownsClient = _injectedClient == null;
    try {
      final resp = await httpClient
          .post(
            Uri.parse('$_apiBaseUrl/v1/studio/loras/train'),
            headers: _buildHeaders(),
            body: jsonEncode(<String, dynamic>{
              'loraId': loraId,
              'executionTarget': 'serverless',
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return null;
      final body = JsonSafe.decodeMap(resp.body) ?? <String, dynamic>{};
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final msg = (body['message'] ?? 'LoRA training failed (${resp.statusCode}).').toString();
        setStateIfMounted(
          state.copyWith(clearActiveDispatch: true, errorMessage: msg),
        );
        return msg;
      }

      final updated = state.packs
          .map(
            (p) => p.loraId == loraId && !p.isActive
                ? p.copyWith(registryStatus: 'queued')
                : p,
          )
          .toList(growable: false);
      setStateIfMounted(
        state.copyWith(
          packs: updated,
          clearActiveDispatch: true,
          noticeMessage: 'RunPod PEFT training queued for $loraId.',
        ),
      );
      return null;
    } catch (_) {
      const msg = 'Network error dispatching cloud LoRA training.';
      setStateIfMounted(
        state.copyWith(clearActiveDispatch: true, errorMessage: msg),
      );
      return msg;
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }
}

final studioLoraRegistryProvider = StateNotifierProvider<
    StudioLoraRegistryNotifier,
    StudioLoraRegistryState>((ref) => StudioLoraRegistryNotifier(ref));
