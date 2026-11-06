import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Centralized design tokens for Vhunambi vector iconography.
///
/// Replaces sharp, blocky stock icons and literal emojis in UI badges with soft,
/// rounded Phosphor vector glyphs. Uses style-specific classes to ensure compile-time
/// tree-shaking and zero runtime bloat.
abstract final class AppIcons {
  // =========================================================================
  // 1. Mobile Bottom Navigation
  // =========================================================================
  static const IconData navHome = PhosphorIconsRegular.house;
  static const IconData navHomeActive = PhosphorIconsFill.house;

  static const IconData navExplore = PhosphorIconsRegular.compass;
  static const IconData navExploreActive = PhosphorIconsFill.compass;

  static const IconData navCreate = PhosphorIconsFill.sparkle;
  static const IconData navCreateActive = PhosphorIconsFill.sparkle;

  static const IconData navLibrary = PhosphorIconsRegular.musicNotesSimple;
  static const IconData navLibraryActive = PhosphorIconsFill.musicNotesSimple;

  static const IconData navMarket = PhosphorIconsRegular.storefront;
  static const IconData navMarketActive = PhosphorIconsFill.storefront;

  // =========================================================================
  // 2. Status, Streak, Gamification & Badges (Replaces UI Emojis)
  // =========================================================================
  /// Replaces '🔥' in streak pills, badges, and momentum counters.
  static const IconData flame = PhosphorIconsFill.flame;
  static const IconData flameOutline = PhosphorIconsRegular.flame;

  /// Replaces '🪙' in cultural coins balances, tipping badges, and payouts.
  static const IconData coin = PhosphorIconsFill.coin;
  static const IconData coins = PhosphorIconsFill.coins;

  /// Replaces '✨' in AI generation CTA badges, spotlights, and fresh drops.
  static const IconData sparkle = PhosphorIconsFill.sparkle;
  static const IconData sparkleOutline = PhosphorIconsRegular.sparkle;

  /// Replaces '⚡' in energy/credit transactions and quick actions.
  static const IconData lightning = PhosphorIconsFill.lightning;

  /// Replaces '🏆' / '🥇' in leaderboards, milestones, and rank badges.
  static const IconData trophy = PhosphorIconsFill.trophy;
  static const IconData crown = PhosphorIconsFill.crown;

  /// Replaces '🧬' in musical identity and Creator DNA cards.
  static const IconData dna = PhosphorIconsFill.dna;

  /// Verified creator checkmark badge.
  static const IconData verified = PhosphorIconsFill.checkCircle;

  /// Favorite / Like heart.
  static const IconData heart = PhosphorIconsFill.heart;
  static const IconData heartOutline = PhosphorIconsRegular.heart;

  /// Social share network action.
  static const IconData share = PhosphorIconsRegular.shareNetwork;

  /// Kinetic Reels & Clips icon.
  static const IconData reels = PhosphorIconsRegular.filmStrip;

  /// Studio multi-track & waveform icon.
  static const IconData studio = PhosphorIconsRegular.waveform;

  /// Sound pack & instruments kit icon.
  static const IconData soundPack = PhosphorIconsRegular.package;

  /// Pinned anthem push-pin icon.
  static const IconData pin = PhosphorIconsRegular.pushPin;

  /// Cross-platform Studio Analytics icon.
  static const IconData analytics = PhosphorIconsRegular.chartLineUp;

  // =========================================================================
  // 3. Studio, DAW & Producer Cockpit (Replaces Studio Emojis)
  // =========================================================================
  /// Replaces '🎵' in studio songs tab and audio listings.
  static const IconData songs = PhosphorIconsFill.musicNotes;
  static const IconData songsOutline = PhosphorIconsRegular.musicNotes;

  /// Replaces '💿' in releases tab and physical drop manager.
  static const IconData releases = PhosphorIconsFill.disc;
  static const IconData releasesOutline = PhosphorIconsRegular.disc;

