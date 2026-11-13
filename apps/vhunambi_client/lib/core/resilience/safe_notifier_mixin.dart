import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';

/// Lifecycle-safe mixin for [StateNotifier] subclasses (REQ-P65-L3-03).
///
/// Guarantees that asynchronous callbacks resuming after `await` never throw
/// `Bad state: Tried to use <Notifier> after dispose was called`.
mixin SafeNotifierMixin<T> on StateNotifier<T> {
  /// Updates [state] only if this [StateNotifier] is still mounted.
  bool setStateIfMounted(T nextState) {
    if (!mounted) return false;
    state = nextState;
    return true;
  }

  /// Executes [action] inside a guarded async boundary and records any uncaught
  /// exception to [VhunambiCrashShield] instead of crashing the isolate.
  Future<R?> runGuarded<R>({
    required String source,
    required Future<R> Function() action,
    R? fallback,
  }) async {
    if (!mounted) return fallback;
    try {
      return await action();
    } catch (error, stackTrace) {
      VhunambiCrashShield.recordBreadcrumb(
        source: source,
        error: error,
        stackTrace: stackTrace,
      );
      return fallback;
    }
  }
}

