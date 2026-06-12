import 'package:flutter/material.dart';

/// Flight dropdown plus an "add flight" button.
class FlightSelector extends StatelessWidget {
  const FlightSelector({
    super.key,
    required this.flights,
    required this.selected,
    required this.onChanged,
    required this.onAdd,
  });

  final List<String> flights;
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.flight),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final f in flights)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Add flight',
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
