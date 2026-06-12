import 'package:flutter/material.dart';

/// A product row with a count and +/- controls.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  final String product;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  IconData get _icon => switch (product) {
        'Coffee' => Icons.local_cafe,
        'Sandwich' => Icons.lunch_dining,
        'Water' => Icons.local_drink,
        _ => Icons.shopping_bag,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(_icon, color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(product, style: theme.textTheme.titleMedium),
            ),
            IconButton.outlined(
              onPressed: count > 0 ? onRemove : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
