import 'dart:async';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/theme/post_chromatic_palette_resolver.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_publish_view.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/atmospheric_effects_deck.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/reel_audio_trimmer_sheet.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/typography_preset_picker.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/sovereign_sticker_pack.dart';

enum _ReelStudioStage { capture, editor, publish }
enum _BackdropMode { artwork, camera, vision }

@immutable
class _VisualPresetOrb {
  final String id;
  final String label;
  final Color tint;
  final AtmosphericEffects effects;

  const _VisualPresetOrb({
    required this.id,
    required this.label,
    required this.tint,
    required this.effects,
  });
}

/// Full-Screen 4-Stage Instagram-Benchmark Kinetic Reels Studio (`EP-P74-REELS-STUDIO-PIPELINE`).
class KineticReelStudioView extends ConsumerStatefulWidget {
  final LibraryTrack? initialTrack;
  final PublishedClip? initialClip;

  const KineticReelStudioView({
    super.key,
    this.initialTrack,
    this.initialClip,
  });

  static Future<void> show(
    BuildContext context, {
    LibraryTrack? initialTrack,
    PublishedClip? initialClip,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => KineticReelStudioView(
          initialTrack: initialTrack,
          initialClip: initialClip,
        ),
      ),
    );
  }

  @override
  ConsumerState<KineticReelStudioView> createState() =>
      _KineticReelStudioViewState();
}

