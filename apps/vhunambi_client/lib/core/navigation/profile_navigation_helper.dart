import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';

/// Resolves whether [creatorId] / [creatorHandle] belongs to the signed-in creator.
bool isOwnedByActiveUser(
  WidgetRef ref, {
  required String? creatorId,
  String? creatorHandle,
}) {
  final owner = ref.read(ownerProfileProvider);
  final session = ref.read(authSessionProvider);
  final activeCreatorId = owner.id.isNotEmpty && owner.id != 'me'
      ? owner.id
      : session.canonicalCreatorId;
  final activeHandle = owner.handle.isNotEmpty
      ? owner.handle
      : session.rawUsername;

  return resolveViewerRole(
        ownerCreatorId: creatorId,
        ownerHandle: creatorHandle,
        activeCreatorId: activeCreatorId,
        activeHandle: activeHandle,
      ) ==
      ViewerRole.owner;
}

/// Canonical profile router (`EP-P73-PROFILE-ROUTER`, `REQ-P73-HYG-01`).
///
/// Routes self-taps to [OwnerProfileView] and visitor taps to [ArtistProfileView].
Future<void> navigateToCreatorProfile(
  BuildContext context,
  WidgetRef ref, {
  required String creatorId,
  String? creatorHandle,
}) {
  final isOwner = isOwnedByActiveUser(
    ref,
    creatorId: creatorId,
    creatorHandle: creatorHandle,
  );
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => isOwner
          ? const OwnerProfileView()
          : ArtistProfileView(artistId: creatorId),
    ),
  );
}
