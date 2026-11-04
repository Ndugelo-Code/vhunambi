# Phase 43 Requirements: Universal Cross-Platform Native Social Share, Gallery Media Export & Legal Transparency

## 1. Functional Requirements

### Track A: Legal Transparency Modal
- **REQ-LEGAL-01**: Tapping any legal link in `landing_footer.dart` ('Terms of Service', 'Privacy Policy', 'Commercial Licensing', 'Copyright & Takedown') MUST open the `LegalTransparencyModal` (`Key('legal_transparency_modal')`).
- **REQ-LEGAL-02**: The modal MUST clearly present:
  1. The 85% Creator Sovereign Royalty Guarantee.
  2. Commercial Licensing for Stems and Masters.
  3. Ethical Bantu Heritage & Cultural Attribution policies.
  4. Privacy and South African SARB-compliant banking security.

### Track B: Social Post Share Rail
- **REQ-SHARE-01**: Tapping the share button on `ExploreSocialPostCard` (`Key('social_post_share_btn_${post.id}')`) MUST copy the track URL/link to the system clipboard.
- **REQ-SHARE-02**: Tapping share MUST dispatch a notification to `notificationsProvider` under `NotificationCategory.creatorActivity` with title `'Social Link Shared'`.

### Track C: Video Export Modal & Phosphor Syndication
- **REQ-VID-01**: `SocialShareTarget` in `video_export_job.dart` and `video_export_modal.dart` MUST render Phosphor vector icons instead of Unicode emojis.
- **REQ-VID-02**: Invoking `shareTo(target)` in `video_export_provider.dart` MUST dispatch a notification to `notificationsProvider` with title `'Video Export Shared'`.
- **REQ-VID-03**: All text, containers, and borders in `video_export_modal.dart` MUST use dynamic `AppColors.*Of(context)`.

### Track D: Content Studio Export Sheet Modernization
- **REQ-EXP-01**: `export_action_sheet.dart` MUST replace all Material icons with Phosphor icons.
- **REQ-EXP-02**: Tapping 'Share to Socials' or 'Save to Device' MUST notify `notificationsProvider` with persistent receipts under `NotificationCategory.creatorActivity`.

