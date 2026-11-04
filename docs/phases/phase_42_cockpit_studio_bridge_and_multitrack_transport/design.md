# Phase 42 Design: Cockpit Hardware Player Studio Bridge

## §1. Shell Navigation Synchronization
In `lib/main.dart` `_RootShellState`:
```dart
@override
Widget build(BuildContext context) {
  ref.listen<int>(appNavigationTabProvider, (previous, next) {
    if (next != _currentIndex) {
      _switchTab(next);
    }
  });
  ...
}
```

---

## §2. Remix in Studio Handler
In `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`:
```dart
void _remixInStudio(BuildContext context, Track track) {
  ref.read(studioFormProvider.notifier).setGenre(track.genre);
  ref.read(studioFormProvider.notifier).updatePrompt('Remix of ${track.title} (${track.genre})');
  
  // Switch RootShell to Studio tab (index 2)
  ref.read(appNavigationTabProvider.notifier).state = 2;
  
  ref.read(notificationsProvider.notifier).addNotification(
    NotificationEntity(
      id: 'notif_remix_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Studio Remix Loaded',
      message: 'Loaded "${track.title}" stems into Studio Cockpit.',
      category: NotificationCategory.creatorActivity,
      priority: NotificationPriority.high,
      createdAt: DateTime.now(),
    ),
  );

  Navigator.of(context).pop();
}
```

---

## §3. Hardware DSP LED Toggle Indicator
```dart
Widget _buildHardwareDspLed(BuildContext context) {
  final isMastered = ref.watch(masteringSessionProvider).isMasteredPreviewActive;

  return InkWell(
    key: const Key('cockpit_dsp_led_indicator'),
    onTap: _toggleMasterAB,
    borderRadius: BorderRadius.circular(16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMastered ? AppColors.accentSuccess.withValues(alpha: 0.15) : AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMastered ? AppColors.accentSuccess : AppColors.borderSubtleOf(context),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMastered ? AppColors.accentSuccess : AppColors.textSecondaryOf(context),
              boxShadow: isMastered
                  ? [BoxShadow(color: AppColors.accentSuccess.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isMastered ? 'DSP: ACTIVE' : 'DSP: BYPASS',
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMastered ? AppColors.accentSuccess : AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    ),
  );
}
```

