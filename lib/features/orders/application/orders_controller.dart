import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../../core/mqtt/mqtt_mode_provider.dart';
import '../../../core/mqtt/mqtt_service.dart';
import '../../auth/application/session.dart';
import '../domain/order_state.dart';

/// MQTT topics. amir (master) owns `state` and `master`; memurs send to
/// `requests`.
const String kStateTopic = 'flightorders/state'; // retained, amir publishes
const String kRequestTopic = 'flightorders/requests'; // memurs publish
const String kMasterTopic = 'flightorders/master'; // retained presence

/// Immutable snapshot the orders UI renders from.
class OrdersUiState {
  const OrdersUiState({
    required this.orders,
    required this.selectedFlight,
    required this.status,
    required this.log,
    this.error,
    this.masterOnline,
  });

  final OrderState orders;
  final String selectedFlight;
  final MqttConnectionState status;
  final List<String> log;
  final String? error;

  /// Whether amir (the master) is reachable. `null` = unknown (no banner),
  /// `true` = online, `false` = offline. Always `true` for amir himself.
  final bool? masterOnline;

  factory OrdersUiState.initial() => OrdersUiState(
        orders: OrderState.initial(),
        selectedFlight: kDefaultFlights.first,
        status: MqttConnectionState.disconnected,
        log: const [],
      );

  OrdersUiState copyWith({
    OrderState? orders,
    String? selectedFlight,
    MqttConnectionState? status,
    List<String>? log,
    Object? error = _sentinel,
    Object? masterOnline = _sentinel,
  }) {
    return OrdersUiState(
      orders: orders ?? this.orders,
      selectedFlight: selectedFlight ?? this.selectedFlight,
      status: status ?? this.status,
      log: log ?? this.log,
      error: identical(error, _sentinel) ? this.error : error as String?,
      masterOnline: identical(masterOnline, _sentinel)
          ? this.masterOnline
          : masterOnline as bool?,
    );
  }

  static const _sentinel = Object();
}

/// Owns the MQTT connection and the order state for the logged-in user.
///
/// Behaviour differs by role:
/// - **amir (master):** holds the authoritative state, applies his own actions
///   *and* incoming memur requests, and publishes the official retained state.
/// - **memur (officer):** sends order *requests* and renders only what the
///   master publishes (strict source of truth).
class OrdersController extends Notifier<OrdersUiState> {
  MqttService? _mqtt;
  String _userId = '';
  bool _isMaster = false;

  /// Master only: becomes true once we've adopted retained state on connect OR
  /// taken authority via a local edit. Prevents a late retained message from
  /// clobbering edits made right after connecting.
  bool _bootstrapped = false;

  @override
  OrdersUiState build() {
    final user = ref.watch(sessionProvider);
    if (user == null) return OrdersUiState.initial();

    // Re-runs build() (and thus reconnects) whenever the user flips SSL ⇄ IP.
    final mode = ref.watch(mqttModeProvider);

    _userId = user.id;
    _isMaster = user.isMaster;
    _bootstrapped = false;

    final mqtt =
        MqttService(clientLabel: _userId, endpoint: MqttEndpoint.of(mode));
    _mqtt = mqtt;
    mqtt.messages.listen(_onMessage);
    mqtt.statusStream.listen((s) => state = state.copyWith(status: s));
    ref.onDispose(() {
      // Graceful disconnect won't fire the Last Will, so the master announces
      // offline explicitly before closing.
      if (_isMaster) mqtt.publish(kMasterTopic, 'offline', retain: true);
      mqtt.dispose();
    });

    // Deferred: we must not touch `state` until build() returns.
    Future.microtask(_connect);
    // amir is always "online" to himself; memur starts unknown.
    return OrdersUiState.initial().copyWith(masterOnline: _isMaster ? true : null);
  }

  Future<void> connect() => _connect();

  Future<void> _connect() async {
    final mqtt = _mqtt;
    if (mqtt == null) return;
    state = state.copyWith(error: null);
    try {
      if (_isMaster) {
        await mqtt.connect(
          subscriptions: const [kStateTopic, kRequestTopic],
          will: const MqttWill(topic: kMasterTopic, payload: 'offline'),
        );
        mqtt.publish(kMasterTopic, 'online', retain: true);
      } else {
        await mqtt.connect(subscriptions: const [kStateTopic, kMasterTopic]);
      }
    } catch (e) {
      state = state.copyWith(error: 'Could not connect: $e');
    }
  }

