import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_logo.dart';
import '../application/auth_controller.dart';

/// First-run setup: sets the two access passwords (Admin and Staff). Shown when
/// no accounts exist yet.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _admin = TextEditingController();
  final _staff = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _admin.dispose();
    _staff.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(authControllerProvider.notifier).setupAccounts(
          adminPassword: _admin.text,
          staffPassword: _staff.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold((_) {}, (failure) => _error = failure.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AppLogo(size: 64, showWordmark: true)),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Set up your passwords',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Create two passwords. The Admin password unlocks full access; '
                  'the Staff password opens billing only.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _admin,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Admin password',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _staff,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Staff password',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      _error ?? '',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _finish,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create passwords'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
