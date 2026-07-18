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

/// Local (offline-first) implementation of the two-password access model.
///
/// The password entered at login is checked against every active account's
/// stored hash; the first match's role decides which interface opens. Admin is
/// checked before Staff so it always wins if the two ever share a password.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required UsersDao usersDao, required PinHasher hasher})
      : _usersDao = usersDao,
        _hasher = hasher;

  final UsersDao _usersDao;
  final PinHasher _hasher;

  static const int _minLength = 4;
  static const String _adminName = 'OWNER';
  static const String _staffName = 'owner';

  @override
  Future<bool> hasAnyUser() => _usersDao.hasAny();

  @override
  Future<Result<AppUser>> login(String password) async {
    try {
      final users = await _usersDao.activeUsers();
      // Admin (owner) first, then staff — deterministic if passwords collide.
      users.sort((a, b) => a.role == UserRole.owner ? -1 : 1);
      for (final user in users) {
        final hash = user.pinHash;
        if (hash != null && _hasher.verify(password, hash)) {
          return Result.success(_toDomain(user));
        }
      }
      return const Result.failure(AuthFailure('Incorrect password.'));
    } catch (e, st) {
      AppLogger.e('Login failed', error: e, stackTrace: st);
      return const Result.failure(
        AuthFailure('Could not sign in. Please try again.'),
      );
    }
  }

  @override
  Future<Result<void>> createInitialAccounts({
    required String adminPassword,
    required String staffPassword,
  }) async {
    if (adminPassword.length < _minLength || staffPassword.length < _minLength) {
      return const Result.failure(
        ValidationFailure('Each password must be at least $_minLength characters.'),
      );
    }
    if (adminPassword == staffPassword) {
      return const Result.failure(
        ValidationFailure('The Admin and Staff passwords must be different.'),
      );
    }
    try {
      await _usersDao.save(
        UsersCompanion.insert(
          name: _adminName,
          role: UserRole.owner,
          pinHash: Value(_hasher.hash(adminPassword)),
        ),
      );
      await _usersDao.save(
        UsersCompanion.insert(
          name: _staffName,
          role: UserRole.staff,
          pinHash: Value(_hasher.hash(staffPassword)),
        ),
      );
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Create accounts failed', error: e, stackTrace: st);
      return const Result.failure(
        UnexpectedFailure('Could not create the accounts.'),
      );
    }
  }

  @override
  Future<Result<void>> setPassword({
    required UserRole role,
    required String password,
  }) async {
    if (password.length < _minLength) {
      return const Result.failure(
        ValidationFailure('Password must be at least $_minLength characters.'),
      );
    }
    try {
      final users = await _usersDao.activeUsers();
      final existing = users.where((u) => u.role == role).toList();
      final hash = _hasher.hash(password);
      if (existing.isEmpty) {
        await _usersDao.save(
          UsersCompanion.insert(
            name: role == UserRole.owner ? _adminName : _staffName,
            role: role,
            pinHash: Value(hash),
          ),
        );
      } else {
        await _usersDao.setPinHash(existing.first.id, hash);
      }
      return const Result.success(null);
    } catch (e, st) {
      AppLogger.e('Set password failed', error: e, stackTrace: st);
      return const Result.failure(
        UnexpectedFailure('Could not update the password.'),
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
