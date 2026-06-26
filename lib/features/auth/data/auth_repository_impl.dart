import 'package:drift/drift.dart';

import '../../../core/enums.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/daos/users_dao.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// Local (offline-first) implementation of [AuthRepository] backed by the Drift
/// [UsersDao]. PINs are verified against PBKDF2 hashes stored on-device.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required UsersDao usersDao, required PinHasher hasher})
      : _usersDao = usersDao,
        _hasher = hasher;

  final UsersDao _usersDao;
  final PinHasher _hasher;

  static const int _minPinLength = 4;

  @override
  Future<bool> hasAnyUser() => _usersDao.hasAny();

  @override
  Future<List<AppUser>> listLoginableUsers() async {
    final rows = await _usersDao.activeUsers();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Result<AppUser>> loginWithPin({
    required String userId,
    required String pin,
  }) async {
    try {
      final user = await _usersDao.getById(userId);
      if (user == null || user.isDeleted || !user.isActive) {
        return const Result.failure(AuthFailure('Account not available.'));
      }
      final hash = user.pinHash;
      if (hash == null || !_hasher.verify(pin, hash)) {
        return const Result.failure(AuthFailure('Incorrect PIN.'));
      }
      return Result.success(_toDomain(user));
    } catch (e, st) {
      AppLogger.e('Login failed', error: e, stackTrace: st);
      return const Result.failure(
        AuthFailure('Could not sign in. Please try again.'),
      );
    }
  }

  @override
  Future<Result<AppUser>> createOwner({
    required String name,
    required String pin,
  }) {
    return createUser(name: name, pin: pin, isOwner: true);
  }

  @override
  Future<Result<AppUser>> createUser({
    required String name,
    required String pin,
    required bool isOwner,
    String? phone,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return const Result.failure(ValidationFailure('Name is required.'));
    }
    if (pin.length < _minPinLength) {
      return const Result.failure(
        ValidationFailure('PIN must be at least $_minPinLength digits.'),
      );
    }

    try {
      final companion = UsersCompanion.insert(
        name: trimmedName,
        role: isOwner ? UserRole.owner : UserRole.staff,
        phone: Value(phone),
        pinHash: Value(_hasher.hash(pin)),
      );
      final created = await _usersDao.save(companion);
      return Result.success(_toDomain(created));
    } catch (e, st) {
      AppLogger.e('Create user failed', error: e, stackTrace: st);
      return const Result.failure(
        UnexpectedFailure('Could not create the account.'),
      );
    }
  }

  AppUser _toDomain(User u) => AppUser(
        id: u.id,
        name: u.name,
        role: u.role,
        phone: u.phone,
        email: u.email,
        isActive: u.isActive,
      );
}
