import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';

/// The signed-in user for a given navigation subtree.
///
/// This is overridden with `overrideWithValue(user)` in a nested
/// [ProviderScope] when navigating to the orders screen, so every screen below
/// it (and the orders controller) sees the user that logged in.
final currentUserProvider = Provider<AppUser>(
  (ref) => throw StateError('currentUserProvider must be overridden'),
);
