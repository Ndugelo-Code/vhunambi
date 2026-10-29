# ── ProGuard & R8 Optimization Rules for VHUNAMBI Client ───────────────────────
# Phase 26: Binary Hardening, Dead Code Elimination, & Media Pipeline Preservation

# 1. Flutter Engine & Plugin Registrant
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Audio Engine (just_audio & audio_service & audio_session)
# Preserve background service lifecycle, MediaBrowserService, and JNI platform channels
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audiosession.** { *; }

# Preserve Android MediaSession and NotificationCompat.MediaStyle
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# 3. Local Persistence & Native IO (Hive, PathProvider, SharedPreferences)
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# 4. Image Caching & Palettes
-keep class io.flutter.plugins.imagepicker.** { *; }

# 5. General Resilience & Suppressed Warnings
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn **

