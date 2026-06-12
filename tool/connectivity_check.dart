// Throwaway check for the master/authority topology.
// Run with: dart run tool/connectivity_check.dart
// Verifies, against the live broker:
//   1. memur receives amir's retained presence  (flightorders/master = online)
//   2. amir receives a memur's order request     (flightorders/requests)
//   3. memur receives amir's published state      (flightorders/state)
// ignore_for_file: avoid_print
import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const host = '173.249.32.141';
const port = 1883;
const user = 'app';
const pass = 'changeme';

const stateTopic = 'flightorders/state';
const requestTopic = 'flightorders/requests';
const masterTopic = 'flightorders/master';

Future<MqttServerClient> connect(String id, {MqttConnectMessage? msg}) async {
  final c = MqttServerClient.withPort(host, id, port)
    ..keepAlivePeriod = 20
    ..logging(on: false)
    ..connectionMessage =
        msg ?? (MqttConnectMessage().withClientIdentifier(id).startClean());
  await c.connect(user, pass);
  return c;
}

void pub(MqttServerClient c, String topic, String payload, {bool retain = false}) {
  final b = MqttClientPayloadBuilder()..addString(payload);
  c.publishMessage(topic, MqttQos.atLeastOnce, b.payload!, retain: retain);
}

Future<String> firstOn(MqttServerClient c, String topic) {
  final completer = Completer<String>();
  c.updates!.listen((events) {
    for (final e in events) {
      if (e.topic == topic && !completer.isCompleted) {
        final m = e.payload as MqttPublishMessage;
        completer.complete(
            MqttPublishPayload.bytesToStringAsString(m.payload.message));
      }
    }
  });
  c.subscribe(topic, MqttQos.atLeastOnce);
  return completer.future
      .timeout(const Duration(seconds: 5), onTimeout: () => 'TIMEOUT');
}

Future<void> main() async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  var pass = true;
  void check(String label, bool ok) {
    print('${ok ? "PASS" : "FAIL"}: $label');
    pass = pass && ok;
  }

  // amir (master) connects with a Last Will and announces online.
  final amir = await connect('check_amir_$stamp',
      msg: MqttConnectMessage()
          .withClientIdentifier('check_amir_$stamp')
          .startClean()
          .withWillTopic(masterTopic)
          .withWillMessage('offline')
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain());
  pub(amir, masterTopic, 'online', retain: true);
  final amirGotRequest = firstOn(amir, requestTopic);

  await Future.delayed(const Duration(milliseconds: 500));

  // memur connects and reads presence + state.
  final memur = await connect('check_memur_$stamp');
  final presence = await firstOn(memur, masterTopic);
  check('memur sees master presence ("$presence")', presence == 'online');

  final memurGotState = firstOn(memur, stateTopic);

  // memur sends an order request; amir should receive it.
  pub(memur, requestTopic,
      '{"by":"memur1","flight":"TK1234","product":"Coffee","delta":1}');
  final request = await amirGotRequest;
  check('amir receives memur request', request.contains('Coffee'));

  // amir publishes the resulting authoritative state; memur should receive it.
  pub(amir, stateTopic,
      '{"flights":{"TK1234":{"Coffee":1,"Sandwich":0,"Water":0}},"lastAction":{"by":"memur1","text":"+1 Coffee on TK1234"}}',
      retain: true);
  final stateMsg = await memurGotState;
  check('memur receives amir state', stateMsg.contains('"Coffee":1'));

  print(pass ? '\nALL PASS' : '\nSOME FAILED');
  amir.disconnect();
  memur.disconnect();
}
