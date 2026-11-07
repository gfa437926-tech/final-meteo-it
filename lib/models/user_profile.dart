/// Firestore profile model for the two currently supported application roles.
///
/// Legacy profiles without [officeIds] remain readable and are interpreted as
/// having no office assignments. This is intentionally fail-closed: once
/// office-scoped rules are enabled, such IT-manager profiles must be assigned
/// offices by an administrator before they can access scoped records.
class UserProfile {
  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    List<String> officeIds = const [],
    this.createdBy,
  }) : officeIds = List<String>.unmodifiable(_normalizeOfficeIds(officeIds)) {
    if (!supportedRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unsupported user role');
    }
    if (role == adminRole && this.officeIds.isNotEmpty) {
      throw ArgumentError('Global administrators must not carry office assignments');
    }
  }

  static const String adminRole = 'admin';
  static const String itManagerRole = 'it_manager';
  static const Set<String> supportedRoles = {adminRole, itManagerRole};

  final String uid;
  final String displayName;
  final String email;
  final String role;
  final bool isActive;
  final List<String> officeIds;
  final String? createdBy;

  bool get isGlobalAdministrator => role == adminRole;

  bool canAccessOffice(String officeId) =>
      isActive && (isGlobalAdministrator || officeIds.contains(officeId));

  Map<String, Object?> toMap() => {
        'displayName': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        'isActive': isActive,
        // Persist an explicit empty list for admins and assigned manager IDs
        // for IT managers. Never serialize a wildcard/global sentinel.
        'officeIds': officeIds,
        if (createdBy != null) 'createdBy': createdBy,
      };

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    final rawOfficeIds = map['officeIds'];
    if (rawOfficeIds != null &&
        (rawOfficeIds is! List || rawOfficeIds.any((value) => value is! String))) {
      throw const FormatException('officeIds must be a list of strings');
    }

    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? '',
      isActive: map['isActive'] == true,
      officeIds: rawOfficeIds == null
          ? const []
          : (rawOfficeIds as List).cast<String>(),
      createdBy: map['createdBy'] as String?,
    );
  }

  static List<String> _normalizeOfficeIds(List<String> values) {
    final normalized = values.map((value) => value.trim()).toList();
    if (normalized.any((value) => value.isEmpty)) {
      throw ArgumentError('Office IDs cannot be empty');
    }
    if (normalized.toSet().length != normalized.length) {
      throw ArgumentError('Office IDs must be unique');
    }
    return normalized;
  }
}
