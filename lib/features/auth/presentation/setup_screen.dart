import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/numeric_keypad.dart';
import '../application/auth_controller.dart';
import 'login_screen.dart' show kMaxPinLength;

enum _Step { name, pin, confirm }

/// First-run setup: creates the shop owner account. Shown when no users exist.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _nameController = TextEditingController();
  _Step _step = _Step.name;
  String _pin = '';
  String _confirm = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _activePin => _step == _Step.confirm ? _confirm : _pin;

  void _onDigit(String d) {
    if (_activePin.length >= kMaxPinLength) return;
    setState(() {
      _error = null;
      if (_step == _Step.confirm) {
        _confirm += d;
      } else {
        _pin += d;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_step == _Step.confirm && _confirm.isNotEmpty) {
        _confirm = _confirm.substring(0, _confirm.length - 1);
      } else if (_step == _Step.pin && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _next() {
    setState(() {
      _error = null;
      switch (_step) {
        case _Step.name:
          if (_nameController.text.trim().isEmpty) {
            _error = 'Please enter your name.';
            return;
          }
          _step = _Step.pin;
        case _Step.pin:
          if (_pin.length < 4) {
            _error = 'PIN must be at least 4 digits.';
            return;
          }
          _step = _Step.confirm;
        case _Step.confirm:
          break;
      }
    });
  }

  Future<void> _finish() async {
    if (_confirm != _pin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _confirm = '';
        _step = _Step.pin;
        _pin = '';
      });
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .createOwnerAndLogin(name: _nameController.text, pin: _pin);
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
              children: [
                const AppLogo(size: 64, showWordmark: true),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_step == _Step.name)
                  _buildNameStep()
                else
                  _buildPinStep(),
                SizedBox(
                  height: 24,
                  child: Center(
                    child: Text(
                      _error ?? '',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_step) {
        _Step.name => 'Set up your shop',
        _Step.pin => 'Create a PIN',
        _Step.confirm => 'Confirm your PIN',
      };

  String get _subtitle => switch (_step) {
        _Step.name => "You're creating the owner account with full access.",
        _Step.pin => 'Choose a 4–6 digit PIN for quick daily login.',
        _Step.confirm => 'Re-enter your PIN to confirm.',
      };

  Widget _buildNameStep() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _next, child: const Text('Continue')),
        ),
      ],
    );
  }

  Widget _buildPinStep() {
    final canProceed = _activePin.length >= 4;
    final isConfirm = _step == _Step.confirm;
    return Column(
      children: [
        PinDots(length: kMaxPinLength, filled: _activePin.length),
        const SizedBox(height: AppSpacing.xl),
        NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canProceed && !_busy
                ? (isConfirm ? _finish : _next)
                : null,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isConfirm ? 'Create account' : 'Continue'),
          ),
        ),
      ],
    );
  }
}