  /// Replaces '🎛️' in producer beatstore and DSP mastering mixer.
  static const IconData beatstore = PhosphorIconsFill.slidersHorizontal;
  static const IconData beatstoreOutline = PhosphorIconsRegular.slidersHorizontal;
  static const IconData sliders = PhosphorIconsRegular.slidersHorizontal;

  /// Replaces '🎤' in vocal stem mixer, lyrics, and recording.
  static const IconData vocals = PhosphorIconsFill.microphone;
  static const IconData mic = PhosphorIconsRegular.microphone;

  /// Replaces '🥁' in drums stem mixer channel and rhythmic loops.
  static const IconData drums = PhosphorIconsFill.waveform;

  /// Replaces '🎹' in bass/log-drum, piano, and sketchpad channels.
  static const IconData piano = PhosphorIconsFill.pianoKeys;

  /// Replaces '🎸' in melody/guitar/synth stem channel.
  static const IconData guitar = PhosphorIconsFill.guitar;

  /// AI Studio prompt synthesis and magic wand.
  static const IconData magicWand = PhosphorIconsFill.magicWand;

  /// Voice clone studio tool.
  static const IconData voiceClone = PhosphorIconsRegular.microphoneStage;

  /// DSP Mastering tool.
  static const IconData mastering = PhosphorIconsRegular.faders;

  // =========================================================================
  // 4. Media & Playback Transport Controls
  // =========================================================================
  static const IconData play = PhosphorIconsFill.play;
  static const IconData playOutline = PhosphorIconsRegular.play;
  static const IconData pause = PhosphorIconsFill.pause;
  static const IconData pauseOutline = PhosphorIconsRegular.pause;
  static const IconData skipForward = PhosphorIconsFill.skipForward;
  static const IconData skipBack = PhosphorIconsFill.skipBack;
  static const IconData shuffle = PhosphorIconsRegular.shuffle;
  static const IconData repeat = PhosphorIconsRegular.repeat;
  static const IconData volumeHigh = PhosphorIconsRegular.speakerHigh;
  static const IconData volumeLow = PhosphorIconsRegular.speakerLow;
  static const IconData volumeMute = PhosphorIconsRegular.speakerSlash;
  static const IconData disc = PhosphorIconsRegular.disc;
  static const IconData waveform = PhosphorIconsRegular.waveform;
  static const IconData playlist = PhosphorIconsRegular.playlist;

  // =========================================================================
  // 5. Common UI Actions, Search, Navigation & Settings
  // =========================================================================
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData bell = PhosphorIconsRegular.bell;
  static const IconData bellActive = PhosphorIconsFill.bell;
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData filter = PhosphorIconsRegular.funnel;
  static const IconData sort = PhosphorIconsRegular.sortAscending;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData plus = PhosphorIconsRegular.plus;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData checkCircle = PhosphorIconsFill.checkCircle;
  static const IconData arrowLeft = PhosphorIconsRegular.arrowLeft;
  static const IconData arrowRight = PhosphorIconsRegular.arrowRight;
  static const IconData caretLeft = PhosphorIconsRegular.caretLeft;
  static const IconData caretRight = PhosphorIconsRegular.caretRight;
  static const IconData caretDown = PhosphorIconsRegular.caretDown;
  static const IconData caretUp = PhosphorIconsRegular.caretUp;
  static const IconData dotsVertical = PhosphorIconsRegular.dotsThreeVertical;
  static const IconData dotsHorizontal = PhosphorIconsRegular.dotsThree;
  static const IconData chat = PhosphorIconsRegular.chatCircle;
  static const IconData remix = PhosphorIconsRegular.arrowsClockwise;
  static const IconData trash = PhosphorIconsRegular.trash;
  static const IconData download = PhosphorIconsRegular.downloadSimple;
  static const IconData upload = PhosphorIconsRegular.uploadSimple;
  static const IconData edit = PhosphorIconsRegular.pencilSimple;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData user = PhosphorIconsRegular.user;
  static const IconData users = PhosphorIconsRegular.users;
}
