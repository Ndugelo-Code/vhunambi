import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Manages ordered keyboard focus traversal for accessible screens.
class KeyboardNavigationController {
  final List<FocusNode> _focusNodes = [];
  int _currentIndex = -1;

  /// Whether to output focus traversal steps to debug console.
  bool debugLogging = false;

  List<FocusNode> get focusNodes => List.unmodifiable(_focusNodes);
  int get currentIndex => _currentIndex;

  /// Register focus node into the sequential tab traversal order.
  void register(FocusNode node) {
    if (!_focusNodes.contains(node)) {
      _focusNodes.add(node);
    }
  }

  /// Register multiple focus nodes in sequence.
  void registerAll(Iterable<FocusNode> nodes) {
    for (final node in nodes) {
      register(node);
    }
  }

  /// Remove focus node from traversal list.
  void unregister(FocusNode node) {
    _focusNodes.remove(node);
    if (_currentIndex >= _focusNodes.length) {
      _currentIndex = _focusNodes.length - 1;
    }
  }

  /// Returns 1-based order of the focus node in the traversal chain, or -1 if not found.
  int orderOf(FocusNode node) {
    final idx = _focusNodes.indexOf(node);
    return idx == -1 ? -1 : idx + 1;
  }

  /// Returns summary of all registered nodes in traversal order.
  List<String> get focusOrderSummary {
    return [
      for (int i = 0; i < _focusNodes.length; i++)
        '${i + 1}. ${_focusNodes[i].debugLabel ?? "FocusNode_${i + 1}"}',
    ];
  }

  /// Moves keyboard focus to the next registered element.
  bool focusNext() {
    if (_focusNodes.isEmpty) return false;
    _currentIndex = (_currentIndex + 1) % _focusNodes.length;
    final node = _focusNodes[_currentIndex];
    node.requestFocus();
    _logFocus(node);
    return true;
  }

  /// Moves keyboard focus to the previous registered element.
  bool focusPrevious() {
    if (_focusNodes.isEmpty) return false;
    _currentIndex = (_currentIndex - 1 + _focusNodes.length) % _focusNodes.length;
    final node = _focusNodes[_currentIndex];
    node.requestFocus();
    _logFocus(node);
    return true;
  }

  void _logFocus(FocusNode node) {
    if (debugLogging || kDebugMode) {
      final label = node.debugLabel ?? 'Node #$_currentIndex';
      debugPrint('[A11y Focus Navigation] Step ${_currentIndex + 1}/${_focusNodes.length}: $label');
    }
  }

  /// Resets navigation state.
  void reset() {
    _currentIndex = -1;
  }

  /// Clean up all nodes.
  void dispose() {
    _focusNodes.clear();
    _currentIndex = -1;
  }
}

