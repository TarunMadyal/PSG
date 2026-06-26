import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/numeric_keypad.dart';
import '../application/auth_controller.dart';
import '../domain/app_user.dart';

/// Active accounts for the login picker.
final loginUsersProvider = FutureProvider.autoDispose<List<AppUser>>(
  (ref) => ref.read(authControllerProvider.notifier).loginableUsers(),
);

const int kMaxPinLength = 6;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  AppUser? _selected;
  String _pin = '';
  String? _error;
  bool _busy = false;

  void _onDigit(String d) {
    if (_pin.length >= kMaxPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final user = _selected;
    if (user == null || _pin.length < 4 || _busy) return;

    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .login(userId: user.id, pin: _pin);
    if (!mounted) return;

    setState(() {
      _busy = false;
      result.fold(
        (_) {}, // success → router redirect navigates away
        (failure) {
          _error = failure.message;
          _pin = '';
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(loginUsersProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 64),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Select your account and enter your PIN',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                usersAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Could not load accounts: $e'),
                  data: (users) => _buildContent(users),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<AppUser> users) {
    if (users.isEmpty) {
      return const Text('No accounts found.');
    }
    _selected ??= users.first;

    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          alignment: WrapAlignment.center,
          children: [
            for (final u in users)
              _UserChip(
                user: u,
                selected: u.id == _selected?.id,
                onTap: () => setState(() {
                  _selected = u;
                  _pin = '';
                  _error = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        PinDots(length: kMaxPinLength, filled: _pin.length),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 20,
          child: Text(
            _error ?? '',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_pin.length >= 4 && !_busy) ? _submit : null,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Log in'),
          ),
        ),
      ],
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AppUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primary,
              child: Text(
                user.initials,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
