import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/player/presentation/providers/mini_player_controller.dart';

/// Registers a page-declared UI bounding [Rect] with [MiniPlayerController]
/// so the Bar form avoids it in Auto_Mode.
///
/// Wrap bottom-anchored UI (e.g., the studio dock) with this widget:
/// ```dart
/// PlayerObstacle(
///   id: 'content_studio_dock',
///   child: StudioDock(),
/// )
/// ```
///
/// The obstacle rect is updated on layout via a `LayoutBuilder` and
/// `WidgetsBinding.instance.addPostFrameCallback` to ensure the rect
/// reflects the actual painted position.
class PlayerObstacle extends ConsumerStatefulWidget {
  /// Unique identifier for this obstacle.
  final String id;

  /// Child widget whose bounds are registered as an obstacle.
  final Widget child;

  const PlayerObstacle({
    super.key,
    required this.id,
    required this.child,
  });

  @override
  ConsumerState<PlayerObstacle> createState() => _PlayerObstacleState();
}

class _PlayerObstacleState extends ConsumerState<PlayerObstacle> {
  final GlobalKey _childKey = GlobalKey();

  // Cached during initState — safe to use in dispose() because Riverpod forbids
  // calling ref.read() after the element is disposed.
  late MiniPlayerController _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(miniPlayerControllerProvider.notifier);
    _registerObstacle();
  }

  @override
  void didUpdateWidget(covariant PlayerObstacle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      _notifier.unregisterObstacle(oldWidget.id);
      _registerObstacle();
    }
  }

  @override
  void dispose() {
    // Defer past the current frame — Riverpod rejects notifyListeners() calls
    // that arrive during widget unmount (dispose is called inside BuildOwner.finalizeTree).
    final id = widget.id;
    Future.microtask(() => _notifier.unregisterObstacle(id));
    super.dispose();
  }

  void _registerObstacle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      _notifier.registerObstacle(widget.id, rect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        key: _childKey,
        child: widget.child,
      ),
    );
  }
}
