import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../../core/mqtt/mqtt_service.dart';
import '../../auth/application/session.dart';
import '../domain/order_state.dart';

/// Immutable snapshot the orders UI renders from.
class OrdersUiState {
  const OrdersUiState({
    required this.orders,
    required this.selectedFlight,
    required this.status,
    required this.log,
    this.error,
  });

  final OrderState orders;
  final String selectedFlight;
  final MqttConnectionState status;
  final List<String> log;
  final String? error;

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
  }) {
    return OrdersUiState(
      orders: orders ?? this.orders,
      selectedFlight: selectedFlight ?? this.selectedFlight,
      status: status ?? this.status,
      log: log ?? this.log,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

/// Owns the MQTT connection and the shared order state for the logged-in user.
class OrdersController extends Notifier<OrdersUiState> {
  late final MqttService _mqtt;
  late final String _userId;
  late final bool _isMaster;

  @override
  OrdersUiState build() {
    final user = ref.watch(currentUserProvider);
    _userId = user.id;
    _isMaster = user.isMaster;

    _mqtt = MqttService(userLabel: _userId);
    _mqtt.stateStream.listen(_onRemoteState);
    _mqtt.statusStream.listen((s) => state = state.copyWith(status: s));
    ref.onDispose(_mqtt.dispose);

    _connect();
    return OrdersUiState.initial();
  }

  Future<void> connect() => _connect();

  Future<void> _connect() async {
    state = state.copyWith(error: null);
    try {
      await _mqtt.connect();
    } catch (e) {
      state = state.copyWith(error: 'Could not connect: $e');
    }
  }

  void selectFlight(String flight) {
    state = state.copyWith(selectedFlight: flight);
  }

  /// Places (or corrects) an order, then republishes the full retained state.
  void order(String product, int delta) {
    final orders = state.orders..bump(state.selectedFlight, product, delta);
    final sign = delta > 0 ? '+$delta' : '$delta';
    _applyLocal(orders, '$sign $product on ${state.selectedFlight}');
  }

  void resetFlight() {
    final orders = state.orders..resetFlight(state.selectedFlight);
    _applyLocal(orders, 'reset ${state.selectedFlight}');
  }

  void addFlight(String rawName) {
    final name = rawName.trim().toUpperCase();
    if (name.isEmpty) return;
    final orders = state.orders..ensureFlight(name);
    state = state.copyWith(orders: orders, selectedFlight: name);
    _mqtt.publishState(orders.toPayload(by: _userId, action: 'added flight $name'));
  }

  // ---- internals ----------------------------------------------------------

  /// Optimistically updates the local UI, then publishes. The activity-log
  /// entry is added when the broker echoes the message back (see
  /// [_onRemoteState]), so own and remote actions are attributed identically
  /// and never logged twice.
  void _applyLocal(OrderState orders, String action) {
    state = state.copyWith(orders: orders);
    _mqtt.publishState(orders.toPayload(by: _userId, action: action));
  }

  void _onRemoteState(String payload) {
    final orders = OrderState.fromJson(payload)..ensureFlight(state.selectedFlight);
    String? logLine;
    try {
      final action = (jsonDecode(payload) as Map<String, dynamic>)['lastAction'];
      if (action is Map) {
        final who = action['by'] == _userId ? '${action['by']} (you)' : action['by'];
        logLine = '$who: ${action['text']}';
      }
    } catch (_) {}
    state = state.copyWith(orders: orders);
    if (logLine != null) _pushLogLine(logLine);
  }

  void _pushLogLine(String line) {
    final next = [line, ...state.log];
    if (next.length > 30) next.removeRange(30, next.length);
    state = state.copyWith(log: next);
  }

  bool get isMaster => _isMaster;
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersUiState>(OrdersController.new);
