import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../data/local/app_database.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/capability.dart';
import '../../application/billing_providers.dart';
import '../../application/cart_controller.dart';
import 'amount_dialog.dart';

Future<void> showComboPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ComboPickerSheet(),
  );
}

class _ComboPickerSheet extends ConsumerStatefulWidget {
  const _ComboPickerSheet();

  @override
  ConsumerState<_ComboPickerSheet> createState() => _ComboPickerSheetState();
}

class _ComboPickerSheetState extends ConsumerState<_ComboPickerSheet> {
  ComboShirt? _shirt;
  ComboPant? _pant;

  Future<String?> _promptItemName(String type) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add combo $type'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Item name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(dialogContext).pop(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _addComboItem({required bool shirt}) async {
    final type = shirt ? 'shirt' : 'pant';
    final name = await _promptItemName(type);
    if (name == null || !mounted) return;
    final price = await promptAmount(context, title: 'Price — $name');
    if (price == null) return;
    final dao = ref.read(databaseProvider).combosDao;
    if (shirt) {
      await dao.addShirt(name, price.paise);
    } else {
      await dao.addPant(name, price.paise);
    }
  }

  Future<void> _editShirtPrice(ComboShirt shirt) async {
    final value = await promptAmount(
      context,
      title: 'Edit price — ${shirt.name}',
      initial: Money(shirt.pricePaise),
    );
    if (value != null) {
      await ref
          .read(databaseProvider)
          .combosDao
          .updateShirtPrice(shirt.id, value.paise);
      // If the currently selected shirt was edited, update the selection so
      // the displayed total reflects the new price.
      if (_shirt?.id == shirt.id) {
        setState(() => _shirt = shirt.copyWith(pricePaise: value.paise));
      }
    }
  }

  Future<void> _editPantPrice(ComboPant pant) async {
    final value = await promptAmount(
      context,
      title: 'Edit price — ${pant.name}',
      initial: Money(pant.pricePaise),
    );
    if (value != null) {
      await ref
          .read(databaseProvider)
          .combosDao
          .updatePantPrice(pant.id, value.paise);
      if (_pant?.id == pant.id) {
        setState(() => _pant = pant.copyWith(pricePaise: value.paise));
      }
    }
  }

  void _addToCart() {
    final shirt = _shirt;
    final pant = _pant;
    if (shirt == null || pant == null) return;
    ref.read(cartProvider.notifier).addCombo(
          shirtName: shirt.name,
          shirtPrice: Money(shirt.pricePaise),
          pantName: pant.name,
          pantPrice: Money(pant.pricePaise),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final shirts = ref.watch(comboShirtsProvider);
    final pants = ref.watch(comboPantsProvider);
    final canEdit = ref.watch(canProvider(Capability.manageProducts));
    final scheme = Theme.of(context).colorScheme;

    final comboTotal = _shirt != null && _pant != null
        ? Money(_shirt!.pricePaise) + Money(_pant!.pricePaise)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select a Shirt',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6A0DAD),
                            ),
                      ),
                    ),
                    if (canEdit)
                      TextButton.icon(
                        onPressed: () => _addComboItem(shirt: true),
                        icon: const Icon(Icons.add),
                        label: const Text('Add shirt'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                shirts.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (list) => Column(
                    children: [
                      for (final s in list)
                        _ItemTile(
                          name: s.name,
                          price: Money(s.pricePaise),
                          selected: _shirt?.id == s.id,
                          canEdit: canEdit,
                          onTap: () => setState(() {
                            _shirt = s;
                            _pant = null; // reset pant when shirt changes
                          }),
                          onEdit: () => _editShirtPrice(s),
                        ),
                    ],
                  ),
                ),
                if (_shirt != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: scheme.primary, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${_shirt!.name}  ·  ${Money(_shirt!.pricePaise).formatted}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select a Pant',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF005B96),
                                  ),
                        ),
                      ),
                      if (canEdit)
                        TextButton.icon(
                          onPressed: () => _addComboItem(shirt: false),
                          icon: const Icon(Icons.add),
                          label: const Text('Add pant'),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  pants.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (list) => Column(
                      children: [
                        for (final p in list)
                          _ItemTile(
                            name: p.name,
                            price: Money(p.pricePaise),
                            selected: _pant?.id == p.id,
                            canEdit: canEdit,
                            onTap: () => setState(() => _pant = p),
                            onEdit: () => _editPantPrice(p),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (comboTotal != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Combo total',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          comboTotal.formatted,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _addToCart,
                      child: const Text('Add Combo to Cart'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.name,
    required this.price,
    required this.selected,
    required this.canEdit,
    required this.onTap,
    required this.onEdit,
  });

  final String name;
  final Money price;
  final bool selected;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 20)
              else
                Icon(Icons.radio_button_unchecked,
                    color: scheme.onSurfaceVariant, size: 20,),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                price.formatted,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: scheme.onSurfaceVariant,),
                  onPressed: onEdit,
                  tooltip: 'Edit price',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
