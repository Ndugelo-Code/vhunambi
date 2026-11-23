import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

/// Deterministic viewer ownership classification for Track & Creator domains
/// (`EP-P70-VIEWER-ROLE`, `REQ-P70-ROLE-01..02`).
enum ViewerRole {
  /// The signed-in creator owns this track/resource and has full studio access.
  owner,

  /// An outside listener or follower viewing another creator's work.
  visitor,
}

const Set<String> _localSeedOwnerAliases = <String>{
  'me',
  'usr_me',
  'user_current',
  'current_user',
  'creator_me',
  'ai_studio',
  'aistudio',
  'creator_ai_studio',
  'creator_aistudio',
};

/// Resolves whether the active signed-in user owns a resource attributed to
/// [ownerCreatorId] / [ownerHandle] (`REQ-P70-ROLE-01..02`).
///
/// Fails closed to [ViewerRole.visitor] whenever [ownerCreatorId] and
/// [ownerHandle] are both blank, or belong to a different creator (`@lerato`,
/// `@fifi`, `@makhadzi`, etc.).
ViewerRole resolveViewerRole({
  required String? ownerCreatorId,
  String? ownerHandle,
  required String activeCreatorId,
  String? activeHandle,
}) {
  final rawOwnerId = (ownerCreatorId ?? '').trim().toLowerCase();
  final rawOwnerHandle = (ownerHandle ?? '').trim().toLowerCase().replaceFirst(
    RegExp(r'^@+'),
    '',
  );

  if (rawOwnerId.isEmpty && rawOwnerHandle.isEmpty) {
    return ViewerRole.visitor;
  }

  final canonicalActive = canonicalizeCreatorId(activeCreatorId);
  final activeSlug = extractRawCreatorId(canonicalActive).toLowerCase();
  final normalizedActiveHandle = (activeHandle ?? '')
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^@+'), '');

  // Explicit local-user placeholder aliases created in offline/demo studio flows.
  if (_localSeedOwnerAliases.contains(rawOwnerId) ||
      _localSeedOwnerAliases.contains(rawOwnerHandle)) {
    return ViewerRole.owner;
  }

  if (rawOwnerId.isNotEmpty) {
    final canonicalOwner = canonicalizeCreatorId(
      rawOwnerId,
      fallback: '__unowned__',
    );
    if (canonicalOwner != '__unowned__' && canonicalOwner == canonicalActive) {
      return ViewerRole.owner;
    }
    final ownerSlug = extractRawCreatorId(rawOwnerId).toLowerCase();
    if (ownerSlug.isNotEmpty &&
        (ownerSlug == activeSlug ||
            (normalizedActiveHandle.isNotEmpty &&
                ownerSlug == normalizedActiveHandle))) {
      return ViewerRole.owner;
    }
  }

  if (rawOwnerHandle.isNotEmpty) {
    final canonicalHandleOwner = canonicalizeCreatorId(
      rawOwnerHandle,
      fallback: '__unowned__',
    );
    if (canonicalHandleOwner != '__unowned__' &&
        canonicalHandleOwner == canonicalActive) {
      return ViewerRole.owner;
    }
    if (normalizedActiveHandle.isNotEmpty &&
        rawOwnerHandle == normalizedActiveHandle) {
      return ViewerRole.owner;
    }
  }

  return ViewerRole.visitor;
}
