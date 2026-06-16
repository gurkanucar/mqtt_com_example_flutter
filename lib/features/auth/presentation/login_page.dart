import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mqtt/mqtt_mode_provider.dart';
import '../../../core/mqtt/mqtt_service.dart';
import '../../orders/presentation/orders_page.dart';
import '../application/session.dart';
import '../domain/app_user.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.flight_takeoff,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Flight Orders',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Select a user to sign in',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 32),
                const _ConnectionModeSelector(),
                const SizedBox(height: 24),
                for (final user in kUsers) ...[
                  _UserCard(user: user),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the user choose how to reach the broker before signing in:
/// SSL via the subdomain, or a plain connection to the raw IP.
class _ConnectionModeSelector extends ConsumerWidget {
  const _ConnectionModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(mqttModeProvider);
    final endpoint = MqttEndpoint.of(mode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Connection', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<MqttConnectionMode>(
          segments: const [
            ButtonSegment(
              value: MqttConnectionMode.ssl,
              label: Text('SSL'),
              icon: Icon(Icons.lock_outline),
            ),
            ButtonSegment(
              value: MqttConnectionMode.ip,
              label: Text('IP'),
              icon: Icon(Icons.lan_outlined),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) =>
              ref.read(mqttModeProvider.notifier).set(selection.first),
        ),
        const SizedBox(height: 6),
        Text(
          endpoint.summary,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: user.isMaster
              ? theme.colorScheme.primary
              : theme.colorScheme.secondaryContainer,
          child: Icon(
            user.isMaster ? Icons.star : Icons.person,
            color: user.isMaster
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title:
            Text(user.id, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(user.isMaster ? 'Master' : 'Officer'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(sessionProvider.notifier).login(user);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrdersPage()),
          );
        },
      ),
    );
  }
}
