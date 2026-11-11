import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

/// Immutable Sovereign authentication & multi-tenant identity session (`Phase 61`).
///
/// Persisted in AES-256 encrypted Tier-0 box [AppConstants.tokenBoxKey] (`vhunambi_tokens`)
/// and projected across all 6 domain providers via [currentCreatorIdProvider].
@immutable
class SovereignAuthSession {
  final String userId;
  final String creatorId;
  final String handle;
  final String displayName;
  final String email;
  final String role;
  final String sessionId;
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
  final bool isGuest;

  const SovereignAuthSession({
    required this.userId,
    required this.creatorId,
    required this.handle,
    required this.displayName,
    required this.email,
    this.role = 'creator',
    this.sessionId = '',
    this.accessToken = '',
    this.refreshToken = '',
    this.expiresAt,
    this.isGuest = true,
  });

  /// Canonical default local studio profile before explicit sign-in.
  factory SovereignAuthSession.guestDefault() {
    return const SovereignAuthSession(
      userId: 'usr_guest_cern',
      creatorId: 'creator_cern',
      handle: '@cern',
      displayName: 'cern',
      email: 'cern@vhunambi.za',
      role: 'creator',
      sessionId: '',
      accessToken: '',
      refreshToken: '',
      expiresAt: null,
      isGuest: true,
    );
  }

  /// True when backed by a signed-in JWT access token.
  bool get isAuthenticated => !isGuest && accessToken.isNotEmpty;

  /// Canonical `creator_<slug>` tenant key guaranteed non-empty.
  String get canonicalCreatorId => canonicalizeCreatorId(creatorId);

  /// Clean username without leading `@`.
  String get rawUsername => extractRawCreatorId(canonicalCreatorId);

  /// Two-character uppercase monogram derived from handle/displayName.
  String get monogram {
    final cleaned = rawUsername.isNotEmpty ? rawUsername : displayName.trim();
    if (cleaned.length >= 2) {
      return cleaned.substring(0, 2).toUpperCase();
    }
    return cleaned.isNotEmpty ? cleaned.toUpperCase() : 'VH';
  }

  /// True if the JWT expires within 60 seconds (or already expired).
  bool get isExpiringSoon {
    if (isGuest || accessToken.isEmpty) return false;
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().toUtc().isAfter(
      exp.toUtc().subtract(const Duration(seconds: 60)),
    );
  }

  /// Auth + tenant headers injected into Sovereign API requests.
  Map<String, String> get authHeaders => <String, String>{
    if (accessToken.isNotEmpty) 'Authorization': 'Bearer $accessToken',
    'X-Vhunambi-Creator-Id': canonicalCreatorId,
  };

  SovereignAuthSession copyWith({
    String? userId,
    String? creatorId,
    String? handle,
    String? displayName,
    String? email,
    String? role,
    String? sessionId,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    bool? isGuest,
  }) {
    return SovereignAuthSession(
      userId: userId ?? this.userId,
      creatorId: creatorId ?? this.creatorId,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      sessionId: sessionId ?? this.sessionId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      isGuest: isGuest ?? this.isGuest,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'userId': userId,
    'creatorId': creatorId,
    'handle': handle,
    'displayName': displayName,
    'email': email,
    'role': role,
    'sessionId': sessionId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    'isGuest': isGuest,
  };

  factory SovereignAuthSession.fromJson(Map<String, dynamic> json) {
    final creatorId = canonicalizeCreatorId(
      json['creatorId']?.toString() ?? json['creator_id']?.toString(),
    );
    final rawHandle = (json['handle'] ?? '').toString().trim();
    final handle = rawHandle.isNotEmpty
        ? (rawHandle.startsWith('@') ? rawHandle : '@$rawHandle')
        : handleFromCreatorId(creatorId);
    final displayName = (json['displayName'] ?? json['display_name'] ?? '')
        .toString()
        .trim();

    return SovereignAuthSession(
      userId: (json['userId'] ?? json['user_id'] ?? 'usr_$creatorId').toString(),
      creatorId: creatorId,
      handle: handle,
      displayName: displayName.isNotEmpty
          ? displayName
          : extractRawCreatorId(creatorId),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'creator').toString(),
      sessionId: (json['sessionId'] ?? json['session_id'] ?? '').toString(),
      accessToken: (json['accessToken'] ?? json['access_token'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? json['refresh_token'] ?? '').toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      isGuest: json['isGuest'] as bool? ??
          ((json['accessToken'] ?? json['access_token'] ?? '').toString().isEmpty),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SovereignAuthSession &&
          userId == other.userId &&
          creatorId == other.creatorId &&
          handle == other.handle &&
          displayName == other.displayName &&
          email == other.email &&
          role == other.role &&
          sessionId == other.sessionId &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresAt == other.expiresAt &&
          isGuest == other.isGuest;

  @override
  int get hashCode => Object.hash(
    userId,
    creatorId,
    handle,
    displayName,
    email,
    role,
    sessionId,
    accessToken,
    refreshToken,
    expiresAt,
    isGuest,
  );
}

