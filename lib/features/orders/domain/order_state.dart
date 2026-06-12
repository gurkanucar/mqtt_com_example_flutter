import 'dart:convert';

/// The three example products that can be ordered for a flight.
const List<String> kProducts = ['Coffee', 'Sandwich', 'Water'];

/// Flights that always exist. Users can add more at runtime.
const List<String> kDefaultFlights = ['TK1234', 'TK5678', 'TK9012'];

/// The full shared state: for every flight, how many of each product are ordered.
///
/// This whole object is what gets published (retained) to MQTT so that any
/// device — including one that logs in later — receives the complete picture.
class OrderState {
  OrderState(this.flights);

  /// flight number -> (product name -> count)
  final Map<String, Map<String, int>> flights;

  factory OrderState.initial() {
    final map = <String, Map<String, int>>{};
    for (final flight in kDefaultFlights) {
      map[flight] = {for (final p in kProducts) p: 0};
    }
    return OrderState(map);
  }

  /// Rebuilds state from a published payload `{ "flights": { ... } }`.
  factory OrderState.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final raw = (data['flights'] as Map<String, dynamic>?) ?? {};
    final flights = <String, Map<String, int>>{};
    raw.forEach((flight, products) {
      final perProduct = <String, int>{for (final p in kProducts) p: 0};
      (products as Map<String, dynamic>).forEach((name, value) {
        perProduct[name] = (value as num).toInt();
      });
      flights[flight] = perProduct;
    });
    for (final flight in kDefaultFlights) {
      flights.putIfAbsent(flight, () => {for (final p in kProducts) p: 0});
    }
    return OrderState(flights);
  }

  int count(String flight, String product) => flights[flight]?[product] ?? 0;

  void ensureFlight(String flight) {
    flights.putIfAbsent(flight, () => {for (final p in kProducts) p: 0});
  }

  void bump(String flight, String product, int delta) {
    ensureFlight(flight);
    final current = flights[flight]![product] ?? 0;
    flights[flight]![product] = (current + delta).clamp(0, 9999);
  }

  void resetFlight(String flight) {
    ensureFlight(flight);
    for (final p in kProducts) {
      flights[flight]![p] = 0;
    }
  }

  /// Encodes the full state plus the action that produced it (for the activity
  /// log) into the payload that gets published retained.
  String toPayload({required String by, required String action}) {
    return jsonEncode({
      'flights': flights,
      'lastAction': {'by': by, 'text': action},
    });
  }
}