  // ---- user actions -------------------------------------------------------

  void selectFlight(String flight) =>
      state = state.copyWith(selectedFlight: flight);

  /// memur: send a request and wait for the master. amir: apply directly.
  void order(String product, int delta) {
    if (_isMaster) {
      _applyAndPublish(state.selectedFlight, product, delta, _userId);
    } else {
      _mqtt?.publish(
        kRequestTopic,
        jsonEncode({
          'by': _userId,
          'flight': state.selectedFlight,
          'product': product,
          'delta': delta,
        }),
      );
    }
  }

  /// Master only.
  void resetFlight() {
    if (!_isMaster) return;
    _bootstrapped = true;
    final orders = state.orders..resetFlight(state.selectedFlight);
    state = state.copyWith(orders: orders);
    _publishState(orders, by: _userId, action: 'reset ${state.selectedFlight}');
    _pushLogLine('$_userId (you): reset ${state.selectedFlight}');
  }

  /// Master only.
  void addFlight(String rawName) {
    if (!_isMaster) return;
    final name = rawName.trim().toUpperCase();
    if (name.isEmpty) return;
    _bootstrapped = true;
    final orders = state.orders..ensureFlight(name);
    state = state.copyWith(orders: orders, selectedFlight: name);
    _publishState(orders, by: _userId, action: 'added flight $name');
    _pushLogLine('$_userId (you): added flight $name');
  }

  // ---- incoming messages --------------------------------------------------

  void _onMessage(BrokerMessage msg) {
    switch (msg.topic) {
      case kStateTopic:
        _onState(msg.payload);
      case kRequestTopic:
        if (_isMaster) _onRequest(msg.payload);
      case kMasterTopic:
        if (!_isMaster) {
          state = state.copyWith(masterOnline: msg.payload.trim() == 'online');
        }
    }
  }

  void _onState(String payload) {
    if (_isMaster) {
      // Adopt retained state once to recover after a restart; ignore our own
      // echoes thereafter.
      if (_bootstrapped) return;
      _bootstrapped = true;
      final orders = OrderState.fromJson(payload)
        ..ensureFlight(state.selectedFlight);
      state = state.copyWith(orders: orders);
      return;
    }
    // Officer: the master's state is the truth.
    final orders = OrderState.fromJson(payload)
      ..ensureFlight(state.selectedFlight);
    state = state.copyWith(orders: orders);
    _logFromPayload(payload);
  }

  /// Master: a memur asked to change an order. Apply and republish.
  void _onRequest(String payload) {
    try {
      final r = jsonDecode(payload) as Map<String, dynamic>;
      _applyAndPublish(
        r['flight'] as String,
        r['product'] as String,
        (r['delta'] as num).toInt(),
        r['by'] as String? ?? 'officer',
      );
    } catch (_) {}
  }

  // ---- master internals ---------------------------------------------------

  void _applyAndPublish(String flight, String product, int delta, String by) {
    _bootstrapped = true;
    final orders = state.orders..bump(flight, product, delta);
    final sign = delta > 0 ? '+$delta' : '$delta';
    final text = '$sign $product on $flight';
    state = state.copyWith(orders: orders);
    _publishState(orders, by: by, action: text);
    final who = by == _userId ? '$by (you)' : by;
    _pushLogLine('$who: $text');
  }

  void _publishState(OrderState orders,
          {required String by, required String action}) =>
      _mqtt?.publish(kStateTopic, orders.toPayload(by: by, action: action),
          retain: true);

  // ---- activity log -------------------------------------------------------

  void _logFromPayload(String payload) {
    try {
      final action =
          (jsonDecode(payload) as Map<String, dynamic>)['lastAction'];
      if (action is Map) {
        final who =
            action['by'] == _userId ? '${action['by']} (you)' : action['by'];
        _pushLogLine('$who: ${action['text']}');
      }
    } catch (_) {}
  }

  void _pushLogLine(String line) {
    final next = [line, ...state.log];
    if (next.length > 30) next.removeRange(30, next.length);
    state = state.copyWith(log: next);
  }
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersUiState>(OrdersController.new);
