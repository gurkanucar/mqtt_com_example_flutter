import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mqtt_com_example/features/orders/domain/order_state.dart';
import 'package:mqtt_com_example/main.dart';

void main() {
  group('OrderState', () {
    test('starts with all default flights at zero', () {
      final state = OrderState.initial();
      for (final flight in kDefaultFlights) {
        for (final product in kProducts) {
          expect(state.count(flight, product), 0);
        }
      }
    });

    test('bump increases and clamps at zero', () {
      final state = OrderState.initial()
        ..bump('TK1234', 'Coffee', 2)
        ..bump('TK1234', 'Coffee', -5);
      expect(state.count('TK1234', 'Coffee'), 0);
    });

    test('survives a publish -> parse round trip', () {
      final original = OrderState.initial()..bump('TK1234', 'Water', 3);
      final payload = original.toPayload(by: 'memur1', action: '+3 Water');
      final restored = OrderState.fromJson(payload);
      expect(restored.count('TK1234', 'Water'), 3);
    });

    test('parsing a payload from an unknown flight keeps it', () {
      const payload = '{"flights":{"TK9999":{"Coffee":1}}}';
      final restored = OrderState.fromJson(payload);
      expect(restored.count('TK9999', 'Coffee'), 1);
      // default flights still present
      expect(restored.flights.containsKey('TK1234'), isTrue);
    });
  });

  testWidgets('login page shows the three users', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.pumpAndSettle();

    expect(find.text('amir'), findsOneWidget);
    expect(find.text('memur1'), findsOneWidget);
    expect(find.text('memur2'), findsOneWidget);
    expect(find.text('Master'), findsOneWidget);
  });
}
