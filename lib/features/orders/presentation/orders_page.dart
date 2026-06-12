import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session.dart';
import '../application/orders_controller.dart';
import '../domain/order_state.dart';
import 'widgets/flight_selector.dart';
import 'widgets/product_tile.dart';
import 'widgets/status_indicator.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final state = ref.watch(ordersControllerProvider);
    final controller = ref.read(ordersControllerProvider.notifier);

    final flights = state.orders.flights.keys.toList()..sort();
    final selected =
        flights.contains(state.selectedFlight) ? state.selectedFlight : flights.first;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(user.id),
            const SizedBox(width: 8),
            if (user.isMaster)
              const Chip(
                label: Text('MASTER'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
        actions: [
          StatusIndicator(status: state.status),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null)
            _ErrorBanner(message: state.error!, onRetry: controller.connect),
          FlightSelector(
            flights: flights,
            selected: selected,
            onChanged: controller.selectFlight,
            onAdd: () => _addFlight(context, controller),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                for (final product in kProducts)
                  ProductTile(
                    product: product,
                    count: state.orders.count(selected, product),
                    onAdd: () => controller.order(product, 1),
                    onRemove: () => controller.order(product, -1),
                  ),
                if (user.isMaster) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.resetFlight,
                    icon: const Icon(Icons.restart_alt),
                    label: Text('Reset $selected'),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Activity', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                if (state.log.isEmpty)
                  Text('No activity yet.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                for (final line in state.log)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_alt, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                            child:
                                Text(line, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFlight(
      BuildContext context, OrdersController controller) async {
    final textController = TextEditingController();
    final flight = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add flight'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'e.g. TK1234',
            prefixIcon: Icon(Icons.flight),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, textController.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (flight != null) controller.addFlight(flight);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
