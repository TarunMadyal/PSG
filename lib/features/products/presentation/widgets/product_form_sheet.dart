import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../application/product_providers.dart';
import '../../domain/product_item.dart';

/// Opens the add/edit product form as a modal bottom sheet. Pass [existing] to
/// edit. Returns true if a product was saved.
Future<bool?> showProductFormSheet(
  BuildContext context, {
  ProductItem? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProductFormSheet(existing: existing),
  );
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  const _ProductFormSheet({this.existing});

  final ProductItem? existing;

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _c = {
      'name': TextEditingController(text: e?.name ?? ''),
      'category': TextEditingController(text: e?.category ?? ''),
      'brand': TextEditingController(text: e?.brand ?? ''),
      'size': TextEditingController(text: e?.size ?? ''),
      'color': TextEditingController(text: e?.color ?? ''),
      'sku': TextEditingController(text: e?.sku ?? ''),
      'barcode': TextEditingController(text: e?.barcode ?? ''),
      'price': TextEditingController(
        text: e == null ? '' : e.price.rupees.toStringAsFixed(2),
      ),
      'cost': TextEditingController(
        text: e?.cost == null ? '' : e!.cost!.rupees.toStringAsFixed(2),
      ),
      'stock': TextEditingController(text: e == null ? '0' : '${e.stock}'),
      'reorder': TextEditingController(
        text: e == null ? '0' : '${e.reorderLevel}',
      ),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(String key) {
    final v = _c[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final draft = ProductDraft(
      name: _c['name']!.text.trim(),
      category: _t('category'),
      brand: _t('brand'),
      size: _t('size'),
      color: _t('color'),
      sku: _t('sku'),
      barcode: _t('barcode'),
      price: Money.fromRupees(double.tryParse(_c['price']!.text.trim()) ?? 0),
      cost: _t('cost') == null
          ? null
          : Money.fromRupees(double.parse(_c['cost']!.text.trim())),
      stock: int.tryParse(_c['stock']!.text.trim()) ?? 0,
      reorderLevel: int.tryParse(_c['reorder']!.text.trim()) ?? 0,
    );

    final result = await ref
        .read(productRepositoryProvider)
        .save(draft, id: widget.existing?.id);

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (_) => Navigator.of(context).pop(true),
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl + bottomInset,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit ? 'Edit product' : 'New product',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _field('name', 'Product name', required: true),
                _twoUp(_field('brand', 'Brand'), _field('category', 'Category')),
                _twoUp(_field('size', 'Size'), _field('color', 'Colour')),
                _twoUp(_field('sku', 'SKU'), _field('barcode', 'Barcode')),
                _twoUp(
                  _field('price', 'Price (₹)', number: true, required: true),
                  _field('cost', 'Cost (₹)', number: true),
                ),
                _twoUp(
                  _field('stock', 'Stock', integer: true),
                  _field('reorder', 'Reorder at', integer: true),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Save changes' : 'Add product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _twoUp(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: b),
        ],
      );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: _c[key],
        decoration: InputDecoration(labelText: label),
        keyboardType: (number || integer)
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: integer
            ? [FilteringTextInputFormatter.digitsOnly]
            : number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
        textCapitalization:
            (number || integer) ? TextCapitalization.none : TextCapitalization.words,
        validator: (value) {
          final v = value?.trim() ?? '';
          if (required && v.isEmpty) return 'Required';
          if (number && v.isNotEmpty && double.tryParse(v) == null) {
            return 'Invalid number';
          }
          return null;
        },
      ),
    );
  }
}
