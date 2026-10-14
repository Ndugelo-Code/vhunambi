import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/feature_flags.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'contrast_checker.dart';

/// Categories of accessibility violations detected during auditing.
enum A11yViolationType {
  touchTarget,
  contrast,
  missingSemantics,
  keyboardNavigation;

  String get label => switch (this) {
        A11yViolationType.touchTarget => 'Touch Target (<48dp)',
        A11yViolationType.contrast => 'Color Contrast',
        A11yViolationType.missingSemantics => 'Missing Semantics',
        A11yViolationType.keyboardNavigation => 'Keyboard Traversal',
      };
}

/// Represents an individual accessibility violation or warning.
class A11yViolation {
  final A11yViolationType type;
  final String elementDescription;
  final String severity; // 'violation' or 'warning'
  final Map<String, dynamic> details;

  const A11yViolation({
    required this.type,
    required this.elementDescription,
    this.severity = 'violation',
    this.details = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'label': type.label,
        'element': elementDescription,
        'severity': severity,
        'details': details,
      };
}

/// Summary report containing accessibility compliance statistics and violation records.
class A11yAuditReport {
  final DateTime timestamp;
  final List<A11yViolation> violations;
  final double touchTargetCompliance;
  final double contrastCompliance;

  A11yAuditReport({
    DateTime? timestamp,
    required this.violations,
    this.touchTargetCompliance = 100.0,
    this.contrastCompliance = 100.0,
  }) : timestamp = timestamp ?? DateTime.now();

  int get totalViolations => violations.length;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'totalViolations': totalViolations,
        'touchTargetCompliancePercent': touchTargetCompliance,
        'contrastCompliancePercent': contrastCompliance,
        'violations': violations.map((v) => v.toJson()).toList(),
      };

  /// Serializes the report into formatted JSON string.
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}

/// Controller managing accessibility audit mode state, simulated announcements, and reports.
class A11yAuditController extends ChangeNotifier {
  bool _isEnabled;
  final List<String> _screenReaderAnnouncements = [];
  final List<A11yViolation> _recordedViolations = [];

  A11yAuditController({bool? initialEnabled})
      : _isEnabled = initialEnabled ?? FeatureFlags.enableA11yAuditMode;

  bool get isEnabled => _isEnabled;
  List<String> get screenReaderAnnouncements => List.unmodifiable(_screenReaderAnnouncements);
  List<A11yViolation> get recordedViolations => List.unmodifiable(_recordedViolations);

  void toggle() {
    _isEnabled = !_isEnabled;
    FeatureFlags.enableA11yAuditMode = _isEnabled;
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_isEnabled != value) {
      _isEnabled = value;
      FeatureFlags.enableA11yAuditMode = value;
      notifyListeners();
    }
  }

  /// Records a simulated screen reader announcement.
  void announce(String message) {
    _screenReaderAnnouncements.insert(0, message);
    if (_screenReaderAnnouncements.length > 30) {
      _screenReaderAnnouncements.removeLast();
    }
    if (kDebugMode) {
      debugPrint('[A11y ScreenReader Simulation]: $message');
    }
    notifyListeners();
  }

  /// Records an accessibility violation found in the view.
  void recordViolation(A11yViolation violation) {
    _recordedViolations.add(violation);
    notifyListeners();
  }

  /// Clears recorded violations and announcements.
  void clear() {
    _recordedViolations.clear();
    _screenReaderAnnouncements.clear();
    notifyListeners();
  }

  /// Generates the complete accessibility audit report.
  A11yAuditReport generateReport() {
    final touchViolations =
        _recordedViolations.where((v) => v.type == A11yViolationType.touchTarget).length;
    final contrastViolations =
        _recordedViolations.where((v) => v.type == A11yViolationType.contrast).length;

    final targetComp = touchViolations == 0 ? 100.0 : (100.0 - (touchViolations * 10)).clamp(0.0, 100.0);
    final contrastComp = contrastViolations == 0 ? 100.0 : (100.0 - (contrastViolations * 10)).clamp(0.0, 100.0);

    return A11yAuditReport(
      violations: List.of(_recordedViolations),
      touchTargetCompliance: targetComp,
      contrastCompliance: contrastComp,
    );
  }
}

/// Global default instance for developer audit mode.
final a11yGlobalAuditController = A11yAuditController();

/// Visual badge and inspector for touch target compliance.
/// Green: ≥48dp
/// Yellow: 40-47dp
/// Red: <40dp
class TouchTargetComplianceBadge extends StatelessWidget {
  final double width;
  final double height;
  final Widget? child;

  const TouchTargetComplianceBadge({
    super.key,
    required this.width,
    required this.height,
    this.child,
  });

