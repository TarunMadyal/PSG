import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/customers_providers.dart';

/// Customer directory — names/phones captured during billing. Optional: sales
/// can always be billed anonymously.
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  static const String title = 'Customers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final scheme = Theme.of(context).colorScheme;

    return customers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load customers: $e')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No customers yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add a phone number at checkout to start keeping history.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = list[i];
            final name = (c.name == null || c.name!.isEmpty) ? 'Customer' : c.name!;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              title: Text(name),
              subtitle: c.phone == null ? null : Text(c.phone!),
            );
          },
        );
      },
    );
  }
}
