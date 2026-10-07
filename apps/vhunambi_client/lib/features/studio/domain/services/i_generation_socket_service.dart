import '../models/generation_pipeline_state.dart';

/// Transport contract for the live generation pipeline socket (T10.2).
abstract class IGenerationSocketService {
  /// Opens a WebSocket connection for [generationId] and returns a broadcast
  /// stream of parsed pipeline events.
  Stream<PipelineSocketEvent> connect(String generationId);

  /// Gracefully closes the socket (normal closure) and cancels heartbeats.
  Future<void> disconnect();

  /// Whether the socket is currently connected.
  bool get isConnected;
}
