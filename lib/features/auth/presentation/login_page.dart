import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
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
        onTap: () => _signIn(context, user),
      ),
    );
  }

  void _signIn(BuildContext context, AppUser user) {
    // Open a fresh ProviderScope for this session so the orders controller and
    // its MQTT connection are scoped to the chosen user and disposed on logout.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(user)],
        child: const OrdersPage(),
      ),
    ));
  }
}
