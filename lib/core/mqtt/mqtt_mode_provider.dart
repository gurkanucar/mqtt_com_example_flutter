import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mqtt_service.dart';

/// The broker endpoint the user picked on the login screen: SSL via the
/// subdomain, or a plain connection to the raw IP.
///
/// The orders controller `watch`es this, so flipping it tears down the old
/// connection and reconnects against the new endpoint.
class MqttModeNotifier extends Notifier<MqttConnectionMode> {
  @override
  MqttConnectionMode build() => MqttConnectionMode.ssl;

  void set(MqttConnectionMode mode) => state = mode;
}

final mqttModeProvider =
    NotifierProvider<MqttModeNotifier, MqttConnectionMode>(
  MqttModeNotifier.new,
);
