// Throwaway check: confirms the broker accepts app/changeme and that a
// retained publish from one client is delivered to a second client.
// Run with: dart run tool/connectivity_check.dart
// ignore_for_file: avoid_print
import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const host = '173.249.32.141';
const port = 1883;
const user = 'app';
const pass = 'changeme';
const topic = 'flightorders/state';

Future<MqttServerClient> connect(String id) async {
  final c = MqttServerClient.withPort(host, id, port)
    ..keepAlivePeriod = 20
    ..logging(on: false)
    ..connectionMessage =
        (MqttConnectMessage().withClientIdentifier(id).startClean());
  await c.connect(user, pass);
  return c;
}

Future<void> main() async {
  print('Connecting publisher (amir)...');
  final amir = await connect('check_amir_${DateTime.now().microsecondsSinceEpoch}');
  print('  state: ${amir.connectionStatus?.state}');

  final payload = '{"flights":{"TK1234":{"Coffee":2,"Sandwich":0,"Water":1}}}';
  final builder = MqttClientPayloadBuilder()..addString(payload);
  amir.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
  print('Published retained state.');

  await Future.delayed(const Duration(seconds: 1));

  print('Connecting subscriber (memur1)...');
  final memur =
      await connect('check_memur_${DateTime.now().microsecondsSinceEpoch}');

  final completer = Completer<String>();
  memur.updates!.listen((events) {
    final msg = events.first.payload as MqttPublishMessage;
    final text = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
    if (!completer.isCompleted) completer.complete(text);
  });
  memur.subscribe(topic, MqttQos.atLeastOnce);

  final received = await completer.future.timeout(const Duration(seconds: 5),
      onTimeout: () => 'TIMEOUT — no retained message received');
  print('memur1 received retained state: $received');

  final ok = received == payload;
  print(ok ? 'PASS: retained sync works.' : 'FAIL: payload mismatch.');

  amir.disconnect();
  memur.disconnect();
}
