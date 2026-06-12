import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Thin wrapper around the MQTT client used to sync flight orders between
/// amir / memur1 / memur2.
///
/// Everyone subscribes to a single *retained* state topic. Whenever a device
/// changes an order it republishes the full state (retained), so all devices —
/// including ones that connect afterwards — stay in sync.
class MqttService {
  MqttService({required this.userLabel});

  /// Which user this device is logged in as (amir / memur1 / memur2).
  final String userLabel;

  static const String host = '173.249.32.141';
  static const int port = 1883;
  static const String username = 'app';
  static const String password = 'changeme';
  static const String stateTopic = 'flightorders/state';

  late MqttServerClient _client;

  final _stateController = StreamController<String>.broadcast();
  final _statusController = StreamController<MqttConnectionState>.broadcast();

  /// Emits the raw JSON payload every time the shared state changes.
  Stream<String> get stateStream => _stateController.stream;

  /// Emits connection-state changes so the UI can show a status indicator.
  Stream<MqttConnectionState> get statusStream => _statusController.stream;

  MqttConnectionState get status =>
      _client.connectionStatus?.state ?? MqttConnectionState.disconnected;

  Future<void> connect() async {
    final clientId =
        'flight_${userLabel}_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient.withPort(host, clientId, port)
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..onAutoReconnected = _handleConnected
      ..connectionMessage = (MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean());

    _statusController.add(MqttConnectionState.connecting);
    // ignore: avoid_print
    print('[MQTT] connecting as $clientId ...');
    await _client.connect(username, password);
    // ignore: avoid_print
    print('[MQTT] connect() returned: ${_client.connectionStatus}');

    _client.subscribe(stateTopic, MqttQos.atLeastOnce);
    _client.updates!.listen((events) {
      for (final event in events) {
        final message = event.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          message.payload.message,
        );
        if (event.topic == stateTopic && payload.isNotEmpty) {
          _stateController.add(payload);
        }
      }
    });
  }

  /// Publishes the full state, retained, so it survives for late joiners.
  void publishState(String json) {
    if (status != MqttConnectionState.connected) return;
    final builder = MqttClientPayloadBuilder()..addString(json);
    _client.publishMessage(
      stateTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
    );
  }

  void _handleConnected() {
    // ignore: avoid_print
    print('[MQTT] onConnected');
    _statusController.add(MqttConnectionState.connected);
  }

  void _handleDisconnected() {
    // ignore: avoid_print
    print('[MQTT] onDisconnected');
    _statusController.add(MqttConnectionState.disconnected);
  }

  void dispose() {
    try {
      _client.disconnect();
    } catch (_) {}
    _stateController.close();
    _statusController.close();
  }
}