  static Color complianceColor(double w, double h) {
    final minDim = w < h ? w : h;
    if (minDim >= 48.0) return Colors.green;
    if (minDim >= 40.0) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = complianceColor(width, height);
    final minDim = width < height ? width : height;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ?child,
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 0.5),
            ),
            child: Text(
              '${minDim.round()}dp',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Badge overlay displaying foreground/background contrast ratio and WCAG rating.
class ContrastAuditBadge extends StatelessWidget {
  final Color foreground;
  final Color background;
  final Widget child;

  const ContrastAuditBadge({
    super.key,
    required this.foreground,
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = ContrastChecker.calculateContrastRatio(foreground, background);
    final level = ContrastChecker.getWCAGLevel(ratio);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          bottom: -6,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: level.color.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${ratio.toStringAsFixed(1)}:1 ${level.name.toUpperCase()}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Highlighting wrapper that applies a red dashed border if semantic label is missing.
class SemanticCheckWrapper extends StatelessWidget {
  final String? semanticLabel;
  final String elementName;
  final Widget child;
  final A11yAuditController? controller;

  const SemanticCheckWrapper({
    super.key,
    this.semanticLabel,
    required this.elementName,
    required this.child,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isMissing = semanticLabel == null || semanticLabel!.trim().isEmpty;
    if (isMissing && controller != null) {
      controller!.recordViolation(
        A11yViolation(
          type: A11yViolationType.missingSemantics,
          elementDescription: elementName,
          details: {'issue': 'Semantic label is null or empty'},
        ),
      );
    }

    if (!isMissing) return child;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.redAccent,
          width: 1.5,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

/// Developer overlay widget showing accessibility auditing details, screen reader simulator,
/// and report export button.
class A11yAuditMode extends StatefulWidget {
  final Widget child;
  final A11yAuditController? controller;

  const A11yAuditMode({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  State<A11yAuditMode> createState() => _A11yAuditModeState();
}

class _A11yAuditModeState extends State<A11yAuditMode> {
  late final A11yAuditController _controller;
  bool _showPanel = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? a11yGlobalAuditController;
    _controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isEnabled) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        // Floating accessibility banner & drawer toggle
        Positioned(
          top: 40,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _showPanel = !_showPanel),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.accessibility_new, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'A11y Audit (${_controller.recordedViolations.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Screen reader & audit simulation panel
        if (_showPanel)
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: _buildAuditPanel(context),
          ),
      ],
    );
  }

  Widget _buildAuditPanel(BuildContext context) {
    final report = _controller.generateReport();

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.surfaceElevated,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.record_voice_over, size: 18, color: AppColors.badgeCyan),
                    SizedBox(width: 6),
                    Text(
                      'Screen Reader & Audit Panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  onPressed: () => setState(() => _showPanel = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Compliance row & export
            Row(
              children: [
                Text(
                  'Targets: ${report.touchTargetCompliance.round()}% | Contrast: ${report.contrastCompliance.round()}%',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    final json = report.exportJson();
                    debugPrint('--- [A11y Audit Report JSON Export] ---');
                    debugPrint(json);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Accessibility audit JSON logged to console'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 14, color: AppColors.coinGold),
                  label: const Text('Export JSON', style: TextStyle(fontSize: 11, color: AppColors.coinGold)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const Divider(color: AppColors.borderSubtle, height: 12),
            // Simulated announcements scrollable list
            Expanded(
              child: _controller.screenReaderAnnouncements.isEmpty
                  ? const Center(
                      child: Text(
                        'No announcements recorded yet.\nInteract with elements to simulate TalkBack/VoiceOver.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _controller.screenReaderAnnouncements.length,
                      itemBuilder: (context, index) {
                        final announcement = _controller.screenReaderAnnouncements[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🔊 ', style: TextStyle(fontSize: 10)),
                              Expanded(
                                child: Text(
                                  announcement,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gesture detector for developer settings that toggles A11yAuditMode on triple-tap.
class A11yVersionTapDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onAuditToggled;

  const A11yVersionTapDetector({
    super.key,
    required this.child,
    this.onAuditToggled,
  });

  @override
  State<A11yVersionTapDetector> createState() => _A11yVersionTapDetectorState();
}

class _A11yVersionTapDetectorState extends State<A11yVersionTapDetector> {
  int _tapCount = 0;
  DateTime? _lastTapTime;

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > const Duration(milliseconds: 600)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 3) {
      _tapCount = 0;
      a11yGlobalAuditController.toggle();
      widget.onAuditToggled?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Accessibility Audit Mode: ${a11yGlobalAuditController.isEnabled ? "ENABLED" : "DISABLED"}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
