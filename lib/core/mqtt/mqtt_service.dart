import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// A message received from the broker.
class BrokerMessage {
  const BrokerMessage(this.topic, this.payload);
  final String topic;
  final String payload;
}

/// An MQTT Last Will — published by the broker on the client's behalf if the
/// client drops without a clean disconnect. Used so memurs learn the master
/// went offline.
class MqttWill {
  const MqttWill({
    required this.topic,
    required this.payload,
    this.retain = true,
  });
  final String topic;
  final String payload;
  final bool retain;
}

/// Generic MQTT transport: connect with a set of subscriptions (and optional
/// Last Will), publish to any topic, and receive every message as a stream.
///
/// It carries no app semantics — the orders controller decides which topics to
/// use for state, requests, and presence.
/// Which broker endpoint to dial.
enum MqttConnectionMode { ssl, ip }

/// A broker endpoint: where to connect and whether to wrap it in TLS.
///
/// Two presets matching the staging server:
/// - [ssl]: `stagingenvironment.space:8883` — nginx terminates TLS and forwards
///   to the broker. Encrypted, cert-validated against the system trust store.
/// - [ip]: `173.249.32.141:1883` — straight to mosquitto, no encryption.
class MqttEndpoint {
  const MqttEndpoint({
    required this.mode,
    required this.host,
    required this.port,
    required this.secure,
  });

  final MqttConnectionMode mode;
  final String host;
  final int port;
  final bool secure;

  static const ssl = MqttEndpoint(
    mode: MqttConnectionMode.ssl,
    host: 'stagingenvironment.space',
    port: 8883,
    secure: true,
  );

  static const ip = MqttEndpoint(
    mode: MqttConnectionMode.ip,
    host: '173.249.32.141',
    port: 1883,
    secure: false,
  );

  static MqttEndpoint of(MqttConnectionMode mode) =>
      mode == MqttConnectionMode.ssl ? ssl : ip;

  String get title => mode == MqttConnectionMode.ssl ? 'SSL' : 'Plain IP';
  String get summary => '$host:$port${secure ? '  ·  TLS' : ''}';
}

class MqttService {
  MqttService({required this.clientLabel, this.endpoint = MqttEndpoint.ssl});

  /// Used to build a unique, human-readable client id (e.g. the user id).
  final String clientLabel;

  /// Where to connect and whether to use TLS.
  final MqttEndpoint endpoint;

  static const String username = 'app';
  static const String password = 'changeme';

  late MqttServerClient _client;

  final _messages = StreamController<BrokerMessage>.broadcast();
  final _statusController = StreamController<MqttConnectionState>.broadcast();

  Stream<BrokerMessage> get messages => _messages.stream;
  Stream<MqttConnectionState> get statusStream => _statusController.stream;

  MqttConnectionState get status =>
      _client.connectionStatus?.state ?? MqttConnectionState.disconnected;

  Future<void> connect({
    required List<String> subscriptions,
    MqttWill? will,
  }) async {
    final clientId =
        'flight_${clientLabel}_${DateTime.now().millisecondsSinceEpoch}';

    final connectMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    if (will != null) {
      connectMessage
          .withWillTopic(will.topic)
          .withWillMessage(will.payload)
          .withWillQos(MqttQos.atLeastOnce);
      if (will.retain) connectMessage.withWillRetain();
    }

    _client = MqttServerClient.withPort(endpoint.host, clientId, endpoint.port)
      // TLS for the SSL endpoint; the default SecurityContext validates the
      // Let's Encrypt cert against the platform trust store.
      ..secure = endpoint.secure
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..onAutoReconnected = _handleConnected
      ..connectionMessage = connectMessage;

    _statusController.add(MqttConnectionState.connecting);
    await _client.connect(username, password);

    for (final topic in subscriptions) {
      _client.subscribe(topic, MqttQos.atLeastOnce);
    }
    _client.updates!.listen((events) {
      for (final event in events) {
        final message = event.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          message.payload.message,
        );
        _messages.add(BrokerMessage(event.topic, payload));
      }
    });
  }

  void publish(String topic, String payload, {bool retain = false}) {
    if (status != MqttConnectionState.connected) return;
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retain,
    );
  }

  void _handleConnected() =>
      _statusController.add(MqttConnectionState.connected);

  void _handleDisconnected() =>
      _statusController.add(MqttConnectionState.disconnected);

  void dispose() {
    try {
      _client.disconnect();
    } catch (_) {}
    _messages.close();
    _statusController.close();
  }
}
