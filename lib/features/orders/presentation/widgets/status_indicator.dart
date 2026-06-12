import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Coloured dot + label showing the MQTT connection state.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.status});

  final MqttConnectionState status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      MqttConnectionState.connected => (Colors.green, 'online'),
      MqttConnectionState.connecting ||
      MqttConnectionState.disconnecting =>
        (Colors.orange, '...'),
      _ => (Colors.red, 'offline'),
    };
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
