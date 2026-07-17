import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../printing/application/printing_providers.dart';
import '../../printing/domain/printer_device.dart';
import '../application/settings_providers.dart';
import '../domain/shop_profile.dart';

/// Shop profile, receipt and Bluetooth printer configuration (owner only).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const String title = 'Settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _footer = TextEditingController();
  final _gstNumber = TextEditingController();
  final _cashLimit = TextEditingController();
  final _upiId = TextEditingController();
  final _upiName = TextEditingController();
  int _receiptWidth = 80;
  bool _printUpiQr = true;

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    _gstNumber.dispose();
    _cashLimit.dispose();
    _upiId.dispose();
    _upiName.dispose();
    super.dispose();
  }

  void _hydrate(ShopProfile p) {
    if (_loaded) return;
    _loaded = true;
    _name.text = p.shopName;
    _address.text = p.address ?? '';
    _phone.text = p.phone ?? '';
    _footer.text = p.footerText ?? '';
    _gstNumber.text = p.gstNumber ?? '';
    _cashLimit.text = p.gstCashLimit.rupees.toStringAsFixed(0);
    _upiId.text = p.upiId ?? '';
    _upiName.text = p.upiName ?? '';
    _receiptWidth = p.receiptWidth;
    _printUpiQr = p.printUpiQr;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final current = await ref.read(settingsRepositoryProvider).get();
    final limit = double.tryParse(_cashLimit.text.trim()) ?? 10000;
    await ref.read(settingsRepositoryProvider).save(
          current.copyWith(
            shopName: _name.text.trim().isEmpty
                ? 'PSG Padmashree Garments'
                : _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            footerText: _footer.text.trim(),
            receiptWidth: _receiptWidth,
            gstNumber: _gstNumber.text.trim(),
            gstCashLimit: Money.fromRupees(limit),
            upiId: _upiId.text.trim(),
            upiName: _upiName.text.trim(),
            printUpiQr: _printUpiQr,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(shopProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load settings: $e')),
      data: (profile) {
        _hydrate(profile);
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            const _SectionTitle('Shop profile', icon: Icons.storefront_outlined),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Printed at the top of every bill.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Shop name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _address,
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Street, area, city',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _footer,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Bill footer',
                hintText: 'Thank you! Visit again.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Receipt width',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 58, label: Text('58 mm')),
                ButtonSegment(value: 80, label: Text('80 mm')),
              ],
              selected: {_receiptWidth},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _receiptWidth = s.first),
            ),

            const Divider(height: AppSpacing.xxxl),
            const _SectionTitle('Tax / GST', icon: Icons.receipt_long_outlined),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The GST number is printed on the bill only when the bill total is '
              'at or below the cash limit. Bills above the limit hide it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _gstNumber,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'GST number (GSTIN)',
                hintText: '29AEXPJ3122K1Z1',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _cashLimit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cash limit (₹)',
                hintText: '10000',
                prefixText: '₹ ',
                helperText: 'Hide GST number on bills above this amount',
              ),
            ),

            const Divider(height: AppSpacing.xxxl),
            const _SectionTitle('UPI payment QR', icon: Icons.qr_code_2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A QR that fills in the exact bill amount when the customer scans '
              'it with any UPI app (Google Pay, PhonePe, etc.). Shown on screen '
              'and printed on the bill.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _upiId,
              decoration: const InputDecoration(
                labelText: 'UPI ID (VPA)',
                hintText: '8123426350@okbizaxis',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _upiName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Payee name (optional)',
                hintText: 'Defaults to shop name',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show payment QR on bills'),
              value: _printUpiQr,
              onChanged: (v) => setState(() => _printUpiQr = v),
            ),

            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save settings'),
            ),
            const Divider(height: AppSpacing.xxxl),
            const _SectionTitle('Printer', icon: Icons.print_outlined),
            const SizedBox(height: AppSpacing.sm),
            _PrinterSection(profile: profile),
            const Divider(height: AppSpacing.xxxl),
            const _SectionTitle('Users', icon: Icons.people_outline),
            const SizedBox(height: AppSpacing.sm),
            const _UsersSection(),
          ],
        );
      },
    );
  }
}

