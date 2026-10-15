import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/studio_session_draft.dart';

/// Offline persistence layer for the Studio Ghost Session drafts (M10 /
/// REQ-SES-01, REQ-SES-06).
///
/// Adheres strictly to the Vhunambi repository standard (see
/// [NotificationRepository], [CreatorDnaRepository]):
/// - An **untyped** `Box?` adopted only when the box is already open — never
///   calls `Hive.openBox()` unconditionally.
/// - An automatic in-memory fallback map so headless VM / widget tests never
///   touch Hive's uninitialized path.
/// - Hand-rolled JSON — **zero** `build_runner` or `@HiveType` codegen.
class StudioSessionRepository {
  /// Single collection key holding the serialized draft.
  static const String _draftKey = 'current_draft';

  Box? _box;
  final Map<String, dynamic> _inMemoryStore = <String, dynamic>{};
  bool _initialized = false;

  StudioSessionRepository([Box? box]) : _box = box;

  /// Lazily binds to the studio session Hive box when it is already open.
  ///
  /// Mirrors the safe-storage invariant from the master handoff: never call
  /// `Hive.openBox()` unconditionally — only adopt an already-open box, else
  /// silently degrade to the in-memory fallback.
  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_box != null) {
      _initialized = true;
      return;
    }
    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.studioSessionBoxKey)) {
        _box = Hive.box(AppConstants.studioSessionBoxKey);
      }
    } catch (e) {
      debugPrint('StudioSessionRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  /// `true` when a persisted draft with recoverable content exists.
  Future<bool> hasSavedSession() async {
    await _ensureInit();
    try {
      final raw = _box != null
          ? _box!.get(_draftKey)
          : _inMemoryStore[_draftKey];
      if (raw == null) return false;
      final draft = StudioSessionDraft.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      return draft.hasContent;
    } catch (_) {
      return false;
    }
  }

  /// Reads the persisted draft, or `null` when absent / unreadable.
  Future<StudioSessionDraft?> loadSession() async {
    await _ensureInit();
    try {
      final raw = _box != null
          ? _box!.get(_draftKey)
          : _inMemoryStore[_draftKey];
      if (raw == null) return null;
      return StudioSessionDraft.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Persists the draft (fire-and-forget safe — write failures are silent).
  Future<void> saveSession(StudioSessionDraft draft) async {
    await _ensureInit();
    try {
      if (_box != null) {
        await _box!.put(_draftKey, draft.toJson());
      } else {
        _inMemoryStore[_draftKey] = draft.toJson();
      }
    } catch (_) {
      // Offline degradation is silent by design.
    }
  }

  /// Wipes the persisted draft (called on generation submit and discard).
  Future<void> clearSession() async {
    await _ensureInit();
    try {
      if (_box != null) {
        await _box!.delete(_draftKey);
      } else {
        _inMemoryStore.remove(_draftKey);
      }
    } catch (_) {}
  }
}