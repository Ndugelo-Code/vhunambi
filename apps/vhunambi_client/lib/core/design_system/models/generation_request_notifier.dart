import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tokens/design_enums.dart';
import 'generation_request_model.dart';

/// State held by [GenerationRequestNotifier].
@immutable
class GenerationRequestState {
  final GenerationRequestModel model;
  final bool isValid;
  final String? validationError;

  const GenerationRequestState({
    required this.model,
    this.isValid = true,
    this.validationError,
  });

  GenerationRequestState copyWith({
    GenerationRequestModel? model,
    bool? isValid,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return GenerationRequestState(
      model: model ?? this.model,
      isValid: isValid ?? this.isValid,
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
    );
  }
}

/// Riverpod StateNotifier managing [GenerationRequestModel] state.
///
/// Provides reactive updates to all consumers when any generation parameter
/// changes. Supports persistence via SharedPreferences.
class GenerationRequestNotifier extends StateNotifier<GenerationRequestState> {
  GenerationRequestNotifier([this._prefs])
      : super(GenerationRequestState(
            model: GenerationRequestModel.defaults())) {
    _loadState();
  }

  final SharedPreferences? _prefs;

  static const _prefsKey = 'generation_request_model';

  /// Loads persisted state from SharedPreferences.
  Future<void> _loadState() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        final model = GenerationRequestModel.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        model.validate();
        state = state.copyWith(model: model);
      } catch (_) {
        // Ignore corrupted persisted state — use defaults.
      }
    }
  }

  /// Persists the current model to SharedPreferences.
  Future<void> _persistState() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_prefsKey, jsonEncode(state.model.toJson()));
  }

  /// The current generation request model.
  GenerationRequestModel get model => state.model;

  /// The current validation status.
  bool get isValid => state.isValid;

  /// The current validation error message, if any.
  String? get validationError => state.validationError;

  /// Sets the genre and re-validates.
  Future<void> setGenre(Genre genre) async {
    final newModel = state.model.copyWith(genre: genre);
    _validateAndUpdate(newModel);
  }

  /// Sets the mood and re-validates.
  Future<void> setMood(Mood mood) async {
    final newModel = state.model.copyWith(mood: mood);
    _validateAndUpdate(newModel);
  }

  /// Sets the BPM and re-validates.
  Future<void> setBpm(int bpm) async {
    final newModel = state.model.copyWith(bpm: bpm);
    _validateAndUpdate(newModel);
  }

  /// Sets the DNA strength (0.0 to 1.0) and re-validates.
  Future<void> setDnaStrength(double dnaStrength) async {
    final newModel = state.model.copyWith(dnaStrength: dnaStrength);
    _validateAndUpdate(newModel);
  }

  /// Sets the visibility (e.g., 'public', 'private') and re-validates.
  Future<void> setVisibility(String visibility) async {
    final newModel = state.model.copyWith(visibility: visibility);
    _validateAndUpdate(newModel);
  }

  /// Sets the lyrics and re-validates.
  Future<void> setLyrics(String? lyrics) async {
    final newModel = state.model.copyWith(lyrics: lyrics);
    _validateAndUpdate(newModel);
  }

  /// Sets the prompt and re-validates.
  Future<void> setPrompt(String? prompt) async {
    final newModel = state.model.copyWith(prompt: prompt);
    _validateAndUpdate(newModel);
  }

  /// Resets all fields to defaults.
  Future<void> reset() async {
    final newModel = GenerationRequestModel.defaults();
    _validateAndUpdate(newModel);
  }

  /// Clears validation error without changing the model.
  void clearValidationError() {
    state = state.copyWith(clearValidationError: true);
  }

  /// Validates [newModel], updates state, and persists on success.
  Future<void> _validateAndUpdate(GenerationRequestModel newModel) async {
    try {
      newModel.validate();
      state = GenerationRequestState(model: newModel, isValid: true);
      await _persistState();
    } on GenerationRequestValidationException catch (e) {
      state = GenerationRequestState(
        model: newModel,
        isValid: false,
        validationError: e.message,
      );
    }
  }
}

/// Provider for an optional [SharedPreferences] instance.
///
/// Overridden in `main.dart` with an initialized instance. When null (such
/// as in widget tests), [GenerationRequestNotifier] runs purely in-memory.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Riverpod provider for [GenerationRequestNotifier].
///
/// Use `ref.read(generationRequestProvider.notifier).setGenre(...)` to
/// update generation parameters.
final generationRequestProvider =
    StateNotifierProvider<GenerationRequestNotifier, GenerationRequestState>(
  (ref) {
    return GenerationRequestNotifier(ref.watch(sharedPreferencesProvider));
  },
);