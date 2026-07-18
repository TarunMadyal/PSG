import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/enums.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/file_share.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_controller.dart';
import '../../printing/application/printing_providers.dart';
import '../../printing/domain/printer_device.dart';
import '../application/settings_providers.dart';
import '../data/sales_export.dart';
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
  final _upiId = TextEditingController();
  final _upiName = TextEditingController();
  int _receiptWidth = 80;
  bool _printGstOnCash = false;

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    _gstNumber.dispose();
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
    _upiId.text = p.upiId ?? '';
    _upiName.text = p.upiName ?? '';
    _receiptWidth = p.receiptWidth;
    _printGstOnCash = p.printGstOnCash;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final current = await ref.read(settingsRepositoryProvider).get();
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
            upiId: _upiId.text.trim(),
            upiName: _upiName.text.trim(),
            printGstOnCash: _printGstOnCash,
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
              'UPI and Cash+UPI bills always print the GST number. For cash-only '
              'bills, use the toggle below.',
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Print GST Number on Cash Bills'),
              subtitle: const Text(
                'Off: cash bills do not show the GST number. UPI bills always do.',
              ),
              value: _printGstOnCash,
              onChanged: (v) => setState(() => _printGstOnCash = v),
            ),

            const Divider(height: AppSpacing.xxxl),
            const _SectionTitle('UPI payment QR', icon: Icons.qr_code_2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A QR that fills in the amount due when the customer scans it with '
              'any UPI app. It is shown and printed automatically for UPI and '
              'Cash+UPI bills, never for cash-only bills.',
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
            const _SectionTitle('Backup / Export', icon: Icons.backup_outlined),
            const SizedBox(height: AppSpacing.sm),
            const _BackupSection(),
            const Divider(height: AppSpacing.xxxl),
            const _SectionTitle('Passwords', icon: Icons.lock_outline),
            const SizedBox(height: AppSpacing.sm),
            const _PasswordsSection(),
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

/// Export a CSV backup of all sales, shared via the system share sheet
/// (Google Drive, email, WhatsApp) — off-device records safety and CA hand-off.
class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(databaseProvider);
      final csv = await buildSalesCsv(db);
      final stamp = Formatters.date(DateTime.now()).replaceAll(' ', '-');
      await shareBytes(
        utf8.encode(csv),
        filename: 'psg-sales-$stamp.csv',
        subject: 'PSG Padmashree Garments — sales export',
        text: 'Sales records attached.',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Export every sale to a CSV file you can save to Google Drive, email, '
          'or send to your CA. Do this regularly so a lost or broken tablet '
          'never loses your records.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _export,
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: const Text('Export sales (CSV)'),
        ),
      ],
    );
  }
}

/// Admin-only: change the two access passwords (Admin and Staff).
class _PasswordsSection extends ConsumerWidget {
  const _PasswordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Two passwords control access. The Admin password opens full access; '
          'the Staff password opens billing only. The password entered at login '
          'decides which opens.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin password'),
                subtitle: const Text('Full access'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _change(context, ref, UserRole.owner, 'Admin'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Staff password'),
                subtitle: const Text('Billing only'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _change(context, ref, UserRole.staff, 'Staff'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
    String label,
  ) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Change $label password'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'At least 4 characters',
          ),
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
    if (password == null || !context.mounted) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .changePassword(role: role, password: password);
    if (!context.mounted) return;
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label password updated.')),
      ),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
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