class _KineticReelStudioViewState
    extends ConsumerState<KineticReelStudioView> {
  static const List<_VisualPresetOrb> _presetOrbs = <_VisualPresetOrb>[
    _VisualPresetOrb(
      id: 'kinetic_gold',
      label: 'Kinetic Gold',
      tint: Color(0xFFF59E0B),
      effects: AtmosphericEffects(
        filmGrain: false,
        bassPulse: true,
        kenBurnsMotion: true,
      ),
    ),
    _VisualPresetOrb(
      id: 'super_8mm',
      label: 'Super 8mm',
      tint: Color(0xFFD97706),
      effects: AtmosphericEffects(
        filmGrain: true,
        bassPulse: false,
        kenBurnsMotion: true,
      ),
    ),
    _VisualPresetOrb(
      id: 'amapiano_pulse',
      label: 'Amapiano Pulse',
      tint: Color(0xFF7C3AED),
      effects: AtmosphericEffects(
        filmGrain: false,
        bassPulse: true,
        kenBurnsMotion: false,
      ),
    ),
    _VisualPresetOrb(
      id: 'noir_studio',
      label: 'Noir Studio',
      tint: Color(0xFF334155),
      effects: AtmosphericEffects(
        filmGrain: true,
        bassPulse: false,
        kenBurnsMotion: false,
      ),
    ),
    _VisualPresetOrb(
      id: 'makhado_warm',
      label: 'Makhado Warm',
      tint: Color(0xFFEA580C),
      effects: AtmosphericEffects(
        filmGrain: true,
        bassPulse: true,
        kenBurnsMotion: true,
      ),
    ),
  ];

  static const List<double> _speedSteps = <double>[0.5, 1.0, 1.5, 2.0];
  static const List<int> _timerSteps = <int>[0, 3, 5, 10];
  static const List<int> _lengthSteps = <int>[15, 30, 60, 90];

  StateController<int>? _overlayCountController;
  bool _incrementedOverlayCount = false;

  _ReelStudioStage _stage = _ReelStudioStage.capture;
  _BackdropMode _backdropMode = _BackdropMode.artwork;
  bool _railOnRight = true;
  bool _flashOn = false;
  bool _showLyrics = true;
  bool _showIntensitySlider = false;
  int _speedIdx = 1;
  int _timerIdx = 0;
  int _lengthIdx = 1; // 30s
  int _countdownRemaining = 0;
  Timer? _countdownTimer;

  String _selectedPresetId = 'kinetic_gold';
  double _effectIntensity = 0.65;
  AtmosphericEffects _effects = const AtmosphericEffects(
    filmGrain: false,
    bassPulse: true,
    kenBurnsMotion: true,
  );
  LyricTypographyPreset _typographyPreset = LyricTypographyPreset.kineticBounce;
  String? _selectedStickerId;
  String _activeEditorDrawer = 'lyrics'; // lyrics | effects | stickers

  late ReelStudioAudioSelection _audio;
  int _audioStartMs = 0;
  int _audioEndMs = 30000;

  String _mediaKind = 'artwork';
  Uint8List? _customMediaBytes;
  String? _customMediaFilename;
  String? _customMediaMime;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _cameraIdx = 0;

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void initState() {
    super.initState();
    _audio = _resolveInitialAudio();
    _audioEndMs = (_lengthSteps[_lengthIdx] * 1000).clamp(15000, 90000);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _overlayCountController =
          ref.read(pushedFullScreenOverlayCountProvider.notifier);
      _overlayCountController!.state++;
      _incrementedOverlayCount = true;
    });
  }

  ReelStudioAudioSelection _resolveInitialAudio() {
    if (widget.initialTrack != null) {
      return ReelStudioAudioSelection.fromLibraryTrack(widget.initialTrack!);
    }
    if (widget.initialClip != null) {
      final clip = widget.initialClip!;
      return ReelStudioAudioSelection(
        trackId: clip.trackId,
        title: clip.title,
        creatorHandle: clip.creatorUsername,
        genre: clip.genre,
        mood: 'uplifting',
        audioUrl: clip.audioUrl,
        coverUrl: clip.coverUrl,
        durationSeconds: 90.0,
        dna: clip.dna,
      );
    }
    final tracks = ref.read(libraryTracksProvider);
    if (tracks.isNotEmpty) {
      return ReelStudioAudioSelection.fromLibraryTrack(tracks.first);
    }
    return ReelStudioAudioSelection(
      trackId: 'studio_seed_track',
      title: 'Limpopo Sunset Groove',
      creatorHandle: 'vhunambi',
      genre: 'Amapiano',
      mood: 'uplifting',
      audioUrl: '',
      coverUrl: '',
      durationSeconds: 90.0,
      dna: SongMetadataDna.fromTrackInfo(
        id: 'studio_seed_track',
        title: 'Limpopo Sunset Groove',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        durationSec: 90,
        lyrics: 'Vhunambi rhythm rising under golden skies tonight',
      ),
    );
  }

  Future<void> _initCameraIfAllowed() async {
    if (_isTestEnv || kIsWeb) return;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _cameraController?.dispose();
      final controller = CameraController(
        _cameras[_cameraIdx % _cameras.length],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraController = controller);
    } catch (_) {
      // Fall back to chromatic artwork canvas when camera is unavailable
    }
  }

  Future<void> _pickGalleryMedia() async {
    if (_isTestEnv) {
      setState(() {
        _mediaKind = 'gallery_photo';
        _customMediaFilename = 'gallery_test.jpg';
        _customMediaMime = 'image/jpeg';
        _stage = _ReelStudioStage.editor;
      });
      return;
    }
    try {
      final picker = ImagePicker();
      final media = await picker.pickMedia();
      if (media == null) return;
      final bytes = await media.readAsBytes();
      final lower = media.name.toLowerCase();
      final isVideo = lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm');
      setState(() {
        _mediaKind = isVideo ? 'gallery_video' : 'gallery_photo';
        _customMediaBytes = bytes;
        _customMediaFilename = media.name;
        _customMediaMime = isVideo ? 'video/mp4' : 'image/jpeg';
        _stage = _ReelStudioStage.editor;
      });
    } catch (_) {}
  }

  void _handleShutterTap() {
    final timerSec = _timerSteps[_timerIdx];
    if (timerSec > 0 && _countdownRemaining == 0) {
      setState(() => _countdownRemaining = timerSec);
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_countdownRemaining <= 1) {
          t.cancel();
          setState(() {
            _countdownRemaining = 0;
            _stage = _ReelStudioStage.editor;
          });
        } else {
          setState(() => _countdownRemaining--);
        }
      });
      return;
    }
    setState(() => _stage = _ReelStudioStage.editor);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    if (_incrementedOverlayCount && _overlayCountController != null) {
      final ctrl = _overlayCountController!;
      _incrementedOverlayCount = false;
      Future<void>.microtask(() {
        if (ctrl.mounted && ctrl.state > 0) {
          ctrl.state = (ctrl.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _ReelStudioStage.publish) {
      return KineticReelPublishView(
        audio: _audio,
        mediaKind: _mediaKind,
        customMediaBytes: _customMediaBytes,
        customMediaFilename: _customMediaFilename,
        customMediaMime: _customMediaMime,
        audioStartMs: _audioStartMs,
        audioEndMs: _audioEndMs,
        effectPreset: _selectedPresetId,
        effectIntensity: _effectIntensity,
        typographyPreset: _typographyPreset,
        speedRate: _speedSteps[_speedIdx],
        stickerId: _selectedStickerId,
        onBackToEditor: () => setState(() => _stage = _ReelStudioStage.editor),
        onPublishComplete: () => Navigator.of(context).pop(),
      );
    }

    final palette = PostChromaticPaletteResolver.resolveSync(
      brightness: Brightness.dark,
      rawMood: _audio.mood,
      artworkUrl: _audio.coverUrl,
      hasAudioAttachment: true,
    );
    final activeOrb = _presetOrbs.firstWhere(
      (o) => o.id == _selectedPresetId,
      orElse: () => _presetOrbs.first,
    );
    final activeSticker = SovereignStickerPack.findById(_selectedStickerId);

    return Scaffold(
      key: const Key('kinetic_reel_studio_view'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          key: Key(
            _stage == _ReelStudioStage.capture
                ? 'reel_studio_stage_capture'
                : 'reel_studio_stage_editor',
          ),
          fit: StackFit.expand,
          children: <Widget>[
            // 1. 9:16 Backdrop / Camera / Chromatic Canvas
            if (_backdropMode == _BackdropMode.camera &&
                _cameraController != null &&
                _cameraController!.value.isInitialized)
              CameraPreview(_cameraController!)
            else
              DecoratedBox(
                key: const Key('reel_studio_camera_fallback_canvas'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      palette.primaryGlow.withValues(alpha: 0.72),
                      palette.secondaryGlow.withValues(alpha: 0.85),
                      Colors.black,
                    ],
                  ),
                ),
                child: KineticPreviewCanvas(
                  coverArtUrl: _audio.coverUrl,
                  genre: _audio.genre,
                  trackId: _audio.trackId,
                  words: _showLyrics
                      ? _audio.dna.alignment
                      : const <LyricWordTimestamp>[],
                  preset: _typographyPreset,
                  effects: _effects,
                  playbackPositionSec: _audioStartMs / 1000.0,
                  isPlaying: false,
                  fullScreen: true,
                  showInternalPlayOverlay: false,
                ),
              ),

            // 2. Active Visual Preset Atmospheric Tint
            IgnorePointer(
              child: ColoredBox(
                color: activeOrb.tint.withValues(
                  alpha: (_effectIntensity * 0.24).clamp(0.0, 0.28),
                ),
              ),
            ),

            // 3. Optional Sovereign Cultural Sticker Overlay
            if (activeSticker != null)
              Positioned(
                top: 84,
                right: 76,
                child: SovereignStickerGraphic(
                  key: Key('reel_studio_canvas_sticker_${activeSticker.id}'),
                  sticker: activeSticker,
                  width: 96,
                  height: 74,
                ),
              ),

            // 4. Countdown HUD
            if (_countdownRemaining > 0)
              Center(
                key: const Key('reel_studio_countdown_hud'),
                child: Text(
                  '$_countdownRemaining',
                  style: AppTypography.displayLarge.copyWith(
                    color: Colors.white,
                    fontSize: 88,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

            // 5. Top Translucent Chrome
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  IconButton(
                    key: const Key('reel_studio_close_btn'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const PhosphorIcon(AppIcons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: GestureDetector(
                      key: const Key('reel_studio_audio_pill'),
                      onTap: () async {
                        final picked = await ReelAudioPickerSheet.show(context);
                        if (picked != null && mounted) {
                          setState(() => _audio = picked);
                        }
                      },
                      child: VhunambiGlassSurface(
                        variant: VhunambiGlassVariant.pill,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const PhosphorIcon(
                              AppIcons.songsOutline,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _audio.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('reel_studio_flash_btn'),
                    onPressed: () => setState(() => _flashOn = !_flashOn),
                    icon: PhosphorIcon(
                      _flashOn ? AppIcons.lightning : AppIcons.sparkle,
                      color: _flashOn ? AppColors.brandPrimary : Colors.white,
                      size: 20,
                    ),
                  ),
                  TextButton(
                    key: const Key('reel_studio_speed_btn'),
                    onPressed: () => setState(
                      () => _speedIdx = (_speedIdx + 1) % _speedSteps.length,
                    ),
                    child: Text(
                      '${_speedSteps[_speedIdx]}x',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('reel_studio_timer_btn'),
                    onPressed: () => setState(
                      () => _timerIdx = (_timerIdx + 1) % _timerSteps.length,
                    ),
                    child: Text(
                      _timerSteps[_timerIdx] == 0
                          ? '0s'
                          : '${_timerSteps[_timerIdx]}s',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('reel_studio_rail_side_btn'),
                    onPressed: () =>
                        setState(() => _railOnRight = !_railOnRight),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.arrowsLeftRight,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // 6. Collapsible Left/Right Floating Tool Rail + Vertical Intensity Slider
            if (_stage == _ReelStudioStage.capture)
              Positioned(
                top: 96,
                right: _railOnRight ? 12 : null,
                left: _railOnRight ? null : 12,
                child: Column(
                  key: const Key('reel_studio_tool_rail'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _RailToolButton(
                      key: const Key('reel_rail_audio_btn'),
                      icon: AppIcons.songsOutline,
                      label: 'Audio',
                      onTap: () async {
                        final picked = await ReelAudioPickerSheet.show(context);
                        if (picked != null && mounted) {
                          setState(() => _audio = picked);
                        }
                      },
                    ),
                    _RailToolButton(
                      key: const Key('reel_rail_effects_btn'),
                      icon: AppIcons.sparkle,
                      label: 'FX',
                      active: _showIntensitySlider,
                      onTap: () => setState(
                        () => _showIntensitySlider = !_showIntensitySlider,
                      ),
                    ),
                    _RailToolButton(
                      key: const Key('reel_rail_backdrop_btn'),
                      icon: PhosphorIconsRegular.camera,
                      label: _backdropMode.name,
                      onTap: () {
                        final nextIdx =
                            (_backdropMode.index + 1) % _BackdropMode.values.length;
                        final nextMode = _BackdropMode.values[nextIdx];
                        setState(() {
                          _backdropMode = nextMode;
                          _mediaKind = nextMode == _BackdropMode.camera
                              ? 'camera_video'
                              : (nextMode == _BackdropMode.vision
                                    ? 'vision'
                                    : 'artwork');
                        });
                        if (nextMode == _BackdropMode.camera) {
                          _initCameraIfAllowed();
                        }
                      },
                    ),
                    _RailToolButton(
                      key: const Key('reel_rail_lyrics_btn'),
                      icon: PhosphorIconsRegular.textAa,
                      label: 'Lyrics',
                      active: _showLyrics,
                      onTap: () => setState(() => _showLyrics = !_showLyrics),
                    ),
                    _RailToolButton(
                      key: const Key('reel_rail_length_btn'),
                      icon: PhosphorIconsRegular.timer,
                      label: '${_lengthSteps[_lengthIdx]}s',
                      onTap: () {
                        setState(() {
                          _lengthIdx = (_lengthIdx + 1) % _lengthSteps.length;
                          _audioEndMs =
                              _audioStartMs + (_lengthSteps[_lengthIdx] * 1000);
                        });
                      },
                    ),
                    if (_showIntensitySlider)
                      SizedBox(
                        height: 120,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            key: const Key('reel_studio_intensity_slider'),
                            value: _effectIntensity * 100.0,
                            min: 0,
                            max: 100,
                            activeColor: AppColors.brandPrimary,
                            onChanged: (v) =>
                                setState(() => _effectIntensity = v / 100.0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // 7. Bottom Capture Deck (Stage 1) OR Studio Editor Drawers (Stage 2)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _stage == _ReelStudioStage.capture
                  ? _buildCaptureBottomDeck()
                  : _buildEditorBottomDeck(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureBottomDeck() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presetOrbs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final orb = _presetOrbs[idx];
                final active = orb.id == _selectedPresetId;
                return GestureDetector(
                  key: Key('reel_preset_orb_${orb.id}'),
                  onTap: () {
                    setState(() {
                      _selectedPresetId = orb.id;
                      _effects = orb.effects;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: active ? orb.tint : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? Colors.white : Colors.white24,
                      ),
                    ),
                    child: Text(
                      orb.label,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                key: const Key('reel_studio_gallery_btn'),
                onPressed: _pickGalleryMedia,
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.image,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              IconButton(
                key: const Key('reel_studio_flip_camera_btn'),
                onPressed: () {
                  _cameraIdx++;
                  if (_backdropMode == _BackdropMode.camera) {
                    _initCameraIfAllowed();
                  }
                },
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.cameraRotate,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              GestureDetector(
                key: const Key('reel_studio_shutter_btn'),
                onTap: _handleShutterTap,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              ElevatedButton(
                key: const Key('reel_studio_next_to_editor_btn'),
                onPressed: () =>
                    setState(() => _stage = _ReelStudioStage.editor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorBottomDeck() {
    final tabStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: const Size(44, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: const BoxDecoration(
        color: Color(0xE6111116),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextButton(
                        style: tabStyle,
                        onPressed: () =>
                            setState(() => _activeEditorDrawer = 'lyrics'),
                        child: Text(
                          'Lyrics',
                          style: TextStyle(
                            color: _activeEditorDrawer == 'lyrics'
                                ? AppColors.brandPrimary
                                : Colors.white70,
                          ),
                        ),
                      ),
                      TextButton(
                        style: tabStyle,
                        onPressed: () =>
                            setState(() => _activeEditorDrawer = 'effects'),
                        child: Text(
                          'FX',
                          style: TextStyle(
                            color: _activeEditorDrawer == 'effects'
                                ? AppColors.brandPrimary
                                : Colors.white70,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('reel_editor_tab_stickers'),
                        style: tabStyle,
                        onPressed: () =>
                            setState(() => _activeEditorDrawer = 'stickers'),
                        child: Text(
                          'Stickers',
                          style: TextStyle(
                            color: _activeEditorDrawer == 'stickers'
                                ? AppColors.brandPrimary
                                : Colors.white70,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('reel_editor_tab_trim'),
                        style: tabStyle,
                        onPressed: () async {
                          final trimmed = await ReelAudioTrimmerSheet.show(
                            context,
                            trackTitle: _audio.title,
                            totalDurationSec: _audio.durationSeconds,
                            initialStartMs: _audioStartMs,
                            initialEndMs: _audioEndMs,
                          );
                          if (trimmed != null && mounted) {
                            setState(() {
                              _audioStartMs = trimmed.startMs;
                              _audioEndMs = trimmed.endMs;
                            });
                          }
                        },
                        child: const Text(
                          'Trim',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                key: const Key('reel_editor_next_to_publish_btn'),
                onPressed: () =>
                    setState(() => _stage = _ReelStudioStage.publish),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(56, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Next'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_activeEditorDrawer == 'lyrics')
            TypographyPresetPicker(
              selectedPreset: _typographyPreset,
              onPresetSelected: (p) => setState(() => _typographyPreset = p),
            )
          else if (_activeEditorDrawer == 'effects')
            AtmosphericEffectsDeck(
              effects: _effects,
              onToggle: ({filmGrain, bassPulse, kenBurnsMotion}) {
                setState(() {
                  _effects = _effects.copyWith(
                    filmGrain: filmGrain,
                    bassPulse: bassPulse,
                    kenBurnsMotion: kenBurnsMotion,
                  );
                });
              },
            )
          else
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: SovereignStickerPack.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final sticker = SovereignStickerPack.all[idx];
                  final selected = _selectedStickerId == sticker.id;
                  return GestureDetector(
                    key: Key('reel_editor_sticker_${sticker.id}'),
                    onTap: () {
                      setState(() {
                        _selectedStickerId = selected ? null : sticker.id;
                      });
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: selected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: SovereignStickerGraphic(
                        sticker: sticker,
                        width: 96,
                        height: 74,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RailToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RailToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? AppColors.brandPrimary : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Center(
                child: PhosphorIcon(icon, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
