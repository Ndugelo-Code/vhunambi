import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Immutable diagnostic record captured by [VhunambiCrashShield] (REQ-P65-L1-02..04).
@immutable
class CrashBreadcrumb {
  final String source;
  final String message;
  final String? stackPreview;
  final DateTime timestamp;
  final bool isFatal;

  const CrashBreadcrumb({
    required this.source,
    required this.message,
    this.stackPreview,
    required this.timestamp,
    this.isFatal = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'source': source,
    'message': message,
    if (stackPreview != null) 'stackPreview': stackPreview,
    'timestamp': timestamp.toIso8601String(),
    'isFatal': isFatal,
  };
}

/// Bounded ring buffer holding the most recent 100 fault breadcrumbs in memory.
class CrashBreadcrumbBuffer {
  static const int maxEntries = 100;
  final ListQueue<CrashBreadcrumb> _queue = ListQueue<CrashBreadcrumb>();

  List<CrashBreadcrumb> get entries =>
      List<CrashBreadcrumb>.unmodifiable(_queue);

  int get length => _queue.length;

  void record({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool isFatal = false,
  }) {
    if (_queue.length >= maxEntries) {
      _queue.removeFirst();
    }
    final rawStack = stackTrace?.toString() ?? '';
    final preview = rawStack.isEmpty
        ? null
        : rawStack.split('\n').take(6).join('\n');
    _queue.addLast(
      CrashBreadcrumb(
        source: source,
        message: error.toString(),
        stackPreview: preview,
        timestamp: DateTime.now().toUtc(),
        isFatal: isFatal,
      ),
    );
  }

  void clear() => _queue.clear();
}

/// Riverpod [ProviderObserver] recording provider initialization/mutation errors
/// into [VhunambiCrashShield.breadcrumbs] without crashing the UI isolate.
class VhunambiProviderObserver extends ProviderObserver {
  const VhunambiProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    VhunambiCrashShield.recordBreadcrumb(
      source: 'provider:${provider.name ?? provider.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Layer 1 Root Isolate, Platform Dispatcher, Widget Build & Startup Crash Shield.
abstract final class VhunambiCrashShield {
  static final CrashBreadcrumbBuffer breadcrumbs = CrashBreadcrumbBuffer();
  static bool _installed = false;

  static bool get isInstalled => _installed;

  /// Installs Flutter, PlatformDispatcher, and ErrorWidget boundaries, then
  /// executes [appRunner] inside [runZonedGuarded].
  static void run(Future<void> Function() appRunner) {
    runZonedGuarded<Future<void>>(() async {
      WidgetsFlutterBinding.ensureInitialized();
      installFrameworkHandlers();
      await appRunner();
    }, recordZoneError);
  }

  /// Installs framework error handlers idempotently (safe to call in tests).
  static void installFrameworkHandlers() {
    _installed = true;

    FlutterError.onError = recordFlutterError;

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      return recordPlatformError(error, stack);
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      recordBreadcrumb(
        source: 'error_widget_builder',
        error: details.exception,
        stackTrace: details.stack,
      );
      return VhunambiSafeErrorCard(details: details);
    };
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    breadcrumbs.record(
      source: 'flutter_error:${details.library ?? 'framework'}',
      error: details.exception,
      stackTrace: details.stack,
    );
    debugPrint(
      '[VhunambiCrashShield] FlutterError caught (${details.library}): ${details.exception}',
    );
  }

  static bool recordPlatformError(Object error, StackTrace stackTrace) {
    breadcrumbs.record(
      source: 'platform_dispatcher',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[VhunambiCrashShield] PlatformDispatcher error contained: $error');
    // Return true so uncaught async plugin/network errors never terminate the OS process.
    return true;
  }

  static void recordZoneError(Object error, StackTrace stackTrace) {
    breadcrumbs.record(
      source: 'zone_error',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('[VhunambiCrashShield] Uncaught zone error contained: $error');
  }

  static void recordBreadcrumb({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool isFatal = false,
  }) {
    breadcrumbs.record(
      source: source,
      error: error,
      stackTrace: stackTrace,
      isFatal: isFatal,
    );
  }

  /// Executes a pre-`runApp` startup task with a strict timeout and fallback
  /// so a hung/corrupt disk box or missing native plugin never blocks launch.
  static Future<T> guardStartup<T>({
    required String stepName,
    required Future<T> Function() action,
    required T Function() fallback,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      return await action().timeout(timeout);
    } catch (error, stackTrace) {
      recordBreadcrumb(
        source: 'startup:$stepName',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint(
        '[VhunambiCrashShield] Startup step "$stepName" degraded cleanly: $error',
      );
      return fallback();
    }
  }
}

/// Non-crashing recovery card rendered whenever a widget subtree fails to build.
class VhunambiSafeErrorCard extends StatelessWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;

  const VhunambiSafeErrorCard({
    super.key = const Key('vhunambi_safe_error_card'),
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceElevated,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.shieldCheck,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Component Recovery Active',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This view recovered from a display error. Your session is safe.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  key: const Key('vhunambi_safe_error_retry_btn'),
                  onPressed: onRetry,
                  child: Text(
                    'Retry',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

