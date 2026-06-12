import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';

/// The currently signed-in user (null when on the login screen).
///
/// A plain root-level provider — set on login, cleared on logout. The orders
/// controller `watch`es this, so it (re)connects for the right user and
/// disposes cleanly when the user logs out.
class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  void login(AppUser user) => state = user;
  void logout() => state = null;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, AppUser?>(SessionNotifier.new);
