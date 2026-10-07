import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models/generation_pipeline_state.dart';
import '../../domain/services/i_generation_socket_service.dart';

/// Production WebSocket bridge for the audio synthesis pipeline (T10.2).
///
/// * Endpoint: `wss://api.vhunambi.com/ws/generation?id=<generationId>`
/// * 25 s heartbeat PING with a 10 s PONG watchdog.
/// * Exponential-backoff reconnection (1 / 2 / 4 / 8 / 16 s, max 5 attempts).
///
/// Automated tests never exercise this class directly (no real sockets in the
/// suite): they override `socketServiceProvider` with
/// [FakeGenerationSocketService].
class GenerationSocketService implements IGenerationSocketService {
  static const String baseUrl = 'wss://api.vhunambi.com/ws/generation';
  static const Duration pingInterval = Duration(seconds: 25);
  static const Duration pongTimeout = Duration(seconds: 10);
  static const int maxAttempts = 5;

  /// Exponential-backoff delay for [attempt] (`1`-based): 1/2/4/8/16 s.
  static Duration backoffForAttempt(int attempt) =>
      Duration(seconds: 1 << (attempt - 1).clamp(0, 10));

  final StreamController<PipelineSocketEvent> _controller =
      StreamController<PipelineSocketEvent>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _pingTimer;
  Timer? _pongTimer;
  Timer? _reconnectTimer;

  String? _activeGenerationId;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  @override
  bool get isConnected => _socket?.readyState == WebSocket.open;

  /// Reconnection attempts consumed by the current session.
  int get reconnectAttempts => _reconnectAttempts;

  /// The generation currently bound to the socket, if any.
  String? get activeGenerationId => _activeGenerationId;

  @override
  Stream<PipelineSocketEvent> connect(String generationId) {
    _activeGenerationId = generationId;
    _reconnectAttempts = 0;
    unawaited(_doConnect(generationId));
    return _controller.stream;
  }

  Future<void> _doConnect(String generationId) async {
    if (_disposed) return;

    try {
      final socket = await WebSocket.connect('$baseUrl?id=$generationId');
      if (_disposed) {
        await socket.close(WebSocketStatus.normalClosure);
        return;
      }

      // A successful handshake clears the backoff budget.
      _reconnectAttempts = 0;
      _socket = socket;
      _startHeartbeat(socket);
      _socketSubscription = socket.listen(
        _onFrame,
        onError: (Object error) => _scheduleReconnect(generationId),
        onDone: () => _scheduleReconnect(generationId),
        cancelOnError: false,
      );
    } catch (error) {
      debugPrint('GenerationSocketService connect failed: $error');
      _scheduleReconnect(generationId);
    }
  }

  void _onFrame(dynamic raw) {
    _resetPongTimer();
    if (raw is! String) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);

      switch (json['type']) {
        case 'pipeline_event':
          _emit(PipelineSocketEvent.fromJson(json));
        case 'PONG':
          _pongTimer?.cancel();
        case 'ERROR':
          _emit(
            PipelineSocketEvent(
              generationId: json['generation_id'] as String? ??
                  _activeGenerationId ??
                  '',
              step: PipelineStep.failed,
              stepIndex: 0,
              progressPercent: 0.0,
              statusMessage: 'Pipeline error',
              error: json['message'] as String? ?? 'Generation failed.',
            ),
          );
        default:
          break;
      }
    } catch (error) {
      // Malformed frame — discard it without tearing the socket down.
      debugPrint('GenerationSocketService discarded frame: $error');
    }
  }

  void _startHeartbeat(WebSocket socket) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (!isConnected) return;
      socket.add(jsonEncode(<String, String>{'type': 'PING'}));
      _resetPongTimer();
    });
  }

  void _resetPongTimer() {
    _pongTimer?.cancel();
    _pongTimer = Timer(pongTimeout, () {
      debugPrint('GenerationSocketService PONG watchdog expired');
      unawaited(_closeSocket());
      final generationId = _activeGenerationId;
      if (generationId != null) _scheduleReconnect(generationId);
    });
  }

  void _scheduleReconnect(String generationId) {
    if (_disposed || _reconnectTimer != null) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > maxAttempts) {
      _emitError(StateError('MaxReconnectAttemptsExceeded'));
      return;
    }

    _reconnectTimer = Timer(backoffForAttempt(_reconnectAttempts), () {
      _reconnectTimer = null;
      if (_disposed) return;
      unawaited(_doConnect(generationId));
    });
  }

  void _emit(PipelineSocketEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  void _emitError(Object error) {
    if (_controller.isClosed) return;
    _controller.addError(error);
  }

  Future<void> _closeSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;

    final socket = _socket;
    _socket = null;
    if (socket == null) return;

    try {
      await socket.close(WebSocketStatus.normalClosure);
    } catch (error) {
      debugPrint('GenerationSocketService close failed: $error');
    }
  }

  @override
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _activeGenerationId = null;
    _reconnectAttempts = 0;

    await _closeSocket();
  }

  /// Tears the bridge down permanently and closes the event stream.
  Future<void> dispose() async {
    await disconnect();
    _disposed = true;
    if (!_controller.isClosed) await _controller.close();
  }
}
