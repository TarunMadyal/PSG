import '../../../core/enums.dart';

/// A logged-in (or selectable) user, decoupled from the database row so the UI
/// and use-cases never depend on Drift types.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.isActive = true,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? phone;
  final String? email;
  final bool isActive;

  bool get isOwner => role == UserRole.owner;

  /// Initials for compact avatars in the user picker.
  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}