class _PrinterSection extends ConsumerWidget {
  const _PrinterSection({required this.profile});

  final ShopProfile profile;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final device = await showModalBottomSheet<PrinterDevice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PrinterPickerSheet(),
    );
    if (device != null) {
      await ref
          .read(settingsRepositoryProvider)
          .setPrinter(name: device.name, address: device.address);
    }
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final shop = await ref.read(settingsRepositoryProvider).get();
    final result =
        await ref.read(printerServiceProvider).testPrint(shop);
    if (!context.mounted) return;
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test page sent to printer.')),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  profile.hasPrinter
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: profile.hasPrinter ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.hasPrinter
                            ? (profile.printerName ?? 'Saved printer')
                            : 'No printer selected',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (profile.hasPrinter)
                        Text(
                          profile.printerAddress!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(context, ref),
                  icon: const Icon(Icons.search),
                  label: Text(
                    profile.hasPrinter ? 'Change printer' : 'Select printer',
                  ),
                ),
                if (profile.hasPrinter)
                  FilledButton.tonalIcon(
                    onPressed: () => _test(context, ref),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Test print'),
                  ),
                if (profile.hasPrinter)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(settingsRepositoryProvider)
                        .setPrinter(name: null, address: null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pair the printer in your device\'s Bluetooth settings first, '
              'then select it here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrinterPickerSheet extends ConsumerWidget {
  const _PrinterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(pairedPrintersProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Paired Bluetooth devices',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.invalidate(pairedPrintersProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            devices.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Could not read Bluetooth devices. Make sure Bluetooth is on '
                  'and permissions are granted.',
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'No paired devices found. Pair your printer in the '
                        'phone\'s Bluetooth settings, then tap refresh.',
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final d in list)
                          ListTile(
                            leading: const Icon(Icons.print_outlined),
                            title: Text(d.name),
                            subtitle: Text(d.address),
                            onTap: () => Navigator.pop(context, d),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner-only: lists all users and lets the owner add / deactivate staff.
class _UsersSection extends ConsumerWidget {
  const _UsersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'People who can log in to this device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load users: $e'),
          data: (users) => Card(
            child: Column(
              children: [
                for (final user in users)
                  _UserTile(user: user, currentUserId: currentUser?.id),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => const _AddUserSheet(),
          ),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add staff account'),
        ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.currentUserId});

  final AppUser user;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = user.id == currentUserId;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => _rename(context, ref),
      leading: CircleAvatar(
        backgroundColor: user.isOwner ? scheme.primaryContainer : scheme.secondaryContainer,
        child: Text(
          user.initials,
          style: TextStyle(
            color: user.isOwner ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        user.name + (isMe ? ' (you)' : ''),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${user.isOwner ? 'Owner' : 'Staff'} · tap to rename'),
      trailing: isMe
          ? const Chip(label: Text('You'))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: user.isActive,
                  onChanged: (active) async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .setUserActive(user.id, active: active);
                  },
                ),
                IconButton(
                  tooltip: 'Remove account',
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: user.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || !context.mounted) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .renameUser(user.id, newName);
    if (!context.mounted) return;
    result.fold(
      (_) {},
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
          '"${user.name}" will no longer be able to log in. Past bills they '
          'created are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result =
        await ref.read(authControllerProvider.notifier).deleteUser(user.id);
    if (!context.mounted) return;
    result.fold(
      (_) {},
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }
}

/// Bottom sheet form to add a new staff or owner account.
class _AddUserSheet extends ConsumerStatefulWidget {
  const _AddUserSheet();

  @override
  ConsumerState<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends ConsumerState<_AddUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  bool _isOwner = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref.read(authControllerProvider.notifier).addUser(
          name: _name.text.trim(),
          pin: _pin.text,
          isOwner: _isOwner,
        );

    if (!mounted) return;

    result.fold(
      (_) => Navigator.of(context).pop(),
      (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN (4–6 digits)',
                counterText: '',
              ),
              validator: (v) {
                if (v == null || v.length < 4) {
                  return 'PIN must be at least 4 digits.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Owner access'),
              subtitle: const Text('Can manage products, settings and reports.'),
              value: _isOwner,
              onChanged: (v) => setState(() => _isOwner = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_outlined),
              label: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
